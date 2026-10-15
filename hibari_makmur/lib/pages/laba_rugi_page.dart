import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class LabaRugiPage extends StatefulWidget {
  const LabaRugiPage({super.key});

  @override
  State<LabaRugiPage> createState() => _LabaRugiPageState();
}

class _LabaRugiPageState extends State<LabaRugiPage> {
  DateTimeRange rentang = rentangBulan(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pj = s.dalam(s.penjualan, rentang).toList();
    final pendapatan = pj.fold<double>(0, (a, t) => a + t.total);
    final hpp = pj.fold<double>(0, (a, t) => a + t.hpp);
    final labaKotor = pendapatan - hpp;
    final biaya = s.biaya.where((b) => dalamRentang(b.tanggal, rentang)).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final totalBiaya = biaya.fold<double>(0, (a, b) => a + b.jumlah);
    final labaBersih = labaKotor - totalBiaya;

    // Biaya digabung per keterangan untuk laporan.
    final biayaPerJenis = <String, double>{};
    for (final b in biaya) {
      biayaPerJenis[b.keterangan] = (biayaPerJenis[b.keterangan] ?? 0) + b.jumlah;
    }

    Widget baris(String label, double nilai,
        {bool tebal = false, bool indent = false, bool kurang = false, Color? warna}) {
      return Padding(
        padding: EdgeInsets.fromLTRB(indent ? 24 : 0, 8, 0, 8),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontWeight: tebal ? FontWeight.w700 : FontWeight.w400, fontSize: tebal ? 15 : 14)),
          ),
          Text(kurang ? '(${rupiah(nilai)})' : rupiah(nilai),
              style: TextStyle(
                  fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
                  fontSize: tebal ? 15 : 14,
                  color: warna)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Laba Rugi',
          subtitle: 'Periode ${tglBulan(rentang.start)} – ${tglBulan(rentang.end)}',
          actions: [
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const _BiayaDialog()),
              icon: const Icon(Icons.add),
              label: const Text('Catat Biaya'),
            ),
          ],
        ),
        RentangTanggalBar(value: rentang, onChanged: (r) => setState(() => rentang = r)),
        const SizedBox(height: 16),
        ResponsiveGrid(children: [
          StatTile(label: 'Pendapatan', value: rupiah(pendapatan), icon: Icons.trending_up),
          StatTile(label: 'Laba Kotor', value: rupiah(labaKotor), icon: Icons.savings_outlined, color: AppColors.blue),
          StatTile(label: 'Biaya Operasional', value: rupiah(totalBiaya), icon: Icons.money_off, color: AppColors.orange),
          StatTile(
            label: labaBersih >= 0 ? 'Laba Bersih' : 'Rugi Bersih',
            value: rupiah(labaBersih),
            icon: Icons.account_balance_outlined,
            color: labaBersih >= 0 ? AppColors.green : AppColors.red,
          ),
        ]),
        const SizedBox(height: 16),
        TwoColumn(
          left: SectionCard(
            title: 'Laporan Laba Rugi',
            icon: Icons.pie_chart_rounded,
            iconColor: AppColors.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                baris('Pendapatan Penjualan', pendapatan, tebal: true),
                baris('Harga Pokok Penjualan (HPP)', hpp, indent: true, kurang: true),
                const Divider(),
                baris('LABA KOTOR', labaKotor, tebal: true, warna: AppColors.blue),
                if (pendapatan > 0)
                  Text('Margin kotor ${(labaKotor / pendapatan * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 12),
                const Text('Biaya Operasional', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (biayaPerJenis.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 0, 8),
                    child: Text('Tidak ada biaya', style: TextStyle(color: AppColors.muted)),
                  ),
                for (final e in biayaPerJenis.entries) baris(e.key, e.value, indent: true, kurang: true),
                baris('Total Biaya Operasional', totalBiaya, kurang: true),
                const Divider(thickness: 2),
                baris(
                  labaBersih >= 0 ? 'LABA BERSIH' : 'RUGI BERSIH',
                  labaBersih,
                  tebal: true,
                  warna: labaBersih >= 0 ? AppColors.green : AppColors.red,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Catatan Biaya',
            icon: Icons.money_off,
            iconColor: AppColors.orange,
            child: SimpleTable(
              perPage: 10,
              emptyText: 'Belum ada biaya pada periode ini',
              columns: [kol('Tanggal'), kol('Keterangan'), kol('Jumlah', angka: true), kol('')],
              rows: [
                for (final b in biaya)
                  DataRow(cells: [
                    sel(tgl(b.tanggal)),
                    sel(b.keterangan),
                    sel(rupiah(b.jumlah)),
                    DataCell(AksiButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Hapus',
                      color: AppColors.red,
                      onPressed: () async {
                        if (await konfirmasi(context, 'Hapus biaya "${b.keterangan}"?')) s.hapusBiaya(b);
                      },
                    )),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BiayaDialog extends StatefulWidget {
  const _BiayaDialog();

  @override
  State<_BiayaDialog> createState() => _BiayaDialogState();
}

class _BiayaDialogState extends State<_BiayaDialog> {
  DateTime tanggal = DateUtils.dateOnly(DateTime.now());
  final ket = TextEditingController();
  final jumlah = TextEditingController();
  String? error;

  @override
  void dispose() {
    ket.dispose();
    jumlah.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Catat Biaya Operasional',
      maxWidth: 440,
      error: error,
      onSave: () {
        if (ket.text.trim().isEmpty || parseAngka(jumlah.text) <= 0) {
          setState(() => error = 'Keterangan dan jumlah wajib diisi.');
          return;
        }
        AppScope.read(context).tambahBiaya(
            Biaya(tanggal: tanggal, keterangan: ket.text.trim(), jumlah: parseAngka(jumlah.text)));
        Navigator.pop(context);
      },
      child: Column(
        children: [
          DateField(label: 'Tanggal', value: tanggal, onChanged: (d) => setState(() => tanggal = d)),
          const SizedBox(height: 12),
          TextField(
            controller: ket,
            decoration: const InputDecoration(labelText: 'Keterangan', hintText: 'mis. Gaji karyawan, Listrik'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: jumlah,
            inputFormatters: hanyaAngka,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '),
          ),
        ],
      ),
    );
  }
}
