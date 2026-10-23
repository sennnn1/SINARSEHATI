import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class DataBarangPage extends StatefulWidget {
  const DataBarangPage({super.key});

  @override
  State<DataBarangPage> createState() => _DataBarangPageState();
}

class _DataBarangPageState extends State<DataBarangPage> {
  String cari = '';
  String kategori = 'Semua Kategori';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = cari.toLowerCase();
    final data = s.barang
        .where((b) =>
            (kategori == 'Semua Kategori' || b.kategori == kategori) &&
            (q.isEmpty || b.nama.toLowerCase().contains(q) || b.kode.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.kode.compareTo(b.kode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Data Barang',
          subtitle: 'Kelola master data barang, harga, dan batas minimum stok',
          actions: [
            FilledButton.icon(
              onPressed: () => _form(context),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            ),
          ],
        ),
        SectionCard(
          title: 'Daftar Barang (${data.length})',
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
                  kol('Satuan'),
                  kol('Harga Beli', angka: true),
                  kol('Harga Jual', angka: true),
                  kol('Stok', angka: true),
                  kol('Min.', angka: true),
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
                    sel([
                      b.satuan,
                      for (final st in b.satuanTersedia.skip(1)) b.keteranganIsi(st.nama),
                    ].join(' · ')),
                    sel(rupiah(b.hargaBeli)),
                    sel(rupiah(b.hargaJual)),
                    sel('${b.stok}', color: b.stok <= b.minStok ? AppColors.red : null),
                    sel('${b.minStok}'),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      AksiButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Ubah',
                        color: AppColors.blue,
                        onPressed: () => _form(context, b),
                      ),
                      AksiButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Hapus',
                        color: AppColors.red,
                        onPressed: () async {
                          if (!await konfirmasi(context, 'Hapus barang ${b.nama}?')) return;
                          s.hapusBarang(b.kode);
                          if (context.mounted) toast(context, '${b.nama} dihapus');
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

  void _form(BuildContext context, [Barang? b]) {
    showDialog(context: context, builder: (_) => BarangFormDialog(barang: b));
  }
}

class BarangFormDialog extends StatefulWidget {
  const BarangFormDialog({super.key, this.barang});

  final Barang? barang;

  @override
  State<BarangFormDialog> createState() => _BarangFormDialogState();
}

class _BarangFormDialogState extends State<BarangFormDialog> {
  final _form = GlobalKey<FormState>();
  late final kode = TextEditingController(text: widget.barang?.kode);
  late final nama = TextEditingController(text: widget.barang?.nama);
  late final beli = TextEditingController(text: widget.barang?.hargaBeli.round().toString());
  late final jual = TextEditingController(text: widget.barang?.hargaJual.round().toString());
  late final stok = TextEditingController(text: '${widget.barang?.stok ?? 0}');
  late final minStok = TextEditingController(text: '${widget.barang?.minStok ?? 10}');
  late final isiKotak = TextEditingController(text: _isi(widget.barang?.isiKotak));
  late final isiDus = TextEditingController(text: _isi(widget.barang?.isiDus));

  static String _isi(int? n) => n == null || n <= 0 ? '' : '$n';
  late String kategori = widget.barang?.kategori ?? AppState.kategoriList.first;
  late String satuan = widget.barang?.satuan ?? AppState.satuanList.first;

  bool get edit => widget.barang != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!edit && kode.text.isEmpty) kode.text = AppScope.read(context).kodeBarangBaru;
  }

  @override
  void dispose() {
    for (final c in [kode, nama, beli, jual, stok, minStok, isiKotak, isiDus]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _wajib(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  Widget _isiField(TextEditingController c, String nama, {required bool enabled}) => TextFormField(
        controller: c,
        enabled: enabled,
        inputFormatters: hanyaAngka,
        decoration: InputDecoration(
          labelText: 'Isi per $nama (opsional)',
          suffixText: satuan,
          helperText: enabled ? 'mis. 1 $nama = 12 $satuan; kosongkan kalau tidak ada' : 'Sudah jadi satuan dasar',
          helperMaxLines: 2,
        ),
        validator: (v) =>
            (v ?? '').isNotEmpty && (int.tryParse(v!) ?? 0) == 1 ? 'Isi harus lebih dari 1' : null,
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    Widget dua(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ]),
        );

    return FormDialog(
      title: edit ? 'Ubah Barang' : 'Tambah Barang',
      maxWidth: 600,
      onSave: () {
        if (!_form.currentState!.validate()) return;
        final b = Barang(
          kode: kode.text.trim().toUpperCase(),
          nama: nama.text.trim(),
          kategori: kategori,
          satuan: satuan,
          stok: int.tryParse(stok.text) ?? 0,
          minStok: int.tryParse(minStok.text) ?? 0,
          hargaBeli: parseAngka(beli.text),
          hargaJual: parseAngka(jual.text),
          isiKotak: int.tryParse(isiKotak.text) ?? 0,
          isiDus: int.tryParse(isiDus.text) ?? 0,
        );
        s.simpanBarang(b, kodeLama: widget.barang?.kode);
        Navigator.pop(context);
        toast(context, '${b.nama} tersimpan');
      },
      child: Form(
        key: _form,
        child: Column(
          children: [
            dua(
              TextFormField(
                controller: kode,
                decoration: const InputDecoration(labelText: 'Kode Barang'),
                validator: (v) {
                  final e = _wajib(v);
                  if (e != null) return e;
                  final k = v!.trim().toUpperCase();
                  if (k != widget.barang?.kode && s.cariBarang(k) != null) return 'Kode sudah dipakai';
                  return null;
                },
              ),
              TextFormField(
                controller: nama,
                decoration: const InputDecoration(labelText: 'Nama Barang'),
                validator: _wajib,
              ),
            ),
            dua(
              DropdownButtonFormField<String>(
                initialValue: kategori,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [for (final k in AppState.kategoriList) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (v) => kategori = v ?? kategori,
              ),
              DropdownButtonFormField<String>(
                initialValue: satuan,
                decoration: const InputDecoration(
                  labelText: 'Satuan Dasar',
                  helperText: 'Satuan stok & harga (Pcs, Lusin, Kotak, ...)',
                ),
                items: [
                  for (final k in {...AppState.satuanList, satuan}) DropdownMenuItem(value: k, child: Text(k)),
                ],
                onChanged: (v) => setState(() => satuan = v ?? satuan),
              ),
            ),
            dua(
              TextFormField(
                controller: beli,
                inputFormatters: hanyaAngka,
                decoration: InputDecoration(labelText: 'Harga Beli per $satuan', prefixText: 'Rp '),
                validator: _wajib,
              ),
              TextFormField(
                controller: jual,
                inputFormatters: hanyaAngka,
                decoration: InputDecoration(labelText: 'Harga Jual per $satuan', prefixText: 'Rp '),
                validator: (v) {
                  final e = _wajib(v);
                  if (e != null) return e;
                  if (parseAngka(v!) < parseAngka(beli.text)) return 'Harga jual di bawah harga beli';
                  return null;
                },
              ),
            ),
            dua(
              TextFormField(
                controller: stok,
                enabled: !edit,
                inputFormatters: hanyaAngka,
                decoration: InputDecoration(
                  labelText: 'Stok Awal',
                  helperText: edit ? 'Ubah stok lewat menu Stok Barang' : null,
                ),
              ),
              TextFormField(
                controller: minStok,
                inputFormatters: hanyaAngka,
                decoration: const InputDecoration(labelText: 'Minimal Stok'),
                validator: _wajib,
              ),
            ),
            // Kotak / Dus: beli atau jual per kotak/dus, stok tetap dihitung dalam satuan dasar.
            dua(
              _isiField(isiKotak, 'Kotak', enabled: satuan != 'Kotak'),
              _isiField(isiDus, 'Dus', enabled: satuan != 'Dus'),
            ),
          ],
        ),
      ),
    );
  }
}
