import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/format.dart';

/// Data yang dibutuhkan untuk mencetak satu faktur.
class DataFaktur {
  const DataFaktur({
    required this.transaksi,
    required this.penjualan,
    required this.profil,
    required this.pengaturan,
    this.kontak,
    this.dicetakOleh = '',
  });

  final Transaksi transaksi;
  final bool penjualan;
  final ProfilToko profil;
  final PengaturanFaktur pengaturan;

  /// Data pelanggan/supplier lengkap (alamat & telepon), kalau ada.
  final Kontak? kontak;
  final String dicetakOleh;
}

const _mm = PdfPageFormat.mm;
final _hijau = PdfColor.fromHex('#156143');
final _abu = PdfColor.fromHex('#6B7280');
final _garis = PdfColor.fromHex('#D1D5DB');
final _latarHeader = PdfColor.fromHex('#E8F3EE');

PdfPageFormat formatKertas(String ukuran) => switch (ukuran) {
  'A4' => PdfPageFormat.a4.copyWith(
    marginLeft: 15 * _mm,
    marginRight: 15 * _mm,
    marginTop: 12 * _mm,
    marginBottom: 12 * _mm,
  ),
  'Continuous Form' => const PdfPageFormat(9.5 * PdfPageFormat.inch, 11 * PdfPageFormat.inch, marginAll: 10 * _mm),
  // Setengah continuous form 9,5 x 5,5 inci — ukuran umum faktur rangkap toko.
  'Continuous 1/2' => const PdfPageFormat(
    9.5 * PdfPageFormat.inch,
    5.5 * PdfPageFormat.inch,
    marginLeft: 10 * _mm,
    marginRight: 10 * _mm,
    marginTop: 6 * _mm,
    marginBottom: 6 * _mm,
  ),
  'Struk 80 mm' => const PdfPageFormat(80 * _mm, double.infinity, marginAll: 4 * _mm),
  'Struk 58 mm' => const PdfPageFormat(58 * _mm, double.infinity, marginAll: 3 * _mm),
  _ => PdfPageFormat.a5.copyWith(
    marginLeft: 10 * _mm,
    marginRight: 10 * _mm,
    marginTop: 10 * _mm,
    marginBottom: 10 * _mm,
  ),
};

/// Membuat file PDF faktur.
Future<Uint8List> buatFakturPdf(DataFaktur d) async {
  final cfg = d.pengaturan;
  final logo = cfg.tampilkanLogo && !cfg.hitamPutih ? await rootBundle.loadString('assets/logo.svg') : null;
  final doc = pw.Document(title: 'Faktur ${d.transaksi.kode}', author: d.profil.nama);
  final format = formatKertas(cfg.ukuran);
  if (cfg.struk) {
    doc.addPage(pw.Page(pageFormat: format, build: (_) => _struk(d, logo, format)));
    return doc.save();
  }

  // Label lembar di kaki halaman.
  final labels = <String?>[];
  switch (cfg.rangkap) {
    case 'NCR 3 ply':
      labels.add(
        [for (var i = 0; i < 3; i++) '${PengaturanFaktur.warnaNcr[i]}: ${cfg.labelLembar[i]}'].join('   |   '),
      );
    case '3 lembar':
      for (var i = 0; i < 3; i++) {
        labels.add('Lembar ${i + 1}: ${cfg.labelLembar[i]}');
      }
    default:
      labels.add(null);
  }

  final abu = cfg.hitamPutih ? PdfColors.black : _abu;
  for (final label in labels) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text('${d.transaksi.kode} (lanjutan)', style: pw.TextStyle(color: abu, fontSize: 8)),
        footer: (ctx) => pw.Row(
          children: [
            if (label != null)
              pw.Expanded(
                child: pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              )
            else
              pw.Spacer(),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}', style: pw.TextStyle(color: abu, fontSize: 7)),
          ],
        ),
        build: (_) => _lembar(d, logo, format),
      ),
    );
  }
  return doc.save();
}

