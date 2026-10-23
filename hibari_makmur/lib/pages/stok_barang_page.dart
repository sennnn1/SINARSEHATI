import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'data_barang_page.dart' show BarangFormDialog;

class StokBarangPage extends StatefulWidget {
  const StokBarangPage({super.key});

  @override
  State<StokBarangPage> createState() => _StokBarangPageState();
}

class _StokBarangPageState extends State<StokBarangPage> {
  String cari = '';
  String kategori = 'Semua Kategori';
  String status = 'Semua Status';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = cari.toLowerCase();
    final data = s.barang
        .where((b) =>
            (kategori == 'Semua Kategori' || b.kategori == kategori) &&
            (status == 'Semua Status' || b.statusStok == status) &&
            (q.isEmpty || b.nama.toLowerCase().contains(q) || b.kode.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.kode.compareTo(b.kode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Stok Barang',
          subtitle: 'Pantau jumlah stok, tambah barang baru, dan lakukan penyesuaian (stock opname)',
          actions: [
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const BarangFormDialog()),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            ),
          ],
        ),
        ResponsiveGrid(children: [
          StatTile(
            label: 'Jenis Barang',
            value: '${angka(s.barang.length)} barang',
            icon: Icons.category_outlined,
            color: AppColors.blue,
          ),
          StatTile(
            label: 'Total Unit Stok',
            value: angka(s.barang.fold<int>(0, (a, b) => a + b.stok)),
            note: 'Nilai stok ${rupiah(s.nilaiStok)}',
            icon: Icons.inventory_2_outlined,
          ),
          StatTile(
            label: 'Stok Menipis',
            value: '${s.barang.where((b) => b.statusStok == 'Menipis').length} barang',
            icon: Icons.warning_amber_rounded,
            color: AppColors.orange,
          ),
          StatTile(
            label: 'Stok Habis',
            value: '${s.barang.where((b) => b.statusStok == 'Habis').length} barang',
            icon: Icons.remove_shopping_cart_outlined,
            color: AppColors.red,
          ),
        ]),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Daftar Stok',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                SearchBox(hint: 'Cari kode / nama barang', onChanged: (v) => setState(() => cari = v)),
                FilterDropdown(
                  width: 230,
                  value: kategori,
                  items: const ['Semua Kategori', ...AppState.kategoriList],
                  onChanged: (v) => setState(() => kategori = v),
                ),
                FilterDropdown(
                  width: 170,
                  value: status,
                  items: const ['Semua Status', 'Aman', 'Menipis', 'Habis'],
                  onChanged: (v) => setState(() => status = v),
                ),
              ]),
              const SizedBox(height: 12),
              if (s.memuatBarang) const LinearProgressIndicator(),
              SimpleTable.builder(
                perPage: 15,
                columns: [
                  kol('No'),
                  kol('Kode'),
                  kol('Nama Barang'),
                  kol('Kategori'),
                  kol('Stok', angka: true),
                  kol('Min. Stok', angka: true),
                  kol('Satuan'),
                  kol('Status'),
                  kol('Aksi'),
                ],
                jumlah: data.length,
                baris: (i) {
                  final b = data[i];
                  return DataRow(cells: [
                    sel('${i + 1}'),
                    sel(b.kode),
                    selPanjang(b.nama),
                    sel(b.kategori),
                    sel('${b.stok}',
                        color: b.stok <= b.minStok ? AppColors.red : null, bold: b.stok <= b.minStok),
                    sel('${b.minStok}'),
                    sel(b.satuan),
                    DataCell(StatusBadge(b.statusStok)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => _PenyesuaianDialog(b: b)),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Sesuaikan'),
                      ),
                      AksiButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Ubah data barang',
                        color: AppColors.blue,
                        onPressed: () =>
                            showDialog(context: context, builder: (_) => BarangFormDialog(barang: b)),
                      ),
                    ])),
                  ]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Riwayat Mutasi Stok',
          icon: Icons.history,
          iconColor: AppColors.blue,
          child: SimpleTable(
            perPage: 10,
            emptyText: 'Belum ada mutasi. Mutasi tercatat otomatis saat ada transaksi atau penyesuaian.',
            columns: [
              kol('Tanggal'),
              kol('Kode'),
              kol('Nama Barang'),
              kol('Perubahan', angka: true),
              kol('Stok Akhir', angka: true),
              kol('Keterangan'),
            ],
            rows: [
              for (final m in s.mutasi)
                DataRow(cells: [
                  sel(tgl(m.tanggal)),
                  sel(m.kodeBarang),
                  sel(m.namaBarang),
                  sel(m.perubahan > 0 ? '+${m.perubahan}' : '${m.perubahan}',
                      color: m.perubahan >= 0 ? AppColors.green : AppColors.red, bold: true),
                  sel('${m.stokAkhir}'),
                  sel(m.keterangan),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _PenyesuaianDialog extends StatefulWidget {
  const _PenyesuaianDialog({required this.b});

  final Barang b;

  @override
  State<_PenyesuaianDialog> createState() => _PenyesuaianDialogState();
}

class _PenyesuaianDialogState extends State<_PenyesuaianDialog> {
  String jenis = 'Tambah';
  final jumlah = TextEditingController();
  final ket = TextEditingController();
  String? error;

  @override
  void dispose() {
    jumlah.dispose();
    ket.dispose();
    super.dispose();
  }

  int get stokBaru {
    final n = int.tryParse(jumlah.text) ?? 0;
    return switch (jenis) {
      'Tambah' => widget.b.stok + n,
      'Kurangi' => widget.b.stok - n,
      _ => n,
    };
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    return FormDialog(
      title: 'Penyesuaian Stok — ${b.nama}',
      maxWidth: 460,
      error: error,
      onSave: () {
        if (jumlah.text.isEmpty) return setState(() => error = 'Isi jumlah terlebih dahulu.');
        if (stokBaru < 0) return setState(() => error = 'Stok tidak boleh kurang dari 0.');
        final keterangan = ket.text.trim().isEmpty ? 'Penyesuaian stok' : ket.text.trim();
        AppScope.read(context).sesuaikanStok(b.kode, stokBaru, keterangan);
        Navigator.pop(context);
        toast(context, 'Stok ${b.nama} sekarang $stokBaru ${b.satuan}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stok saat ini: ${b.stok} ${b.satuan}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Tambah', label: Text('Tambah'), icon: Icon(Icons.add)),
              ButtonSegment(value: 'Kurangi', label: Text('Kurangi'), icon: Icon(Icons.remove)),
              ButtonSegment(value: 'Set', label: Text('Set Jumlah'), icon: Icon(Icons.edit)),
            ],
            selected: {jenis},
            onSelectionChanged: (v) => setState(() => jenis = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: jumlah,
            autofocus: true,
            inputFormatters: hanyaAngka,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Jumlah', suffixText: b.satuan),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ket,
            decoration: const InputDecoration(
                labelText: 'Keterangan', hintText: 'mis. Stock opname, barang rusak'),
          ),
          const SizedBox(height: 12),
          Text('Stok setelah penyesuaian: $stokBaru ${b.satuan}',
              style: TextStyle(color: stokBaru < 0 ? AppColors.red : AppColors.green)),
        ],
      ),
    );
  }
}
