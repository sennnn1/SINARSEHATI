import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../faktur/faktur_page.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Halaman Pembelian (penjualan: false) atau Penjualan (penjualan: true).
class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key, required this.penjualan});

  final bool penjualan;

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  String cari = '';
  String status = 'Semua';
  String daerah = 'Semua Daerah';

  bool get pj => widget.penjualan;
  String get belumLunas => pj ? 'Piutang' : 'Hutang';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final semua = [...(pj ? s.penjualan : s.pembelian)]
      ..sort((a, b) {
        final c = b.tanggal.compareTo(a.tanggal);
        return c != 0 ? c : b.kode.compareTo(a.kode);
      });
    final q = cari.toLowerCase();
    String daerahDari(Transaksi t) => s.daerahTransaksi(t, penjualan: pj);
    final daftarDaerah = {for (final t in semua) daerahDari(t)}.toList()..sort();
    if (daerah != 'Semua Daerah' && !daftarDaerah.contains(daerah)) daerah = 'Semua Daerah';
    final data = semua
        .where((t) =>
            (status == 'Semua' || t.status == status) &&
            (daerah == 'Semua Daerah' || daerahDari(t) == daerah) &&
            (q.isEmpty ||
                t.kode.toLowerCase().contains(q) ||
                t.pihak.toLowerCase().contains(q) ||
                daerahDari(t).toLowerCase().contains(q)))
        .toList();
    final bulanIni = s.dalam(semua, rentangBulan(now.year, now.month)).toList();
    final belum = semua.where((t) => !t.lunas).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: pj ? 'Penjualan' : 'Pembelian',
          subtitle: pj
              ? 'Catat transaksi penjualan barang ke pelanggan'
              : 'Catat transaksi pembelian barang dari supplier',
          actions: [
            FilledButton.icon(
              onPressed: () => _tambah(context),
              icon: const Icon(Icons.add),
              label: const Text('Transaksi Baru'),
            ),
          ],
        ),
        if (s.errorTransaksi != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.red),
              const SizedBox(width: 10),
              Expanded(child: Text(s.errorTransaksi!, style: const TextStyle(color: AppColors.red))),
              TextButton(onPressed: s.muatTransaksiDariSupabase, child: const Text('Coba lagi')),
            ]),
          ),
        ResponsiveGrid(children: [
          StatTile(
            label: 'Transaksi Bulan Ini',
            value: '${bulanIni.length}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.blue,
          ),
          StatTile(
            label: 'Total Bulan Ini',
            value: rupiah(bulanIni.fold<double>(0, (a, t) => a + t.total)),
            icon: Icons.payments_outlined,
          ),
          StatTile(
            label: pj ? 'Piutang (belum dibayar)' : 'Hutang (belum dibayar)',
            value: rupiah(belum.fold<double>(0, (a, t) => a + t.total)),
            note: '${belum.length} transaksi',
            icon: Icons.schedule,
            color: AppColors.orange,
          ),
        ]),
        const SizedBox(height: 16),
        SectionCard(
          title: pj ? 'Daftar Penjualan' : 'Daftar Pembelian',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                SearchBox(
                  hint: pj ? 'Cari kode / pelanggan / daerah' : 'Cari kode / supplier / daerah',
                  onChanged: (v) => setState(() => cari = v),
                ),
                FilterDropdown(
                  width: 170,
                  value: status,
                  items: ['Semua', 'Lunas', belumLunas],
                  onChanged: (v) => setState(() => status = v),
                ),
                FilterDropdown(
                  width: 190,
                  value: daerah,
                  items: ['Semua Daerah', ...daftarDaerah],
                  onChanged: (v) => setState(() => daerah = v),
                ),
              ]),
              const SizedBox(height: 12),
              SimpleTable.builder(
                perPage: 15,
                columns: [
                  kol('No'),
                  kol('Tanggal'),
                  kol('Kode'),
                  kol(pj ? 'Pelanggan' : 'Supplier'),
                  kol('Daerah'),
                  kol('Item', angka: true),
                  kol('Total', angka: true),
                  kol('Status'),
                  kol('Aksi'),
                ],
                jumlah: data.length,
                baris: (i) {
                  final t = data[i];
                  return DataRow(cells: [
                    sel('${i + 1}'),
                    sel(tgl(t.tanggal)),
                    sel(t.kode),
                    sel(t.pihak),
                    sel(daerahDari(t)),
                    sel('${t.items.length}'),
                    sel(rupiah(t.total)),
                    DataCell(StatusBadge(t.status)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      AksiButton(
                        icon: Icons.print_outlined,
                        tooltip: 'Cetak Faktur',
                        color: AppColors.brand,
                        onPressed: () => bukaFaktur(context, t, penjualan: pj),
                      ),
                      AksiButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'Detail',
                        onPressed: () => showDialog(
                            context: context, builder: (_) => DetailTransaksiDialog(t: t, penjualan: pj)),
                      ),
                      if (!t.lunas)
                        AksiButton(
                          icon: Icons.check_circle_outline,
                          tooltip: 'Tandai Lunas',
                          color: AppColors.green,
                          onPressed: () {
                            s.ubahStatus(t, 'Lunas');
                            toast(context, '${t.kode} ditandai lunas');
                          },
                        ),
                      AksiButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Hapus',
                        color: AppColors.red,
                        onPressed: () async {
                          final ok = await konfirmasi(context,
                              'Hapus transaksi ${t.kode}? Stok barang akan dikembalikan seperti semula.');
                          if (!ok) return;
                          final e = await s.hapusTransaksi(t, isPenjualan: pj);
                          if (!context.mounted) return;
                          toast(context, e ?? '${t.kode} dihapus', error: e != null);
                        },
                      ),
                    ])),
                  ]);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _tambah(BuildContext context) async {
    final t = await showDialog<Transaksi>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransaksiFormDialog(penjualan: pj),
    );
    if (t == null || !context.mounted) return;
    toast(context, 'Transaksi ${t.kode} tersimpan (${rupiah(t.total)})');
    try {
      await cetakFaktur(context, t, penjualan: pj);
    } catch (e) {
      // Transaksi tetap tersimpan; faktur bisa dicetak ulang dari tombol printer.
      if (context.mounted) toast(context, 'Faktur belum bisa dicetak: $e', error: true);
    }
  }
}