// ------------------------------------------------------------ A4 / A5 / CF
List<pw.Widget> _lembar(DataFaktur d, String? logo, PdfPageFormat f) {
  final t = d.transaksi;
  final kecil = f.availableWidth < 140 * _mm; // A5
  final fs = kecil ? 8.0 : 9.5;
  final cfg = d.pengaturan;
  final judul = d.penjualan ? cfg.judulPenjualan : cfg.judulPembelian;
  final pendek = f.height < 160 * _mm; // Continuous 1/2

  // Mode hitam-putih: semua hitam, tanpa arsiran — tembusan kertas rangkap tetap jelas.
  final mono = cfg.hitamPutih;
  final hijau = mono ? PdfColors.black : _hijau;
  final abu = mono ? PdfColors.black : _abu;
  final garis = mono ? PdfColors.black : _garis;
  final latar = mono ? null : _latarHeader;
  final warnaStatus = mono ? PdfColors.black : (t.lunas ? _hijau : PdfColors.orange700);

  pw.Widget info(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: kecil ? 52 : 64,
          child: pw.Text(
            k,
            style: pw.TextStyle(fontSize: fs, color: abu),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(fontSize: fs)),
        pw.Expanded(
          child: pw.Text(v, style: pw.TextStyle(fontSize: fs)),
        ),
      ],
    ),
  );

  return [
    // Kop
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[pw.SvgImage(svg: logo, width: kecil ? 42 : 56), pw.SizedBox(width: 10)],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                d.profil.nama.toUpperCase(),
                style: pw.TextStyle(fontSize: kecil ? 15 : 19, fontWeight: pw.FontWeight.bold, color: hijau),
              ),
              if (d.profil.alamat.isNotEmpty) pw.Text(d.profil.alamat, style: pw.TextStyle(fontSize: fs)),
              pw.Text(
                [
                  if (d.profil.telepon.isNotEmpty) 'Telp. ${d.profil.telepon}',
                  if (d.profil.email.isNotEmpty) d.profil.email,
                ].join('  |  '),
                style: pw.TextStyle(fontSize: fs, color: abu),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              judul,
              style: pw.TextStyle(fontSize: kecil ? 12 : 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'No. ${t.kode}',
              style: pw.TextStyle(fontSize: fs + 1, fontWeight: pw.FontWeight.bold),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4),
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: warnaStatus, width: 1),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                t.status.toUpperCase(),
                style: pw.TextStyle(fontSize: fs - 1, fontWeight: pw.FontWeight.bold, color: warnaStatus),
              ),
            ),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 8),
    pw.Container(height: 2, color: hijau),
    pw.SizedBox(height: 8),

    // Info transaksi & pihak
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              info(d.penjualan ? 'Kepada' : 'Supplier', t.pihak),
              if (_alamatLengkap(d).isNotEmpty) info('Alamat', _alamatLengkap(d)),
              if ((d.kontak?.telepon ?? '').isNotEmpty) info('Telepon', d.kontak!.telepon),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              info('Tanggal', tglBulan(t.tanggal)),
              info('Pembayaran', t.lunas ? 'Tunai / Lunas' : (d.penjualan ? 'Piutang' : 'Hutang')),
              if (d.dicetakOleh.isNotEmpty) info('Petugas', d.dicetakOleh),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 10),

    // Tabel barang
    pw.TableHelper.fromTextArray(
      headers: ['No', 'Kode', 'Nama Barang', 'Qty', 'Satuan', 'Harga', 'Jumlah'],
      data: [
        for (final (i, it) in t.items.indexed)
          ['${i + 1}', it.kodeBarang, it.namaBarang, angka(it.qty), it.satuan, angka(it.harga), angka(it.subtotal)],
      ],
      headerStyle: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold, color: hijau),
      headerDecoration: pw.BoxDecoration(
        color: latar,
        border: mono
            ? pw.Border(
                top: pw.BorderSide(color: garis),
                bottom: pw.BorderSide(color: garis),
              )
            : null,
      ),
      cellStyle: pw.TextStyle(fontSize: fs),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: garis),
        horizontalInside: pw.BorderSide(color: garis, width: mono ? 0.3 : 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FixedColumnWidth(54),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FixedColumnWidth(30),
        4: const pw.FixedColumnWidth(48),
        5: const pw.FlexColumnWidth(1.3),
        6: const pw.FlexColumnWidth(1.5),
      },
      cellAlignments: {
        0: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      headerAlignments: {
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
    ),
    pw.SizedBox(height: 6),

    // Total
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: cfg.tampilkanTerbilang
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: mono
                      ? pw.BoxDecoration(border: pw.Border.all(color: garis, width: 0.5))
                      : pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(3)),
                  child: pw.Text(
                    'Terbilang: ${_kapital(terbilang(t.total))} rupiah',
                    style: pw.TextStyle(fontSize: fs - 0.5, fontStyle: pw.FontStyle.italic),
                  ),
                )
              : pw.SizedBox(),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: kecil ? 150 : 200,
          child: pw.Column(
            children: [
              _barisTotal('Total Item', '${t.items.length} barang / ${angka(t.jumlahQty)} unit', fs, abu),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4),
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: mono ? pw.BoxDecoration(border: pw.Border.all(width: 1.2)) : pw.BoxDecoration(color: hijau),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: fs + 1,
                        fontWeight: pw.FontWeight.bold,
                        color: mono ? null : PdfColors.white,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      rupiah(t.total),
                      style: pw.TextStyle(
                        fontSize: fs + 2,
                        fontWeight: pw.FontWeight.bold,
                        color: mono ? null : PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    if (t.catatan.isNotEmpty) ...[
      pw.SizedBox(height: 6),
      pw.Text('Catatan: ${t.catatan}', style: pw.TextStyle(fontSize: fs)),
    ],

    // Tanda tangan
    if (cfg.tampilkanTandaTangan) ...[
      pw.SizedBox(height: pendek ? 6 : 16),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _ttd(d.penjualan ? 'Penerima,' : 'Pengirim,', fs, tinggi: pendek ? 24 : 40),
          _ttd('Hormat kami,', fs, nama: d.profil.nama, tinggi: pendek ? 24 : 40),
        ],
      ),
    ],

    if (cfg.catatanKaki.trim().isNotEmpty) ...[
      pw.SizedBox(height: pendek ? 4 : 14),
      pw.Divider(color: garis, thickness: 0.5),
      pw.SizedBox(
        width: double.infinity,
        child: pw.Text(
          cfg.catatanKaki.trim(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs - 1, color: abu),
        ),
      ),
    ],
  ];
}

