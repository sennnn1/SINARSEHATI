import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final _form = GlobalKey<FormState>();
  final nama = TextEditingController();
  final alamat = TextEditingController();
  final telepon = TextEditingController();
  final email = TextEditingController();
  bool _terisi = false;

  void _isiForm() {
    final p = AppScope.read(context).profil;
    nama.text = p.nama;
    alamat.text = p.alamat;
    telepon.text = p.telepon;
    email.text = p.email;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_terisi) return;
    _isiForm();
    _terisi = true;
  }

  @override
  void dispose() {
    for (final c in [nama, alamat, telepon, email]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Pengaturan', subtitle: 'Profil toko dan pengelolaan data aplikasi'),
        TwoColumn(
          left: SectionCard(
            title: 'Profil Toko',
            icon: Icons.storefront_outlined,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nama,
                    decoration: const InputDecoration(labelText: 'Nama Toko'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: alamat,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: telepon, decoration: const InputDecoration(labelText: 'Telepon')),
                  const SizedBox(height: 12),
                  TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!_form.currentState!.validate()) return;
                        s.simpanProfil(ProfilToko(
                          nama: nama.text.trim(),
                          alamat: alamat.text.trim(),
                          telepon: telepon.text.trim(),
                          email: email.text.trim(),
                        ));
                        toast(context, 'Profil toko disimpan');
                      },
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Simpan Profil'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Kategori & Satuan',
                icon: Icons.label_outline,
                iconColor: AppColors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori barang', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final k in AppState.kategoriList)
                        Chip(
                          avatar: CircleAvatar(backgroundColor: AppColors.kategori[k]),
                          label: Text(k),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Satuan', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final k in AppState.satuanList) Chip(label: Text(k)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Data Aplikasi',
                icon: Icons.storage_outlined,
                iconColor: AppColors.orange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${s.barang.length} barang · ${s.penjualan.length} penjualan · '
                      '${s.pembelian.length} pembelian · ${s.pelanggan.length} pelanggan · '
                      '${s.supplier.length} supplier',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Data saat ini masih disimpan di memori (data contoh) dan akan kembali '
                      'seperti semula saat aplikasi dibuka ulang.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                        onPressed: () async {
                          final ok = await konfirmasi(
                            context,
                            'Kembalikan semua data ke data contoh? Perubahan yang sudah dibuat akan hilang.',
                            tombol: 'Reset',
                          );
                          if (!ok) return;
                          s.muatDataContoh();
                          if (context.mounted) {
                            _isiForm();
                            toast(context, 'Data dikembalikan ke data contoh');
                          }
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset ke Data Contoh'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