class _BarisItem {
  String? kode;
  final qty = TextEditingController(text: '1');
  final harga = TextEditingController();

  int get q => int.tryParse(qty.text) ?? 0;
  double get h => parseAngka(harga.text);
  double get subtotal => q * h;

  void dispose() {
    qty.dispose();
    harga.dispose();
  }
}

class TransaksiFormDialog extends StatefulWidget {
  const TransaksiFormDialog({super.key, required this.penjualan});

  final bool penjualan;

  @override
  State<TransaksiFormDialog> createState() => _TransaksiFormDialogState();
}

class _TransaksiFormDialogState extends State<TransaksiFormDialog> {
  DateTime tanggal = DateUtils.dateOnly(DateTime.now());
  String? pihak;
  String status = 'Lunas';
  final catatan = TextEditingController();
  final daerah = TextEditingController();
  final rows = <_BarisItem>[_BarisItem()];
  String? error;
  bool menyimpan = false;

  bool get pj => widget.penjualan;

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    catatan.dispose();
    daerah.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kode = pj ? s.kodePenjualanBaru : s.kodePembelianBaru;
    final daftarPihak = (pj ? s.pelanggan : s.supplier).map((e) => e.nama).toList();
    // Layar sempit (HP): kolom isian memenuhi lebar dialog, bukan lebar tetap.
    final sempit = MediaQuery.sizeOf(context).width < 600;
    double lebar(double w) => sempit ? double.infinity : w;
    final total = rows.fold<double>(0, (a, r) => a + r.subtotal);