pw.Widget _barisTotal(String k, String v, double fs, PdfColor abu) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  child: pw.Row(
    children: [
      pw.Text(
        k,
        style: pw.TextStyle(fontSize: fs, color: abu),
      ),
      pw.Spacer(),
      pw.Text(v, style: pw.TextStyle(fontSize: fs)),
    ],
  ),
);

pw.Widget _ttd(String label, double fs, {String nama = '', double tinggi = 40}) => pw.Column(
  children: [
    pw.Text(label, style: pw.TextStyle(fontSize: fs)),
    pw.SizedBox(height: tinggi),
    pw.Container(width: 110, height: 0.7, color: PdfColors.black),
    pw.SizedBox(height: 2),
    pw.Text(nama.isEmpty ? '(.............................)' : nama, style: pw.TextStyle(fontSize: fs - 1)),
  ],
);

String _kapital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ------------------------------------------------------------------- Struk
pw.Widget _struk(DataFaktur d, String? logo, PdfPageFormat f) {
  final t = d.transaksi;
  final kecil = f.width < 70 * _mm;
  final fs = kecil ? 6.5 : 7.5;
  final cfg = d.pengaturan;
  // Fungsi (bukan satu objek) karena widget pdf tidak boleh dipakai ulang.
  pw.Widget garis() => pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _abu, width: 0.6, style: pw.BorderStyle.dashed),
      ),
    ),
  );
  pw.Widget baris(String k, String v, {bool tebal = false}) => pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          k,
          style: pw.TextStyle(fontSize: fs, fontWeight: tebal ? pw.FontWeight.bold : null),
        ),
      ),
      pw.Text(
        v,
        style: pw.TextStyle(fontSize: fs, fontWeight: tebal ? pw.FontWeight.bold : null),
      ),
    ],
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      if (logo != null)
        pw.Center(
          child: pw.SvgImage(svg: logo, width: kecil ? 26 : 34),
        ),
      pw.Text(
        d.profil.nama.toUpperCase(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: fs + 3, fontWeight: pw.FontWeight.bold),
      ),
      if (d.profil.alamat.isNotEmpty)
        pw.Text(
          d.profil.alamat,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs),
        ),
      if (d.profil.telepon.isNotEmpty)
        pw.Text(
          'Telp. ${d.profil.telepon}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs),
        ),
      garis(),
      baris('No', t.kode),
      baris('Tanggal', tgl(t.tanggal)),
      baris(d.penjualan ? 'Pelanggan' : 'Supplier', t.pihak),
      if (d.dicetakOleh.isNotEmpty) baris('Kasir', d.dicetakOleh),
      garis(),
      for (final it in t.items) ...[
        pw.Text(it.namaBarang, style: pw.TextStyle(fontSize: fs)),
        baris('  ${angka(it.qty)} ${it.satuan} x ${angka(it.harga)}', angka(it.subtotal)),
      ],
      garis(),
      baris('TOTAL', rupiah(t.total), tebal: true),
      baris('Status', t.status),
      if (cfg.tampilkanTerbilang) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          '${_kapital(terbilang(t.total))} rupiah',
          style: pw.TextStyle(fontSize: fs - 0.5, fontStyle: pw.FontStyle.italic),
        ),
      ],
      garis(),
      if (cfg.catatanKaki.trim().isNotEmpty)
        pw.Text(
          cfg.catatanKaki.trim(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs),
        ),
    ],
  );
}

/// Alamat pelanggan/supplier ditambah daerah transaksi (kalau belum tertulis di alamat).
String _alamatLengkap(DataFaktur d) {
  final k = d.kontak;
  final alamat = k == null || k.alamat.trim() == '-' ? '' : k.alamat.trim();
  final daerah = d.transaksi.daerah.trim().isNotEmpty ? d.transaksi.daerah.trim() : (k?.daerah.trim() ?? '');
  if (daerah.isEmpty || alamat.toLowerCase().contains(daerah.toLowerCase())) return alamat;
  return alamat.isEmpty ? daerah : '$alamat, $daerah';
}
