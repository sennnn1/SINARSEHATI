import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'dashboard_page.dart' show produkTerlaris;

// ============================================================ Laporan Periodik
class LaporanPeriodikPage extends StatefulWidget {
  const LaporanPeriodikPage({super.key});

  @override
  State<LaporanPeriodikPage> createState() => _LaporanPeriodikPageState();
}

class _LaporanPeriodikPageState extends State<LaporanPeriodikPage> {
  DateTimeRange rentang = rentangTahun(DateTime.now().year);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    // Daftar bulan yang tercakup dalam rentang.
    final bulan = <DateTimeRange>[];
    var d = DateTime(rentang.start.year, rentang.start.month);
    while (!d.isAfter(rentang.end)) {
      final r = rentangBulan(d.year, d.month);
      bulan.add(
        DateTimeRange(
          start: r.start.isBefore(rentang.start) ? rentang.start : r.start,
          end: r.end.isAfter(rentang.end) ? rentang.end : r.end,
        ),
      );
      d = DateTime(d.year, d.month + 1);
    }

    final baris = [
      for (final b in bulan)
        (
          label: '${namaBulan[b.start.month - 1]} ${b.start.year}',
          pendek: bulanPendek[b.start.month - 1],
          pj: s.totalDalam(s.penjualan, b),
          pb: s.totalDalam(s.pembelian, b),
          laba: s.labaKotorDalam(b),
          nPj: s.dalam(s.penjualan, b).length,
          nPb: s.dalam(s.pembelian, b).length,
        ),
    ];
    final totPj = baris.fold<double>(0, (a, b) => a + b.pj);
    final totPb = baris.fold<double>(0, (a, b) => a + b.pb);
    final totLaba = baris.fold<double>(0, (a, b) => a + b.laba);
    final totN = baris.fold<int>(0, (a, b) => a + b.nPj + b.nPb);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Laporan Periodik',
          subtitle: 'Ringkasan penjualan, pembelian, dan laba per bulan',
          actions: [
            UnduhExcelButton(
              onPressed: () => unduhExcel(
                context,
                namaFile: 'Laporan Periodik ${tgl(rentang.start)} sd ${tgl(rentang.end)}',
                judul: 'Laporan Periodik',
                subjudul: 'Periode ${tglBulan(rentang.start)} – ${tglBulan(rentang.end)}',
                header: ['Bulan', 'Penjualan', 'Pembelian', 'Laba Kotor', 'Trx Penjualan', 'Trx Pembelian'],
                rows: [
                  for (final b in baris) [b.label, b.pj, b.pb, b.laba, b.nPj, b.nPb],
                  [
                    'TOTAL',
                    totPj,
                    totPb,
                    totLaba,
                    baris.fold<int>(0, (a, b) => a + b.nPj),
                    baris.fold<int>(0, (a, b) => a + b.nPb),
                  ],
                ],
                format: const {
                  1: FormatKolom.rupiah,
                  2: FormatKolom.rupiah,
                  3: FormatKolom.rupiah,
                  4: FormatKolom.angka,
                  5: FormatKolom.angka,
                },
              ),
            ),
          ],
        ),
        RentangTanggalBar(value: rentang, onChanged: (r) => setState(() => rentang = r)),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            StatTile(label: 'Total Penjualan', value: rupiah(totPj), icon: Icons.trending_up),
            StatTile(
              label: 'Total Pembelian',
              value: rupiah(totPb),
              icon: Icons.shopping_cart_outlined,
              color: AppColors.blue,
            ),
            StatTile(
              label: 'Laba Kotor',
              value: rupiah(totLaba),
              icon: Icons.savings_outlined,
              color: AppColors.orange,
              note: totPj == 0 ? null : 'Margin ${(totLaba / totPj * 100).toStringAsFixed(1)}%',
            ),
            StatTile(label: 'Jumlah Transaksi', value: '$totN', icon: Icons.receipt_long, color: AppColors.red),
          ],
        ),
        const SizedBox(height: 16),
        if (baris.length <= 24)
          SectionCard(
            title: 'Grafik per Bulan',
            trailing: const Wrap(
              spacing: 16,
              children: [
                LegendDot(color: AppColors.green, label: 'Penjualan'),
                LegendDot(color: AppColors.blue, label: 'Pembelian'),
                LegendDot(color: AppColors.orange, label: 'Laba Kotor'),
              ],
            ),
            child: GroupedBarChart(
              labels: [for (final b in baris) b.pendek],
              series: [
                [for (final b in baris) b.pj],
                [for (final b in baris) b.pb],
                [for (final b in baris) b.laba < 0 ? 0 : b.laba],
              ],
              colors: const [AppColors.green, AppColors.blue, AppColors.orange],
            ),
          ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Rincian per Bulan',
          child: SimpleTable(
            columns: [
              kol('Bulan'),
              kol('Trx Jual', angka: true),
              kol('Penjualan', angka: true),
              kol('Trx Beli', angka: true),
              kol('Pembelian', angka: true),
              kol('Laba Kotor', angka: true),
            ],
            rows: [
              for (final b in baris)
                DataRow(
                  cells: [
                    sel(b.label),
                    sel('${b.nPj}'),
                    sel(rupiah(b.pj)),
                    sel('${b.nPb}'),
                    sel(rupiah(b.pb)),
                    sel(rupiah(b.laba), color: b.laba < 0 ? AppColors.red : AppColors.green),
                  ],
                ),
              DataRow(
                color: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                cells: [
                  sel('TOTAL', bold: true),
                  sel('${baris.fold<int>(0, (a, b) => a + b.nPj)}', bold: true),
                  sel(rupiah(totPj), bold: true),
                  sel('${baris.fold<int>(0, (a, b) => a + b.nPb)}', bold: true),
                  sel(rupiah(totPb), bold: true),
                  sel(rupiah(totLaba), bold: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================ Laporan Penjualan / Pembelian
class LaporanTransaksiPage extends StatefulWidget {
  const LaporanTransaksiPage({super.key, required this.penjualan});

  final bool penjualan;

  @override
  State<LaporanTransaksiPage> createState() => _LaporanTransaksiPageState();
}

class _LaporanTransaksiPageState extends State<LaporanTransaksiPage> {
  DateTimeRange rentang = rentangBulan(DateTime.now().year, DateTime.now().month);
  String status = 'Semua';
  String daerah = 'Semua Daerah';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pj = widget.penjualan;
    final data =
        s
            .dalam(pj ? s.penjualan : s.pembelian, rentang)
            .where(
              (t) =>
                  (status == 'Semua' || t.status == status) &&
                  (daerah == 'Semua Daerah' || s.daerahTransaksi(t, penjualan: pj) == daerah),
            )
            .toList()
          ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final daftarDaerah = {
      for (final t in s.dalam(pj ? s.penjualan : s.pembelian, rentang)) s.daerahTransaksi(t, penjualan: pj),
    }.toList()
      ..sort();
    final total = data.fold<double>(0, (a, t) => a + t.total);
    final lunas = data.where((t) => t.lunas).fold<double>(0, (a, t) => a + t.total);
    final labelPihak = pj ? 'Pelanggan' : 'Supplier';

    final rekap = <String, ({int n, double total})>{};
    for (final t in data) {
      final r = rekap[t.pihak];
      rekap[t.pihak] = (n: (r?.n ?? 0) + 1, total: (r?.total ?? 0) + t.total);
    }
    final rekapList = rekap.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: pj ? 'Laporan Penjualan' : 'Laporan Pembelian',
          subtitle: 'Daftar transaksi ${pj ? 'penjualan' : 'pembelian'} pada periode terpilih',
          actions: [
            UnduhExcelButton(
              onPressed: () => unduhExcel(
                context,
                namaFile:
                    '${pj ? 'Laporan Penjualan' : 'Laporan Pembelian'} '
                    '${tgl(rentang.start)} sd ${tgl(rentang.end)}',
                judul: pj ? 'Laporan Penjualan' : 'Laporan Pembelian',
                subjudul:
                    'Periode ${tglBulan(rentang.start)} – ${tglBulan(rentang.end)}'
                    '${status == 'Semua' ? '' : ' · Status $status'}'
                    '${daerah == 'Semua Daerah' ? '' : ' · Daerah $daerah'}',
                header: ['Tanggal', 'No. Faktur', labelPihak, 'Daerah', 'Jumlah Item', 'Total', 'Status'],
                rows: [
                  for (final t in data)
                    [tgl(t.tanggal), t.kode, t.pihak, s.daerahTransaksi(t, penjualan: pj), t.items.length, t.total, t.status],
                ],
                format: const {4: FormatKolom.angka, 5: FormatKolom.rupiah},
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RentangTanggalBar(value: rentang, onChanged: (r) => setState(() => rentang = r)),
            FilterDropdown(
              width: 160,
              value: status,
              items: ['Semua', 'Lunas', pj ? 'Piutang' : 'Hutang'],
              onChanged: (v) => setState(() => status = v),
            ),
            FilterDropdown(
              width: 190,
              value: daftarDaerah.contains(daerah) ? daerah : 'Semua Daerah',
              items: ['Semua Daerah', ...daftarDaerah],
              onChanged: (v) => setState(() => daerah = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            StatTile(
              label: 'Jumlah Transaksi',
              value: '${data.length}',
              icon: Icons.receipt_long,
              color: AppColors.blue,
            ),
            StatTile(
              label: 'Total ${pj ? 'Penjualan' : 'Pembelian'}',
              value: rupiah(total),
              icon: Icons.payments_outlined,
            ),
            StatTile(label: 'Sudah Lunas', value: rupiah(lunas), icon: Icons.check_circle_outline),
            StatTile(
              label: pj ? 'Piutang' : 'Hutang',
              value: rupiah(total - lunas),
              icon: Icons.schedule,
              color: AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: SectionCard(
            title: 'Daftar Transaksi',
            child: SimpleTable(
              perPage: 20,
              emptyText: 'Tidak ada transaksi pada periode ini',
              columns: [
                kol('No'),
                kol('Tanggal'),
                kol('Kode'),
                kol(labelPihak),
                kol('Total', angka: true),
                kol('Status'),
              ],
              rows: [
                for (final (i, t) in data.indexed)
                  DataRow(
                    cells: [
                      sel('${i + 1}'),
                      sel(tgl(t.tanggal)),
                      sel(t.kode),
                      sel(t.pihak),
                      sel(rupiah(t.total)),
                      DataCell(StatusBadge(t.status)),
                    ],
                  ),
              ],
            ),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Rekap per $labelPihak',
                child: SimpleTable(
                  columns: [kol(labelPihak), kol('Trx', angka: true), kol('Total', angka: true)],
                  rows: [
                    for (final e in rekapList)
                      DataRow(cells: [sel(e.key), sel('${e.value.n}'), sel(rupiah(e.value.total))]),
                  ],
                ),
              ),
              if (pj) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Barang Terlaris',
                  icon: Icons.leaderboard_rounded,
                  child: SimpleTable(
                    columns: [kol('Nama Barang'), kol('Terjual', angka: true), kol('Pendapatan', angka: true)],
                    rows: [
                      for (final p in produkTerlaris(data).take(10))
                        DataRow(cells: [sel(p.nama), sel('${p.qty} ${p.satuan}'), sel(rupiah(p.pendapatan))]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================ Laporan Stok
class LaporanStokPage extends StatefulWidget {
  const LaporanStokPage({super.key});

  @override
  State<LaporanStokPage> createState() => _LaporanStokPageState();
}

class _LaporanStokPageState extends State<LaporanStokPage> {
  String kategori = 'Semua Kategori';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final data = s.barang.where((b) => kategori == 'Semua Kategori' || b.kategori == kategori).toList()
      ..sort((a, b) => a.kode.compareTo(b.kode));
    final totalNilai = data.fold<double>(0, (a, b) => a + b.nilaiStok);
    final potensiJual = data.fold<double>(0, (a, b) => a + b.stok * b.hargaJual);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Laporan Stok',
          subtitle: 'Posisi stok dan nilai persediaan per ${tglBulan(DateTime.now())}',
          actions: [
            UnduhExcelButton(
              onPressed: () => unduhExcel(
                context,
                namaFile: 'Laporan Stok ${tgl(DateTime.now())}',
                judul: 'Laporan Stok',
                subjudul:
                    'Per ${tglBulan(DateTime.now())}'
                    '${kategori == 'Semua Kategori' ? '' : ' · Kategori $kategori'}',
                header: ['Kode', 'Nama Barang', 'Kategori', 'Stok', 'Satuan', 'Harga Beli', 'Nilai Stok', 'Status'],
                rows: [
                  for (final b in data)
                    [b.kode, b.nama, b.kategori, b.stok, b.satuan, b.hargaBeli, b.nilaiStok, b.statusStok],
                ],
                format: const {3: FormatKolom.angka, 5: FormatKolom.rupiah, 6: FormatKolom.rupiah},
              ),
            ),
          ],
        ),
        FilterDropdown(
          width: 240,
          value: kategori,
          items: const ['Semua Kategori', ...AppState.kategoriList],
          onChanged: (v) => setState(() => kategori = v),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            StatTile(
              label: 'Jenis Barang',
              value: '${data.length}',
              icon: Icons.category_outlined,
              color: AppColors.blue,
            ),
            StatTile(
              label: 'Total Unit',
              value: angka(data.fold<int>(0, (a, b) => a + b.stok)),
              icon: Icons.inventory_2_outlined,
            ),
            StatTile(
              label: 'Nilai Persediaan (harga beli)',
              value: rupiah(totalNilai),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.orange,
            ),
            StatTile(
              label: 'Potensi Penjualan (harga jual)',
              value: rupiah(potensiJual),
              icon: Icons.sell_outlined,
              color: AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Rincian Persediaan',
          child: SimpleTable.builder(
            perPage: 20,
            columns: [
              kol('No'),
              kol('Kode'),
              kol('Nama Barang'),
              kol('Kategori'),
              kol('Stok', angka: true),
              kol('Satuan'),
              kol('Harga Beli', angka: true),
              kol('Nilai Stok', angka: true),
              kol('Status'),
            ],
            // Baris terakhir adalah TOTAL.
            jumlah: data.length + 1,
            baris: (i) {
              if (i == data.length) return _barisTotal(data, totalNilai);
              final b = data[i];
              return DataRow(
                cells: [
                  sel('${i + 1}'),
                  sel(b.kode),
                  selPanjang(b.nama),
                  sel(b.kategori),
                  sel('${b.stok}'),
                  sel(b.satuan),
                  sel(rupiah(b.hargaBeli)),
                  sel(rupiah(b.nilaiStok)),
                  DataCell(StatusBadge(b.statusStok)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _barisTotal(List<Barang> data, double totalNilai) => DataRow(
    color: const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
    cells: [
      sel(''),
      sel(''),
      sel('TOTAL', bold: true),
      sel(''),
      sel(angka(data.fold<int>(0, (a, b) => a + b.stok)), bold: true),
      sel(''),
      sel(''),
      sel(rupiah(totalNilai), bold: true),
      sel(''),
    ],
  );
}