    return FormDialog(
      // Dengan database, nomor final dibuat saat disimpan (bisa beda kalau ada
      // kasir lain yang menyimpan lebih dulu).
      title: '${pj ? 'Penjualan' : 'Pembelian'} Baru — $kode',
      maxWidth: 860,
      error: error,
      menyimpan: menyimpan,
      // Transaksi disimpan dulu, lalu dialog cetak faktur langsung terbuka.
      labelSimpan: 'Simpan & Cetak',
      ikonSimpan: Icons.print_outlined,
      onSave: () => _simpan(s, kode),
      footer: Text('Total: ${rupiah(total)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.green)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: lebar(200),
              child: DateField(
                  label: 'Tanggal', value: tanggal, onChanged: (d) => setState(() => tanggal = d)),
            ),
            SizedBox(
              width: lebar(280),
              // Bisa diketik untuk mencari; daftar muncul saat kolom diklik.
              child: Autocomplete<String>(
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  return daftarPihak.where((p) => p.toLowerCase().contains(q)).take(30);
                },
                onSelected: (v) => _pilihPihak(s, v),
                fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                  controller: controller,
                  focusNode: focus,
                  onSubmitted: (_) => onSubmit(),
                  // Nama yang diketik lengkap (tanpa memilih dari daftar) tetap dianggap dipilih.
                  onChanged: (v) {
                    final q = v.trim().toLowerCase();
                    final cocok = daftarPihak.where((p) => p.toLowerCase() == q).firstOrNull;
                    if (cocok != pihak) _pilihPihak(s, cocok);
                  },
                  decoration: InputDecoration(
                    labelText: pj ? 'Pelanggan' : 'Supplier',
                    hintText: 'Ketik nama ${pj ? 'pelanggan' : 'supplier'}',
                    suffixIcon: const Icon(Icons.search, size: 20),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: lebar(200),
              // Terisi otomatis dari daerah pelanggan; bisa diubah (mis. pelanggan UMUM).
              child: SaranField(
                controller: daerah,
                saran: () => {...s.daerahTerpakai, ...AppState.daerahSaran},
                label: 'Daerah',
                hint: 'mis. Banda Aceh',
                icon: Icons.place_outlined,
              ),
            ),
            SizedBox(
              width: lebar(180),
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status Pembayaran'),
                items: [
                  for (final st in ['Lunas', pj ? 'Piutang' : 'Hutang'])
                    DropdownMenuItem(value: st, child: Text(st)),
                ],
                onChanged: (v) => setState(() => status = v ?? 'Lunas'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Daftar Barang', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Baris kosong baru muncul otomatis setelah barang di baris terakhir dipilih.
          for (final (i, r) in rows.indexed) _baris(s, i, r),
          const SizedBox(height: 8),
          TextField(
            controller: catatan,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
        ],
      ),
    );
  }

  /// Memilih pelanggan/supplier; daerahnya ikut terisi otomatis (masih bisa diubah).
  void _pilihPihak(AppState s, String? nama) {
    setState(() => pihak = nama);
    final d = nama == null ? '' : (s.cariKontak(!pj, nama)?.daerah ?? '');
    if (d.isNotEmpty) daerah.text = d;
  }

  static String _labelBarang(Barang b) => '${b.kode} — ${b.nama}';

  Widget _baris(AppState s, int i, _BarisItem r) {
    final b = r.kode == null ? null : s.cariBarang(r.kode!);

    // Kolom cari (bukan dropdown) supaya ribuan barang tidak dimuat
    // sekaligus; hanya 30 hasil teratas yang ditampilkan.
    final barang = Autocomplete<Barang>(
      initialValue: TextEditingValue(text: b == null ? '' : _labelBarang(b)),
      displayStringForOption: _labelBarang,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        final hasil = q.isEmpty
            ? s.barang
            : s.barang.where((e) => e.kode.toLowerCase().contains(q) || e.nama.toLowerCase().contains(q));
        return hasil.take(30);
      },
      onSelected: (b) => setState(() {
        r.kode = b.kode;
        r.harga.text = (pj ? b.hargaJual : b.hargaBeli).round().toString();
        if (identical(r, rows.last)) rows.add(_BarisItem());
      }),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        onSubmitted: (_) => onSubmit(),
        onChanged: (v) {
          if (b != null && v != _labelBarang(b)) setState(() => r.kode = null);
        },
        decoration: InputDecoration(
          labelText: 'Barang ${i + 1}',
          hintText: 'Ketik kode / nama barang',
          helperText: b == null ? null : 'Stok: ${b.stok} ${b.satuan}',
        ),
      ),
    );
    final qty = TextField(
      controller: r.qty,
      inputFormatters: hanyaAngka,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: 'Qty', suffixText: b?.satuan),
      onChanged: (_) => setState(() {}),
    );
    final harga = TextField(
      controller: r.harga,
      inputFormatters: hanyaAngka,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Harga', prefixText: 'Rp '),
      onChanged: (_) => setState(() {}),
    );
    final subtotal = Text(rupiah(r.subtotal),
        textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600));
    final hapus = IconButton(
      tooltip: 'Hapus baris',
      // Baris kosong terakhir (tempat mengisi barang berikutnya) tidak perlu dihapus.
      onPressed: identical(r, rows.last) && r.kode == null
          ? null
          : () => setState(() {
                rows.removeAt(i).dispose();
                if (rows.isEmpty || rows.last.kode != null) rows.add(_BarisItem());
              }),
      icon: const Icon(Icons.close, color: AppColors.red),
    );

    return Padding(
      key: ObjectKey(r),
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(builder: (context, c) {
        // Layar sempit: barang di atas, lalu qty + harga, lalu subtotal + hapus.
        if (c.maxWidth < 600) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            barang,
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: qty),
              const SizedBox(width: 8),
              Expanded(child: harga),
            ]),
            Row(children: [
              const Text('Subtotal  ', style: TextStyle(color: AppColors.muted)),
              Expanded(child: subtotal),
              hapus,
            ]),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: barang),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: qty),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: harga),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 14), child: subtotal)),
            hapus,
          ],
        );
      }),
    );
  }

  Future<void> _simpan(AppState s, String kode) async {
    String? err;
    final items = <ItemTransaksi>[];
    if (pihak == null) err = 'Pilih ${pj ? 'pelanggan' : 'supplier'} terlebih dahulu.';
    for (final r in rows) {
      if (r.kode == null) continue;
      final b = s.cariBarang(r.kode!);
      if (b == null) continue;
      if (r.q <= 0) err ??= 'Jumlah ${b.nama} harus lebih dari 0.';
      if (r.h <= 0) err ??= 'Harga ${b.nama} belum diisi.';
      items.add(ItemTransaksi(
        kodeBarang: b.kode,
        namaBarang: b.nama,
        satuan: b.satuan,
        qty: r.q,
        harga: r.h,
        hargaPokok: b.hargaBeli,
      ));
    }
    if (items.isEmpty) err ??= 'Tambahkan minimal satu barang.';
    if (err != null) {
      setState(() => error = err);
      return;
    }

    final t = Transaksi(
      kode: kode,
      tanggal: tanggal,
      pihak: pihak!,
      items: items,
      status: status,
      catatan: catatan.text.trim(),
      daerah: s.rapikanDaerah(daerah.text),
    );
    setState(() {
      menyimpan = true;
      error = null;
    });
    final e = await (pj ? s.tambahPenjualan(t) : s.tambahPembelian(t));
    if (!mounted) return;
    if (e != null) {
      setState(() {
        menyimpan = false;
        error = e;
      });
      return;
    }
    Navigator.pop(context, t);
  }
}

