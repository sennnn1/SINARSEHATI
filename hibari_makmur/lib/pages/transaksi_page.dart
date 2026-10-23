import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
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

/// Angka persen boleh memakai koma, mis. "2,5" (bukan pemisah ribuan).
double parsePersen(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

/// Input persen: angka dengan satu koma/titik desimal.
final _formatPersen = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,2})?'))];

class _BarisItem {
  String? kode;

  /// Satuan yang dipilih (mis. Dus); null = satuan dasar barang.
  String? satuan;

  /// Isi satu [satuan] dalam satuan dasar, mis. 1 Dus = 36 Bh.
  int isi = 1;
  final qty = TextEditingController(text: '1');

  /// Harga selalu per satuan dasar (per buah / per lusin), walaupun qty dalam Dus.
  final harga = TextEditingController();
  final diskon = TextEditingController();

  int get q => int.tryParse(qty.text) ?? 0;
  int get qDasar => q * isi;
  double get h => parseAngka(harga.text);
  double get d => parsePersen(diskon.text);
  double get bruto => qDasar * h;
  double get subtotal => bruto * (1 - d.clamp(0, 100) / 100);

  void dispose() {
    qty.dispose();
    harga.dispose();
    diskon.dispose();
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
  final diskonFaktur = TextEditingController();

  /// Diskon faktur diisi dalam persen ('%') atau rupiah ('Rp').
  String modeDiskon = '%';
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
    diskonFaktur.dispose();
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
    final subtotal = rows.fold<double>(0, (a, r) => a + r.subtotal);
    final potongan = _potongan(subtotal);
    final total = subtotal - potongan;
    final bruto = rows.fold<double>(0, (a, r) => a + r.bruto);
    final hemat = bruto - total;
    final bolehUbahHarga = AuthScope.of(context).bolehUbahBarang;

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
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hemat > 0)
            Text('Subtotal ${rupiah(bruto)} · Diskon −${rupiah(hemat)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          Text('Total: ${rupiah(total)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.brand)),
        ],
      ),
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
          for (final (i, r) in rows.indexed) _baris(s, i, r, bolehUbahHarga),
          if (!bolehUbahHarga)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Harga mengikuti harga jual di data barang dan tidak dapat diubah oleh Sales.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: lebar(240),
              child: TextField(
                controller: diskonFaktur,
                inputFormatters: modeDiskon == '%' ? _formatPersen : hanyaAngka,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Diskon Faktur',
                  hintText: 'opsional',
                  prefixText: modeDiskon == 'Rp' ? 'Rp ' : null,
                  suffixText: modeDiskon == '%' ? '%' : null,
                  helperText: potongan > 0 ? 'Potongan ${rupiah(potongan)}' : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: '%', label: Text('%')),
                ButtonSegment(value: 'Rp', label: Text('Rp')),
              ],
              selected: {modeDiskon},
              onSelectionChanged: (v) => setState(() {
                modeDiskon = v.first;
                diskonFaktur.clear();
              }),
            ),
          ]),
          const SizedBox(height: 12),
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

  /// Potongan faktur dalam rupiah dari isian diskon faktur.
  double _potongan(double subtotal) {
    final n = modeDiskon == '%'
        ? subtotal * parsePersen(diskonFaktur.text).clamp(0, 100) / 100
        : parseAngka(diskonFaktur.text);
    return n.clamp(0, subtotal).roundToDouble();
  }

  static String _labelBarang(Barang b) => '${b.kode} — ${b.nama}';

  Widget _baris(AppState s, int i, _BarisItem r, bool bolehUbahHarga) {
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
        r.satuan = b.satuan;
        r.isi = 1;
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
          helperText: b == null
              ? null
              : 'Stok: ${angka(b.stok)} ${b.satuan}${b.stokDalamDus() == null ? '' : ' (${b.stokDalamDus()})'}',
        ),
      ),
    );
    final satuan = b == null ? null : r.satuan ?? b.satuan;
    final isi = b == null ? 1 : b.isiSatuan(satuan!);
    // Barang yang punya Kotak/Dus: satuan dipilih langsung di kolom Qty.
    final pilihSatuan = b == null || b.satuanTersedia.length < 2
        ? null
        : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: satuan,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600, fontSize: 14),
              items: [
                for (final st in b.satuanTersedia) DropdownMenuItem(value: st.nama, child: Text(st.nama)),
              ],
              onChanged: (v) => setState(() {
                // Harga tetap per satuan dasar; jumlah = qty × isi × harga.
                r.satuan = v;
                r.isi = b.isiSatuan(v!);
              }),
            ),
          );
    final qty = TextField(
      controller: r.qty,
      inputFormatters: hanyaAngka,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Qty',
        suffixText: pilihSatuan == null ? b?.satuan : null,
        suffixIcon: pilihSatuan == null ? null : Padding(padding: const EdgeInsets.only(right: 8), child: pilihSatuan),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        // Langsung terlihat jumlah buahnya, mis. "= 36 Bh (1 Dus = 36 Bh)".
        helperText: isi > 1 ? '= ${angka(r.qDasar)} ${b!.satuan}  (${b.keteranganIsi(satuan!)})' : null,
        helperStyle: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600),
        helperMaxLines: 2,
      ),
      onChanged: (_) => setState(() {}),
    );
    final harga = TextField(
      controller: r.harga,
      readOnly: !bolehUbahHarga,
      inputFormatters: hanyaAngka,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: b == null ? 'Harga' : 'Harga / ${b.satuan}',
        prefixText: 'Rp ',
        fillColor: bolehUbahHarga ? null : AppColors.bg,
        suffixIcon: bolehUbahHarga ? null : const Icon(Icons.lock_outline, size: 16),
      ),
      onChanged: (_) => setState(() {}),
    );
    final diskon = TextField(
      controller: r.diskon,
      inputFormatters: _formatPersen,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Disc', suffixText: '%', hintText: '0'),
      onChanged: (_) => setState(() {}),
    );
    final subtotal = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(rupiah(r.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (r.d > 0 && r.bruto > 0)
        Text(rupiah(r.bruto),
            style: const TextStyle(
                color: AppColors.muted, fontSize: 11.5, decoration: TextDecoration.lineThrough)),
    ]);
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
        // Layar sempit: barang di atas, lalu qty + harga, lalu diskon + subtotal + hapus.
        if (c.maxWidth < 600) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            barang,
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: qty),
              const SizedBox(width: 8),
              Expanded(child: harga),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(width: 90, child: diskon),
              const SizedBox(width: 12),
              Expanded(child: subtotal),
              hapus,
            ]),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: barang),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: qty),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: harga),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: diskon),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 12), child: subtotal)),
            hapus,
          ],
        );
      }),
    );
  }

  Future<void> _simpan(AppState s, String kode) async {
    final bolehUbahHarga = AuthScope.read(context).bolehUbahBarang;
    String? err;
    final items = <ItemTransaksi>[];
    if (pihak == null) err = 'Pilih ${pj ? 'pelanggan' : 'supplier'} terlebih dahulu.';
    for (final r in rows) {
      if (r.kode == null) continue;
      final b = s.cariBarang(r.kode!);
      if (b == null) continue;
      final isi = b.isiSatuan(r.satuan ?? b.satuan);
      // Harga di form per satuan dasar; disimpan per satuan transaksi (mis. per Dus = × isi).
      // Sales selalu memakai harga jual dari data barang.
      final harga = (bolehUbahHarga ? r.h : b.hargaJual) * isi;
      if (r.q <= 0) err ??= 'Jumlah ${b.nama} harus lebih dari 0.';
      if (harga <= 0) err ??= 'Harga ${b.nama} belum diisi.';
      if (r.d > 100) err ??= 'Diskon ${b.nama} tidak boleh lebih dari 100%.';
      items.add(ItemTransaksi(
        kodeBarang: b.kode,
        namaBarang: b.nama,
        satuan: isi > 1 ? r.satuan! : b.satuan,
        qty: r.q,
        harga: harga,
        diskon: r.d,
        isi: isi,
        satuanDasar: b.satuan,
        hargaPokok: b.hargaBeli * isi,
      ));
    }
    if (items.isEmpty) err ??= 'Tambahkan minimal satu barang.';
    final subtotal = items.fold<double>(0, (a, i) => a + i.subtotal);
    if (modeDiskon == '%' && parsePersen(diskonFaktur.text) > 100) {
      err ??= 'Diskon faktur tidak boleh lebih dari 100%.';
    }
    if (modeDiskon == 'Rp' && parseAngka(diskonFaktur.text) > subtotal) {
      err ??= 'Diskon faktur melebihi subtotal (${rupiah(subtotal)}).';
    }
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
      diskon: _potongan(subtotal),
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
    Widget ringkas(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            const Spacer(),
            Text('$k  ', style: const TextStyle(color: AppColors.muted)),
            Text(v),
          ]),
        );
    final adaDiskonBarang = t.items.any((i) => i.diskon > 0);
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
                  kol('Harga Satuan', angka: true),
                  if (adaDiskonBarang) kol('Disc', angka: true),
                  kol('Subtotal', angka: true),
                ],
                rows: [
                  for (final i in t.items)
                    DataRow(cells: [
                      sel(i.kodeBarang),
                      sel(i.namaBarang),
                      sel(i.isi > 1 ? '${i.qty} ${i.satuan} (${angka(i.qtyDasar)} ${i.satuanDasar})' : '${i.qty} ${i.satuan}'),
                      sel(rupiah(i.hargaDasar)),
                      if (adaDiskonBarang) sel(i.diskon > 0 ? persen(i.diskon) : '-'),
                      sel(rupiah(i.subtotal)),
                    ]),
                ],
              ),
              const Divider(),
              if (t.adaDiskon) ...[
                ringkas('Subtotal', rupiah(t.subtotal + t.diskonBarang)),
                if (t.diskonBarang > 0) ringkas('Diskon barang', '−${rupiah(t.diskonBarang)}'),
                if (t.diskon > 0) ringkas('Diskon faktur', '−${rupiah(t.diskon)}'),
              ],
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
