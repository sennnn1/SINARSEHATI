import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Ringkasan laba kotor (penjualan − HPP) per periode.
class LabaKotorPage extends StatefulWidget {
  const LabaKotorPage({super.key});

  @override
  State<LabaKotorPage> createState() => _LabaKotorPageState();
}

/// Satu baris rekap: penjualan, HPP, dan qty yang dikelompokkan per kunci.
class _Rekap {
  _Rekap(this.label, {this.sub = ''});

  final String label;
  final String sub;
  double penjualan = 0;
  double hpp = 0;
  int qty = 0;
  int transaksi = 0;

  double get laba => penjualan - hpp;
  double get margin => penjualan == 0 ? 0 : laba / penjualan * 100;
}

const _rincianPilihan = ['Barang', 'Kategori', 'Pelanggan', 'Daerah', 'Transaksi'];

class _LabaKotorPageState extends State<LabaKotorPage> {
  DateTimeRange rentang = rentangBulan(DateTime.now().year, DateTime.now().month);
  String status = 'Semua';
  String rincian = 'Barang';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pj = s.dalam(s.penjualan, rentang).where((t) => status == 'Semua' || t.status == status).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    final kategoriBarang = {for (final b in s.barang) b.kode: b.kategori};
    final perBarang = <String, _Rekap>{};
    final perKategori = <String, _Rekap>{};
    final perPelanggan = <String, _Rekap>{};
    final perDaerah = <String, _Rekap>{};
    var tanpaHpp = 0;
    for (final t in pj) {
      final p = perPelanggan.putIfAbsent(t.pihak, () => _Rekap(t.pihak));
      p.transaksi++;
      final namaDaerah = s.daerahTransaksi(t, penjualan: true);
      final d = perDaerah.putIfAbsent(namaDaerah, () => _Rekap(namaDaerah));
      d.transaksi++;
      for (final i in t.items) {
        final hpp = i.qty * i.hargaPokok;
        if (i.hargaPokok <= 0) tanpaHpp++;
        final kat = kategoriBarang[i.kodeBarang] ?? 'Lainnya';
        for (final r in [
          perBarang.putIfAbsent(i.kodeBarang, () => _Rekap(i.namaBarang, sub: i.kodeBarang)),
          perKategori.putIfAbsent(kat, () => _Rekap(kat)),
          p,
          d,
        ]) {
          r.penjualan += i.subtotal;
          r.hpp += hpp;
          r.qty += i.qty;
        }
      }
    }
    int urut(_Rekap a, _Rekap b) => b.laba.compareTo(a.laba);
    final barang = perBarang.values.toList()..sort(urut);
    final kategori = perKategori.values.toList()..sort(urut);
    final pelanggan = perPelanggan.values.toList()..sort(urut);
    final daerah = perDaerah.values.toList()..sort(urut);
    final rugi = barang.where((b) => b.laba < 0).toList();

    final penjualan = pj.fold<double>(0, (a, t) => a + t.total);
    final hpp = pj.fold<double>(0, (a, t) => a + t.hpp);
    final laba = penjualan - hpp;
    final margin = penjualan == 0 ? 0.0 : laba / penjualan * 100;