class DetailTransaksiDialog extends StatelessWidget {
  const DetailTransaksiDialog({super.key, required this.t, required this.penjualan});

  final Transaksi t;
  final bool penjualan;

  @override
  Widget build(BuildContext context) {
    Widget info(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted))),
            v,
          ]),
        );
    return AlertDialog(
      title: Text('Detail ${t.kode}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              info('Tanggal', Text(tglBulan(t.tanggal))),
              info(penjualan ? 'Pelanggan' : 'Supplier', Text(t.pihak)),
              info('Daerah', Text(AppScope.read(context).daerahTransaksi(t, penjualan: penjualan))),
              info('Status', StatusBadge(t.status)),
              if (t.catatan.isNotEmpty) info('Catatan', Flexible(child: Text(t.catatan))),
              const SizedBox(height: 12),
              SimpleTable(
                columns: [
                  kol('Kode'),
                  kol('Nama Barang'),
                  kol('Qty', angka: true),
                  kol('Harga', angka: true),
                  kol('Subtotal', angka: true),
                ],
                rows: [
                  for (final i in t.items)
                    DataRow(cells: [
                      sel(i.kodeBarang),
                      sel(i.namaBarang),
                      sel('${i.qty} ${i.satuan}'),
                      sel(rupiah(i.harga)),
                      sel(rupiah(i.subtotal)),
                    ]),
                ],
              ),
              const Divider(),
              Row(children: [
                const Spacer(),
                const Text('Total  ', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(rupiah(t.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              if (penjualan)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Laba kotor: ${rupiah(t.labaKotor)}',
                      style: const TextStyle(color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            bukaFaktur(context, t, penjualan: penjualan);
          },
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Cetak Faktur'),
        ),
      ],
    );
  }
}
