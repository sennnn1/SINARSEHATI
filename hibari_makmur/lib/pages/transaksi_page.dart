import 'package:flutter/material.dart';

import '../data/app_state.dart';
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
    final data = semua
        .where((t) =>
            (status == 'Semua' || t.status == status) &&
            (q.isEmpty || t.kode.toLowerCase().contains(q) || t.pihak.toLowerCase().contains(q)))
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
                  hint: pj ? 'Cari kode / pelanggan' : 'Cari kode / supplier',
                  onChanged: (v) => setState(() => cari = v),
                ),
                FilterDropdown(
                  width: 170,
                  value: status,
                  items: ['Semua', 'Lunas', belumLunas],
                  onChanged: (v) => setState(() => status = v),
                ),
              ]),
              const SizedBox(height: 12),
              SimpleTable(
                perPage: 15,
                columns: [
                  kol('No'),
                  kol('Tanggal'),
                  kol('Kode'),
                  kol(pj ? 'Pelanggan' : 'Supplier'),
                  kol('Item', angka: true),
                  kol('Total', angka: true),
                  kol('Status'),
                  kol('Aksi'),
                ],
                rows: [
                  for (final (i, t) in data.indexed)
                    DataRow(cells: [
                      sel('${i + 1}'),
                      sel(tgl(t.tanggal)),
                      sel(t.kode),
                      sel(t.pihak),
                      sel('${t.items.length}'),
                      sel(rupiah(t.total)),
                      DataCell(StatusBadge(t.status)),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
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
                            s.hapusTransaksi(t, isPenjualan: pj);
                            if (context.mounted) toast(context, '${t.kode} dihapus');
                          },
                        ),
                      ])),
                    ]),
                ],
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
    if (t != null && context.mounted) {
      toast(context, 'Transaksi ${t.kode} tersimpan (${rupiah(t.total)})');
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
  final rows = <_BarisItem>[_BarisItem()];
  String? error;

  bool get pj => widget.penjualan;

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kode = pj ? s.kodePenjualanBaru : s.kodePembelianBaru;
    final daftarPihak = (pj ? s.pelanggan : s.supplier).map((e) => e.nama).toList();
    final total = rows.fold<double>(0, (a, r) => a + r.subtotal);

    return FormDialog(
      title: '${pj ? 'Penjualan' : 'Pembelian'} Baru — $kode',
      maxWidth: 860,
      error: error,
      onSave: () => _simpan(s, kode),
      footer: Text('Total: ${rupiah(total)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.green)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 200,
              child: DateField(
                  label: 'Tanggal', value: tanggal, onChanged: (d) => setState(() => tanggal = d)),
            ),
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<String>(
                initialValue: pihak,
                isExpanded: true,
                decoration: InputDecoration(labelText: pj ? 'Pelanggan' : 'Supplier'),
                items: [for (final p in daftarPihak) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() => pihak = v),
              ),
            ),
            SizedBox(
              width: 180,
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
          for (final (i, r) in rows.indexed) _baris(s, i, r),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => rows.add(_BarisItem())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: catatan,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
        ],
      ),
    );
  }

  Widget _baris(AppState s, int i, _BarisItem r) {
    final b = r.kode == null ? null : s.cariBarang(r.kode!);
    return Padding(
      key: ObjectKey(r),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: DropdownButtonFormField<String>(
              initialValue: r.kode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Barang ${i + 1}',
                helperText: b == null ? null : 'Stok: ${b.stok} ${b.satuan}',
              ),
              items: [
                for (final b in s.barang)
                  DropdownMenuItem(value: b.kode, child: Text('${b.kode} — ${b.nama}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                r.kode = v;
                final b = v == null ? null : s.cariBarang(v);
                if (b != null) {
                  r.harga.text = (pj ? b.hargaJual : b.hargaBeli).round().toString();
                }
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: r.qty,
              inputFormatters: hanyaAngka,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Qty', suffixText: b?.satuan),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.harga,
              inputFormatters: hanyaAngka,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga', prefixText: 'Rp '),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(rupiah(r.subtotal),
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: 'Hapus baris',
            onPressed: rows.length == 1
                ? null
                : () => setState(() {
                      rows.removeAt(i).dispose();
                    }),
            icon: const Icon(Icons.close, color: AppColors.red),
          ),
        ],
      ),
    );
  }

  void _simpan(AppState s, String kode) {
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
    );
    if (pj) {
      final e = s.tambahPenjualan(t);
      if (e != null) {
        setState(() => error = e);
        return;
      }
    } else {
      s.tambahPembelian(t);
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
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    );
  }
}
