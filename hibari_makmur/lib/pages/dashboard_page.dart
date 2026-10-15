import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../shell.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int tahun = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final nav = ShellNav.of(context);
    final now = DateTime.now();
    final ini = rentangBulan(now.year, now.month);
    final lalu = rentangBulan(now.year, now.month - 1);

    final pjIni = s.totalDalam(s.penjualan, ini);
    final pbIni = s.totalDalam(s.pembelian, ini);
    final lkIni = s.labaKotorDalam(ini);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(minItemWidth: 260, children: [
          _StatCard(
            icon: Icons.bar_chart_rounded,
            color: AppColors.green,
            label: 'Total Penjualan',
            value: rupiah(pjIni),
            persen: persenPerubahan(pjIni, s.totalDalam(s.penjualan, lalu)),
          ),
          _StatCard(
            icon: Icons.shopping_cart_outlined,
            color: AppColors.blue,
            label: 'Total Pembelian',
            value: rupiah(pbIni),
            persen: persenPerubahan(pbIni, s.totalDalam(s.pembelian, lalu)),
          ),
          _StatCard(
            icon: Icons.inventory_2_outlined,
            color: AppColors.orange,
            label: 'Nilai Stok Barang',
            value: rupiah(s.nilaiStok),
            catatan: '${s.barang.length} jenis barang',
          ),
          _StatCard(
            icon: Icons.pie_chart_rounded,
            color: AppColors.red,
            label: 'Laba Kotor',
            value: rupiah(lkIni),
            persen: persenPerubahan(lkIni, s.labaKotorDalam(lalu)),
          ),
        ]),
        const SizedBox(height: 16),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: _grafik(s),
          right: _komposisi(s),
        ),
        const SizedBox(height: 16),
        TwoColumn(
          left: _transaksiTerbaru(s.penjualan, true, () => nav.buka('Penjualan')),
          right: _transaksiTerbaru(s.pembelian, false, () => nav.buka('Pembelian')),
        ),
        const SizedBox(height: 16),
        TwoColumn(
          left: _stokMenipis(s, () => nav.buka('Stok Barang')),
          right: _terlaris(s, () => nav.buka('Laporan Penjualan')),
        ),
      ],
    );
  }

  Widget _grafik(AppState s) {
    final pj = List<double>.filled(12, 0);
    final pb = List<double>.filled(12, 0);
    for (final t in s.penjualan) {
      if (t.tanggal.year == tahun) pj[t.tanggal.month - 1] += t.total;
    }
    for (final t in s.pembelian) {
      if (t.tanggal.year == tahun) pb[t.tanggal.month - 1] += t.total;
    }
    return SectionCard(
      title: 'Grafik Penjualan & Pembelian',
      trailing: SizedBox(
        width: 160,
        child: FilterDropdown(
          width: 160,
          value: 'Tahun $tahun',
          items: [for (final y in s.tahunTersedia) 'Tahun $y'],
          onChanged: (v) => setState(() => tahun = int.parse(v.split(' ').last)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Wrap(spacing: 16, children: [
            LegendDot(color: AppColors.green, label: 'Penjualan'),
            LegendDot(color: AppColors.blue, label: 'Pembelian'),
          ]),
          const SizedBox(height: 8),
          GroupedBarChart(
            labels: bulanPendek,
            series: [pj, pb],
            colors: const [AppColors.green, AppColors.blue],
          ),
        ],
      ),
    );
  }

  Widget _komposisi(AppState s) {
    final total = s.barang.fold<int>(0, (a, b) => a + b.stok);
    final perKategori = {
      for (final k in AppState.kategoriList)
        k: s.barang.where((b) => b.kategori == k).fold<int>(0, (a, b) => a + b.stok),
    };
    final legend = Column(
      children: [
        for (final e in perKategori.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: LegendDot(color: AppColors.kategori[e.key]!, label: e.key)),
                Text(
                  total == 0 ? '0%' : '${(e.value / total * 100).round()}%  (${e.value})',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
    final donut = DonutChart(
      values: perKategori.values.map((e) => e.toDouble()).toList(),
      colors: [for (final k in perKategori.keys) AppColors.kategori[k]!],
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const Text('Total Barang', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
    return SectionCard(
      title: 'Komposisi Stok Barang',
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 440) {
          return Column(children: [donut, const SizedBox(height: 12), legend]);
        }
        return Row(children: [donut, const SizedBox(width: 24), Expanded(child: legend)]);
      }),
    );
  }

  Widget _transaksiTerbaru(List<Transaksi> list, bool penjualan, VoidCallback lihat) {
    final data = [...list]..sort((a, b) => b.kode.compareTo(a.kode));
    return SectionCard(
      title: penjualan ? 'Penjualan Terbaru' : 'Pembelian Terbaru',
      icon: penjualan ? Icons.receipt_long : Icons.shopping_cart,
      iconColor: penjualan ? AppColors.red : AppColors.blue,
      trailing: LinkText('Lihat Semua', onTap: lihat),
      child: SimpleTable(
        columns: [
          kol('No'),
          kol('Tanggal'),
          kol('Kode'),
          kol(penjualan ? 'Pelanggan' : 'Supplier'),
          kol('Total'),
          kol('Status'),
        ],
        rows: [
          for (final (i, t) in data.take(5).indexed)
            DataRow(cells: [
              sel('${i + 1}'),
              sel(tgl(t.tanggal)),
              sel(t.kode),
              sel(t.pihak),
              sel(rupiah(t.total)),
              DataCell(StatusBadge(t.status)),
            ]),
        ],
      ),
    );
  }

  Widget _stokMenipis(AppState s, VoidCallback lihat) {
    return SectionCard(
      title: 'Stok Menipis',
      icon: Icons.warning_rounded,
      iconColor: AppColors.red,
      trailing: LinkText('Lihat Semua', onTap: lihat),
      child: SimpleTable(
        emptyText: 'Semua stok aman 👍',
        columns: [kol('No'), kol('Kode'), kol('Nama Barang'), kol('Stok'), kol('Min. Stok'), kol('Satuan')],
        rows: [
          for (final (i, b) in s.stokMenipis.take(5).indexed)
            DataRow(cells: [
              sel('${i + 1}'),
              sel(b.kode),
              sel(b.nama),
              sel('${b.stok}', color: AppColors.red, bold: true),
              sel('${b.minStok}'),
              sel(b.satuan),
            ]),
        ],
      ),
    );
  }

  Widget _terlaris(AppState s, VoidCallback lihat) {
    final data = produkTerlaris(s.penjualan.where((t) => t.tanggal.year == tahun));
    return SectionCard(
      title: 'Produk Terlaris',
      icon: Icons.leaderboard_rounded,
      trailing: LinkText('Lihat Semua', onTap: lihat),
      child: SimpleTable(
        columns: [
          kol('No'),
          kol('Kode'),
          kol('Nama Barang'),
          kol('Terjual', angka: true),
          kol('Satuan'),
          kol('Pendapatan', angka: true),
        ],
        rows: [
          for (final (i, p) in data.take(5).indexed)
            DataRow(cells: [
              sel('${i + 1}'),
              sel(p.kode),
              sel(p.nama),
              sel('${p.qty}'),
              sel(p.satuan),
              sel(rupiah(p.pendapatan)),
            ]),
        ],
      ),
    );
  }
}

class ProdukTerjual {
  ProdukTerjual(this.kode, this.nama, this.satuan);

  final String kode;
  final String nama;
  final String satuan;
  int qty = 0;
  double pendapatan = 0;
}

/// Rekap barang terjual, urut dari qty terbanyak.
List<ProdukTerjual> produkTerlaris(Iterable<Transaksi> penjualan) {
  final map = <String, ProdukTerjual>{};
  for (final t in penjualan) {
    for (final i in t.items) {
      final p = map.putIfAbsent(i.kodeBarang, () => ProdukTerjual(i.kodeBarang, i.namaBarang, i.satuan));
      p.qty += i.qty;
      p.pendapatan += i.subtotal;
    }
  }
  return map.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.persen,
    this.catatan,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final double? persen;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final naik = (persen ?? 0) >= 0;
    final warna = naik ? AppColors.green : AppColors.red;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                if (persen != null)
                  Row(children: [
                    Icon(naik ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: warna),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${persen!.abs().round()}% dari bulan lalu',
                          style: TextStyle(color: warna, fontSize: 13.5)),
                    ),
                  ])
                else
                  Text(catatan ?? 'Bulan lalu belum ada data',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
