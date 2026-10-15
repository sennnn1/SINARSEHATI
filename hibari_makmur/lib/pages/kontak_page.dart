import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
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

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sup = widget.supplier;
    final label = sup ? 'Supplier' : 'Pelanggan';
    final transaksi = sup ? s.pembelian : s.penjualan;
    final q = cari.toLowerCase();
    final data = (sup ? s.supplier : s.pelanggan)
        .where((k) =>
            q.isEmpty ||
            k.nama.toLowerCase().contains(q) ||
            k.kode.toLowerCase().contains(q) ||
            k.telepon.contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Data $label',
          subtitle: sup ? 'Daftar pemasok barang' : 'Daftar pelanggan toko',
          actions: [
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => KontakFormDialog(supplier: sup)),
              icon: const Icon(Icons.add),
              label: Text('Tambah $label'),
            ),
          ],
        ),
        SectionCard(
          title: 'Daftar $label (${data.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SearchBox(hint: 'Cari kode / nama / telepon', onChanged: (v) => setState(() => cari = v)),
              ),
              const SizedBox(height: 12),
              SimpleTable(
                perPage: 15,
                columns: [
                  kol('No'),
                  kol('Kode'),
                  kol('Nama $label'),
                  kol('Telepon'),
                  kol('Alamat'),
                  kol('Jml Trx', angka: true),
                  kol('Total Transaksi', angka: true),
                  kol(sup ? 'Hutang' : 'Piutang', angka: true),
                  kol('Aksi'),
                ],
                rows: [
                  for (final (i, k) in data.indexed)
                    () {
                      final trx = transaksi.where((t) => t.pihak == k.nama);
                      final belum = trx.where((t) => !t.lunas).fold<double>(0, (a, t) => a + t.total);
                      return DataRow(cells: [
                        sel('${i + 1}'),
                        sel(k.kode),
                        sel(k.nama),
                        sel(k.telepon.isEmpty ? '-' : k.telepon),
                        sel(k.alamat.isEmpty ? '-' : k.alamat),
                        sel('${trx.length}'),
                        sel(rupiah(trx.fold<double>(0, (a, t) => a + t.total))),
                        sel(rupiah(belum), color: belum > 0 ? AppColors.orange : null),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          AksiButton(
                            icon: Icons.edit_outlined,
                            tooltip: 'Ubah',
                            color: AppColors.blue,
                            onPressed: () => showDialog(
                                context: context, builder: (_) => KontakFormDialog(supplier: sup, kontak: k)),
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
                        ])),
                      ]);
                    }(),
                ],
              ),
            ],
          ),
        ),
      ],
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
        );
        s.simpanKontak(widget.supplier, k, kodeLama: widget.kontak?.kode);
        Navigator.pop(context);
        toast(context, '${k.nama} tersimpan');
      },
      child: Form(
        key: _form,
        child: Column(children: [
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
        ]),
      ),
    );
  }
}