    // Pembanding: periode sebelumnya dengan panjang yang sama.
    final hari = rentang.end.difference(rentang.start).inDays + 1;
    final lalu = DateTimeRange(
      start: rentang.start.subtract(Duration(days: hari)),
      end: rentang.start.subtract(const Duration(days: 1)),
    );
    final labaLalu = s
        .dalam(s.penjualan, lalu)
        .where((t) => status == 'Semua' || t.status == status)
        .fold<double>(0, (a, t) => a + t.labaKotor);
    final perubahan = persenPerubahan(laba, labaLalu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Laba Kotor',
          subtitle:
              'Penjualan dikurangi harga pokok (HPP), '
              'periode ${tglBulan(rentang.start)} – ${tglBulan(rentang.end)}',
          actions: [UnduhExcelButton(onPressed: () => _unduh(context, pj, barang, kategori, pelanggan, daerah))],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RentangTanggalBar(value: rentang, onChanged: (r) => setState(() => rentang = r)),
            FilterDropdown(
              value: status,
              width: 170,
              items: const ['Semua', 'Lunas', 'Piutang'],
              onChanged: (v) => setState(() => status = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            StatTile(
              label: 'Total Penjualan',
              value: rupiah(penjualan),
              icon: Icons.trending_up,
              note: '${pj.length} transaksi',
            ),
            StatTile(
              label: 'Harga Pokok (HPP)',
              value: rupiah(hpp),
              icon: Icons.inventory_2_outlined,
              color: AppColors.blue,
            ),
            StatTile(
              label: 'Laba Kotor',
              value: rupiah(laba),
              icon: Icons.savings_outlined,
              color: laba >= 0 ? AppColors.orange : AppColors.red,
              note: perubahan == null
                  ? 'Periode lalu ${rupiah(labaLalu)}'
                  : '${perubahan >= 0 ? '▲' : '▼'} ${perubahan.abs().toStringAsFixed(1)}% dari periode lalu',
            ),
            StatTile(
              label: 'Margin Kotor',
              value: '${margin.toStringAsFixed(1)}%',
              icon: Icons.percent,
              color: AppColors.red,
              note: pj.isEmpty ? null : 'Rata-rata ${rupiah(laba / pj.length)} / transaksi',
            ),
          ],
        ),
        if (tanpaHpp > 0 || rugi.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Peringatan(tanpaHpp: tanpaHpp, rugi: rugi),
        ],
        const SizedBox(height: 16),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: _grafik(pj),
          right: SectionCard(
            title: 'Laba per Kategori',
            icon: Icons.donut_large,
            iconColor: AppColors.orange,
            child: _donutKategori(kategori, laba),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Rincian Laba Kotor',
          icon: Icons.table_chart_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Bisa digeser di layar sempit (HP).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [for (final r in _rincianPilihan) ButtonSegment(value: r, label: Text('Per $r'))],
                selected: {rincian},
                onSelectionChanged: (v) => setState(() => rincian = v.first),
              ),
            ),
            const SizedBox(height: 12),
            switch (rincian) {
              'Transaksi' => _tabelTransaksi(pj),
              'Kategori' => _tabelRekap(kategori, 'Kategori'),
              'Pelanggan' => _tabelRekap(pelanggan, 'Pelanggan', kolomTrx: true),
              'Daerah' => _tabelRekap(daerah, 'Daerah', kolomTrx: true),
              _ => _tabelRekap(barang, 'Barang', kolomKode: true),
            },
          ]),
        ),
      ],
    );
  }

  /// Per hari kalau rentang ≤ 31 hari, selain itu per bulan.
  Widget _grafik(List<Transaksi> pj) {
    final harian = rentang.end.difference(rentang.start).inDays < 31;
    final titik = <DateTime>[];
    if (harian) {
      for (var d = DateUtils.dateOnly(rentang.start); !d.isAfter(rentang.end); d = d.add(const Duration(days: 1))) {
        titik.add(d);
      }
    } else {
      for (
        var d = DateTime(rentang.start.year, rentang.start.month);
        !d.isAfter(rentang.end);
        d = DateTime(d.year, d.month + 1)
      ) {
        titik.add(d);
      }
    }
    final jual = List<double>.filled(titik.length, 0);
    final laba = List<double>.filled(titik.length, 0);
    for (final t in pj) {
      final i = harian
          ? DateUtils.dateOnly(t.tanggal).difference(titik.first).inDays
          : (t.tanggal.year - titik.first.year) * 12 + t.tanggal.month - titik.first.month;
      if (i < 0 || i >= titik.length) continue;
      jual[i] += t.total;
      laba[i] += t.labaKotor;
    }
    final terlaluBanyak = titik.length > 36;
    return SectionCard(
      title: harian ? 'Laba Kotor per Hari' : 'Laba Kotor per Bulan',
      icon: Icons.bar_chart_rounded,
      trailing: const Wrap(
        spacing: 16,
        children: [
          LegendDot(color: AppColors.green, label: 'Penjualan'),
          LegendDot(color: AppColors.orange, label: 'Laba Kotor'),
        ],
      ),
      child: terlaluBanyak
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Rentang terlalu panjang untuk grafik. Persempit periodenya.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : GroupedBarChart(
              labels: [for (final d in titik) harian ? '${d.day}' : bulanPendek[d.month - 1]],
              series: [
                jual,
                [for (final v in laba) v < 0 ? 0 : v],
              ],
              colors: const [AppColors.green, AppColors.orange],
            ),
    );
  }

  Widget _donutKategori(List<_Rekap> kategori, double total) {
    final positif = kategori.where((k) => k.laba > 0).toList();
    if (positif.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Belum ada laba pada periode ini', style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    Color warna(String k) => AppColors.kategori[k] ?? AppColors.kategori['Lainnya']!;
    return Column(
      children: [
        DonutChart(
          values: [for (final k in positif) k.laba],
          colors: [for (final k in positif) warna(k.label)],
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Laba Kotor', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              Text(rupiah(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final k in positif)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: LegendDot(color: warna(k.label), label: k.label),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${rupiah(k.laba)}  (${k.margin.toStringAsFixed(1)}%)',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tabelRekap(List<_Rekap> data, String judul, {bool kolomKode = false, bool kolomTrx = false}) {
    return SimpleTable.builder(
      perPage: 10,
      emptyText: 'Belum ada penjualan pada periode ini',
      columns: [
        kol('No', angka: true),
        if (kolomKode) kol('Kode'),
        kol(judul),
        if (kolomTrx) kol('Trx', angka: true),
        kol('Qty', angka: true),
        kol('Penjualan', angka: true),
        kol('HPP', angka: true),
        kol('Laba Kotor', angka: true),
        kol('Margin', angka: true),
      ],
      jumlah: data.length,
      baris: (i) {
        final r = data[i];
        return DataRow(
          cells: [
            sel('${i + 1}'),
            if (kolomKode) sel(r.sub),
            selPanjang(r.label, lebar: 280),
            if (kolomTrx) sel('${r.transaksi}'),
            sel(angka(r.qty)),
            sel(rupiah(r.penjualan)),
            sel(rupiah(r.hpp)),
            sel(rupiah(r.laba), color: r.laba < 0 ? AppColors.red : AppColors.green, bold: true),
            sel('${r.margin.toStringAsFixed(1)}%', color: r.laba < 0 ? AppColors.red : null),
          ],
        );
      },
    );
  }

  Widget _tabelTransaksi(List<Transaksi> pj) {
    return SimpleTable.builder(
      perPage: 10,
      emptyText: 'Belum ada penjualan pada periode ini',
      columns: [
        kol('Tanggal'),
        kol('No. Faktur'),
        kol('Pelanggan'),
        kol('Status'),
        kol('Penjualan', angka: true),
        kol('HPP', angka: true),
        kol('Laba Kotor', angka: true),
        kol('Margin', angka: true),
      ],
      jumlah: pj.length,
      baris: (i) {
        final t = pj[i];
        final m = t.total == 0 ? 0 : t.labaKotor / t.total * 100;
        return DataRow(
          cells: [
            sel(tgl(t.tanggal)),
            sel(t.kode),
            sel(t.pihak),
            DataCell(StatusBadge(t.status)),
            sel(rupiah(t.total)),
            sel(rupiah(t.hpp)),
            sel(rupiah(t.labaKotor), color: t.labaKotor < 0 ? AppColors.red : AppColors.green, bold: true),
            sel('${m.toStringAsFixed(1)}%'),
          ],
        );
      },
    );
  }

  void _unduh(
    BuildContext context,
    List<Transaksi> pj,
    List<_Rekap> barang,
    List<_Rekap> kategori,
    List<_Rekap> pelanggan,
    List<_Rekap> daerah,
  ) {
    const kolom = ['Penjualan', 'HPP', 'Laba Kotor', 'Margin'];
    List<Object> nilai(_Rekap r) => [r.penjualan, r.hpp, r.laba, r.margin];
    // [awal] = indeks kolom Penjualan; tiga kolom rupiah lalu satu kolom persen.
    Map<int, FormatKolom> fmt(int awal, {List<int> angka = const []}) => {
      for (final a in angka) a: FormatKolom.angka,
      awal: FormatKolom.rupiah,
      awal + 1: FormatKolom.rupiah,
      awal + 2: FormatKolom.rupiah,
      awal + 3: FormatKolom.persen,
    };
    final (header, rows, format) = switch (rincian) {
      'Transaksi' => (
        ['Tanggal', 'No. Faktur', 'Pelanggan', 'Status', ...kolom],
        [
          for (final t in pj)
            <Object>[
              tgl(t.tanggal),
              t.kode,
              t.pihak,
              t.status,
              t.total,
              t.hpp,
              t.labaKotor,
              t.total == 0 ? 0 : t.labaKotor / t.total * 100,
            ],
        ],
        fmt(4),
      ),
      'Kategori' => (
        ['Kategori', 'Qty', ...kolom],
        [
          for (final r in kategori) <Object>[r.label, r.qty, ...nilai(r)],
        ],
        fmt(2, angka: [1]),
      ),
      'Pelanggan' => (
        ['Pelanggan', 'Transaksi', 'Qty', ...kolom],
        [
          for (final r in pelanggan) <Object>[r.label, r.transaksi, r.qty, ...nilai(r)],
        ],
        fmt(3, angka: [1, 2]),
      ),
      'Daerah' => (
        ['Daerah', 'Transaksi', 'Qty', ...kolom],
        [
          for (final r in daerah) <Object>[r.label, r.transaksi, r.qty, ...nilai(r)],
        ],
        fmt(3, angka: [1, 2]),
      ),
      _ => (
        ['Kode', 'Barang', 'Qty', ...kolom],
        [
          for (final r in barang) <Object>[r.sub, r.label, r.qty, ...nilai(r)],
        ],
        fmt(3, angka: [2]),
      ),
    };
    unduhExcel(
      context,
      namaFile: 'Laba Kotor per $rincian ${tgl(rentang.start)} sd ${tgl(rentang.end)}',
      judul: 'Laba Kotor per $rincian',
      subjudul:
          'Periode ${tglBulan(rentang.start)} – ${tglBulan(rentang.end)}'
          '${status == 'Semua' ? '' : ' · Status $status'}',
      header: header,
      rows: rows,
      format: format,
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan({required this.tanpaHpp, required this.rugi});

  final int tanpaHpp;
  final List<_Rekap> rugi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        border: Border.all(color: const Color(0xFFF5D08A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tanpaHpp > 0)
                  Text(
                    '$tanpaHpp item terjual tanpa harga pokok (harga beli Rp 0), '
                    'jadi laba kotornya terhitung terlalu besar. Isi harga beli di Data Barang.',
                  ),
                if (rugi.isNotEmpty)
                  Text(
                    '${rugi.length} barang dijual di bawah harga pokok: '
                    '${rugi.take(3).map((r) => r.label).join(', ')}${rugi.length > 3 ? ', …' : ''}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
