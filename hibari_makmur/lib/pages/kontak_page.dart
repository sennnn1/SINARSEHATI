import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Halaman Data Supplier (supplier: true) atau Data Pelanggan (supplier: false).
class KontakPage extends StatefulWidget {
  const KontakPage({super.key, required this.supplier});

  final bool supplier;

  @override
  State<KontakPage> createState() => _KontakPageState();
}

class _KontakPageState extends State<KontakPage> {
  String cari = '';
  String daerah = 'Semua Daerah';
  int tahun = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sup = widget.supplier;
    final label = sup ? 'Supplier' : 'Pelanggan';
    final transaksi = sup ? s.pembelian : s.penjualan;
    final now = DateTime.now();
    // Dikelompokkan sekali per nama, supaya tiap baris tidak menyaring ulang
    // semua transaksi.
    final perPihak = <String, List<Transaksi>>{};
    for (final t in transaksi) {
      (perPihak[t.pihak] ??= []).add(t);
    }
    final q = cari.toLowerCase();
    final semua = sup ? s.supplier : s.pelanggan;
    final daftarDaerah = {
      for (final k in semua) k.daerah.trim().isEmpty ? AppState.tanpaDaerah : k.daerah.trim(),
    }.toList()..sort();
    if (daerah != 'Semua Daerah' && !daftarDaerah.contains(daerah)) daerah = 'Semua Daerah';
    final data = semua
        .where(
          (k) =>
              (daerah == 'Semua Daerah' ||
                  (k.daerah.trim().isEmpty ? AppState.tanpaDaerah : k.daerah.trim()) == daerah) &&
              (q.isEmpty ||
                  k.nama.toLowerCase().contains(q) ||
                  k.kode.toLowerCase().contains(q) ||
                  k.daerah.toLowerCase().contains(q) ||
                  k.telepon.contains(q)),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Data $label',
          subtitle: sup ? 'Daftar pemasok barang' : 'Daftar pelanggan toko',
          actions: [
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => KontakFormDialog(supplier: sup),
              ),
              icon: const Icon(Icons.add),
              label: Text('Tambah $label'),
            ),
          ],
        ),
        if (!sup && s.errorPelanggan != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, color: AppColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.errorPelanggan!, style: const TextStyle(color: AppColors.red)),
                ),
                TextButton(onPressed: s.muatPelangganDariSupabase, child: const Text('Coba lagi')),
              ],
            ),
          ),
        SectionCard(
          title: 'Daftar $label (${data.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SearchBox(hint: 'Cari kode / nama / daerah / telepon', onChanged: (v) => setState(() => cari = v)),
                  FilterDropdown(
                    width: 190,
                    value: daerah,
                    items: ['Semua Daerah', ...daftarDaerah],
                    onChanged: (v) => setState(() => daerah = v),
                  ),
                  FilterDropdown(
                    width: 160,
                    value: 'Tahun $tahun',
                    items: [for (final y in s.tahunTersedia) 'Tahun $y'],
                    onChanged: (v) => setState(() => tahun = int.parse(v.split(' ').last)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SimpleTable.builder(
                perPage: 15,
                columns: [
                  kol('No'),
                  kol('Kode'),
                  kol('Nama $label'),
                  kol('Daerah'),
                  kol('Telepon'),
                  kol('Alamat'),
                  kol('Belanja ${bulanPendek[now.month - 1]}', angka: true),
                  kol('Total $tahun', angka: true),
                  kol('Trx $tahun', angka: true),
                  kol(sup ? 'Hutang' : 'Piutang', angka: true),
                  kol('Aksi'),
                ],
                jumlah: data.length,
                baris: (i) {
                  final k = data[i];
                  final trx = perPihak[k.nama] ?? const <Transaksi>[];
                  final setahun = trx.where((t) => t.tanggal.year == tahun).toList();
                  final bulanIni = trx
                      .where((t) => t.tanggal.year == now.year && t.tanggal.month == now.month)
                      .fold<double>(0, (a, t) => a + t.total);
                  final belum = trx.where((t) => !t.lunas).fold<double>(0, (a, t) => a + t.total);
                  return DataRow(
                    cells: [
                      sel('${i + 1}'),
                      sel(k.kode),
                      selPanjang(k.nama, lebar: 170),
                      sel(k.daerah.isEmpty ? '-' : k.daerah),
                      sel(k.telepon.isEmpty ? '-' : k.telepon),
                      selPanjang(k.alamat.isEmpty ? '-' : k.alamat, lebar: 150),
                      sel(rupiah(bulanIni)),
                      sel(rupiah(setahun.fold<double>(0, (a, t) => a + t.total)), bold: true),
                      sel('${setahun.length}'),
                      sel(rupiah(belum), color: belum > 0 ? AppColors.orange : null),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AksiButton(
                              icon: Icons.bar_chart_rounded,
                              tooltip: 'Rincian belanja per bulan',
                              color: AppColors.brand,
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => RincianBelanjaDialog(kontak: k, supplier: sup, tahunAwal: tahun),
                              ),
                            ),
                            AksiButton(
                              icon: Icons.edit_outlined,
                              tooltip: 'Ubah',
                              color: AppColors.blue,
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => KontakFormDialog(supplier: sup, kontak: k),
                              ),
                            ),
                            AksiButton(
                              icon: Icons.delete_outline,
                              tooltip: 'Hapus',
                              color: AppColors.red,
                              onPressed: () async {
                                if (!await konfirmasi(context, 'Hapus $label ${k.nama}?')) return;
                                s.hapusKontak(sup, k.kode);
                                if (context.mounted) toast(context, '${k.nama} dihapus');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Berapa banyak satu pelanggan (atau supplier) berbelanja: per bulan dalam
/// setahun, total setahun, rata-rata per bulan, dan bulan tertinggi.
class RincianBelanjaDialog extends StatefulWidget {
  const RincianBelanjaDialog({super.key, required this.kontak, required this.supplier, required this.tahunAwal});

  final Kontak kontak;
  final bool supplier;
  final int tahunAwal;

  @override
  State<RincianBelanjaDialog> createState() => _RincianBelanjaDialogState();
}

class _RincianBelanjaDialogState extends State<RincianBelanjaDialog> {
  late int tahun = widget.tahunAwal;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final trx = (widget.supplier ? s.pembelian : s.penjualan)
        .where((t) => t.pihak == widget.kontak.nama && t.tanggal.year == tahun)
        .toList();
    final perBulan = List<double>.filled(12, 0);
    final jumlah = List<int>.filled(12, 0);
    for (final t in trx) {
      perBulan[t.tanggal.month - 1] += t.total;
      jumlah[t.tanggal.month - 1]++;
    }
    final total = perBulan.fold<double>(0, (a, b) => a + b);
    final now = DateTime.now();
    // Rata-rata dihitung dari bulan yang sudah berjalan (tahun ini) atau 12 bulan.
    final nBulan = tahun == now.year ? now.month : 12;
    var tertinggi = 0;
    for (var m = 1; m < 12; m++) {
      if (perBulan[m] > perBulan[tertinggi]) tertinggi = m;
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rincian Belanja — ${widget.kontak.nama}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilterDropdown(
                    width: 150,
                    value: 'Tahun $tahun',
                    items: [for (final y in s.tahunTersedia) 'Tahun $y'],
                    onChanged: (v) => setState(() => tahun = int.parse(v.split(' ').last)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              ResponsiveGrid(
                children: [
                  StatTile(
                    label: 'Total Belanja $tahun',
                    value: rupiah(total),
                    note: '${trx.length} transaksi',
                    icon: Icons.payments_outlined,
                    color: AppColors.green,
                  ),
                  StatTile(
                    label: 'Rata-rata per Bulan',
                    value: rupiah(total / nBulan),
                    note: 'dari $nBulan bulan',
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.blue,
                  ),
                  StatTile(
                    label: 'Bulan Tertinggi',
                    value: total == 0 ? '-' : namaBulan[tertinggi],
                    note: total == 0 ? 'belum ada transaksi' : rupiah(perBulan[tertinggi]),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GroupedBarChart(labels: bulanPendek, series: [perBulan], colors: const [AppColors.green], height: 220),
              const SizedBox(height: 16),
              SimpleTable(
                columns: [kol('Bulan'), kol('Jml Trx', angka: true), kol('Total Belanja', angka: true)],
                rows: [
                  for (var m = 0; m < 12; m++)
                    DataRow(
                      cells: [
                        sel('${namaBulan[m]} $tahun'),
                        sel('${jumlah[m]}'),
                        sel(rupiah(perBulan[m]), bold: perBulan[m] > 0),
                      ],
                    ),
                  DataRow(
                    color: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                    cells: [sel('TOTAL', bold: true), sel('${trx.length}', bold: true), sel(rupiah(total), bold: true)],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KontakFormDialog extends StatefulWidget {
  const KontakFormDialog({super.key, required this.supplier, this.kontak});

  final bool supplier;
  final Kontak? kontak;

  @override
  State<KontakFormDialog> createState() => _KontakFormDialogState();
}

class _KontakFormDialogState extends State<KontakFormDialog> {
  final _form = GlobalKey<FormState>();
  late final kode = TextEditingController(text: widget.kontak?.kode);
  late final nama = TextEditingController(text: widget.kontak?.nama);
  late final telepon = TextEditingController(text: widget.kontak?.telepon);
  late final alamat = TextEditingController(text: widget.kontak?.alamat);
  late String daerah = widget.kontak?.daerah ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.kontak == null && kode.text.isEmpty) {
      kode.text = AppScope.read(context).kodeKontakBaru(widget.supplier);
    }
  }

  @override
  void dispose() {
    for (final c in [kode, nama, telepon, alamat]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final label = widget.supplier ? 'Supplier' : 'Pelanggan';
    final list = widget.supplier ? s.supplier : s.pelanggan;
    return FormDialog(
      title: '${widget.kontak == null ? 'Tambah' : 'Ubah'} $label',
      onSave: () {
        if (!_form.currentState!.validate()) return;
        final k = Kontak(
          kode: kode.text.trim().toUpperCase(),
          nama: nama.text.trim(),
          telepon: telepon.text.trim(),
          alamat: alamat.text.trim(),
          daerah: s.rapikanDaerah(daerah),
        );
        s.simpanKontak(widget.supplier, k, kodeLama: widget.kontak?.kode);
        Navigator.pop(context);
        toast(context, '${k.nama} tersimpan');
      },
      child: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: kode,
              decoration: const InputDecoration(labelText: 'Kode'),
              validator: (v) {
                final k = (v ?? '').trim().toUpperCase();
                if (k.isEmpty) return 'Wajib diisi';
                if (k != widget.kontak?.kode && list.any((e) => e.kode == k)) return 'Kode sudah dipakai';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nama,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'Nama $label'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            // Bisa pilih dari saran atau ketik daerah baru.
            Autocomplete<String>(
              initialValue: TextEditingValue(text: daerah),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                final pilihan = {...s.daerahTerpakai, ...AppState.daerahSaran};
                return pilihan.where((d) => d.toLowerCase().contains(q)).take(20);
              },
              onSelected: (v) => daerah = v,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                controller: controller,
                focusNode: focus,
                onFieldSubmitted: (_) => onSubmit(),
                onChanged: (v) => daerah = v,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Daerah / Kota',
                  hintText: 'mis. Banda Aceh, Medan',
                  suffixIcon: Icon(Icons.place_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: telepon,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telepon'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: alamat,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
          ],
        ),
      ),
    );
  }
}
