import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../shell.dart' show menuUntuk;
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class PenggunaPage extends StatelessWidget {
  const PenggunaPage({super.key});

  static String _hakAkses(String role) =>
      role == 'Owner' ? 'Semua menu' : menuUntuk(role).map((m) => m.label).join(', ');

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Dengan Supabase, daftar ini adalah akun asli; tanpa itu (mode demo)
    // masih data contoh di memori.
    final db = s.penggunaRepo != null;
    final emailSaya = AuthScope.read(context).user?.email.toLowerCase();

    final daftar = [...s.pengguna];
    if (db) {
      // Akun yang perlu perhatian (belum aktif) di atas, lalu yang terbaru.
      daftar.sort((a, b) {
        if (a.aktif != b.aktif) return a.aktif ? 1 : -1;
        return (b.dibuatPada ?? DateTime(2000)).compareTo(a.dibuatPada ?? DateTime(2000));
      });
    }
    final belumAktif = daftar.where((p) => !p.aktif).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Pengguna',
          subtitle: db
              ? 'Atur role dan setujui akun yang mendaftar'
              : 'Kelola akun yang dapat mengakses aplikasi',
          actions: [
            if (db)
              OutlinedButton.icon(
                onPressed: s.muatPenggunaDariSupabase,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Muat Ulang'),
              )
            else
              FilledButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const PenggunaFormDialog()),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Tambah Pengguna'),
              ),
          ],
        ),
        if (db && s.errorPengguna != null)
          _Banner(
            warna: AppColors.red,
            ikon: Icons.cloud_off_outlined,
            teks: s.errorPengguna!,
            aksi: TextButton(onPressed: s.muatPenggunaDariSupabase, child: const Text('Coba lagi')),
          ),
        if (db && belumAktif > 0)
          _Banner(
            warna: AppColors.orange,
            ikon: Icons.hourglass_top_rounded,
            teks: '$belumAktif akun belum aktif: akun baru yang menunggu persetujuan, atau akun yang '
                'dinonaktifkan. Klik ✏ lalu nyalakan "Akun aktif" supaya orangnya bisa login.',
          ),
        SectionCard(
          title: 'Daftar Pengguna (${daftar.length})',
          child: SimpleTable(
            emptyText: db ? 'Belum ada pengguna.' : 'Belum ada data',
            columns: [
              kol('No'),
              if (!db) kol('Username'),
              kol('Email'),
              kol('Nama Lengkap'),
              kol('Role'),
              kol('Hak Akses'),
              if (db) kol('Terdaftar'),
              kol('Status'),
              kol('Aksi'),
            ],
            rows: [
              for (final (i, p) in daftar.indexed)
                DataRow(cells: [
                  sel('${i + 1}'),
                  if (!db) sel(p.username),
                  sel(p.email.isEmpty ? '-' : p.email),
                  sel(p.nama),
                  sel(p.role),
                  selPanjang(_hakAkses(p.role), lebar: 380),
                  if (db) sel(p.dibuatPada == null ? '-' : tgl(p.dibuatPada!)),
                  DataCell(StatusBadge(p.aktif ? 'Aktif' : 'Nonaktif')),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    AksiButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Ubah',
                      color: AppColors.blue,
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => PenggunaFormDialog(
                                pengguna: p,
                                database: db,
                                akunSaya: db && p.email.toLowerCase() == emailSaya,
                              )),
                    ),
                    // Akun asli di Supabase tidak dihapus dari aplikasi; cukup dinonaktifkan.
                    if (!db)
                      AksiButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Hapus',
                        color: AppColors.red,
                        onPressed: () async {
                          if (p.role == 'Owner' && s.pengguna.where((e) => e.role == 'Owner').length == 1) {
                            toast(context, 'Minimal harus ada satu Owner.', error: true);
                            return;
                          }
                          if (p.email == AuthScope.read(context).user?.email) {
                            toast(context, 'Tidak bisa menghapus akun yang sedang dipakai.', error: true);
                            return;
                          }
                          if (!await konfirmasi(context, 'Hapus pengguna ${p.username}?')) return;
                          s.hapusPengguna(p.username);
                        },
                      ),
                  ])),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.warna, required this.ikon, required this.teks, this.aksi});

  final Color warna;
  final IconData ikon;
  final String teks;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.08),
        border: Border.all(color: warna.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(ikon, color: warna),
        const SizedBox(width: 10),
        Expanded(child: Text(teks)),
        ?aksi,
      ]),
    );
  }
}

class PenggunaFormDialog extends StatefulWidget {
  const PenggunaFormDialog({super.key, this.pengguna, this.database = false, this.akunSaya = false});

  final Pengguna? pengguna;

  /// true: mengubah akun asli di Supabase (hanya nama, role, status).
  final bool database;

  /// true: ini akun yang sedang login; role dan status dikunci supaya Owner
  /// tidak mengunci dirinya sendiri.
  final bool akunSaya;

  @override
  State<PenggunaFormDialog> createState() => _PenggunaFormDialogState();
}

class _PenggunaFormDialogState extends State<PenggunaFormDialog> {
  final _form = GlobalKey<FormState>();
  late final username = TextEditingController(text: widget.pengguna?.username);
  late final nama = TextEditingController(text: widget.pengguna?.nama);
  late final email = TextEditingController(text: widget.pengguna?.email);
  late String role = widget.pengguna?.role ?? 'Sales';
  late bool aktif = widget.pengguna?.aktif ?? true;
  bool menyimpan = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    nama.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _simpanDb(AppState s) async {
    if (!_form.currentState!.validate()) return;
    final p = widget.pengguna!;
    setState(() {
      menyimpan = true;
      error = null;
    });
    final e = await s.ubahPenggunaDb(Pengguna(
      id: p.id,
      username: p.username,
      email: p.email,
      nama: nama.text.trim(),
      role: role,
      aktif: aktif,
      dibuatPada: p.dibuatPada,
    ));
    if (!mounted) return;
    if (e != null) {
      setState(() {
        menyimpan = false;
        error = e;
      });
      return;
    }
    toast(context, 'Perubahan ${p.email} tersimpan');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    if (widget.database) return _bangunDb(s);
    return FormDialog(
      title: widget.pengguna == null ? 'Tambah Pengguna' : 'Ubah Pengguna',
      maxWidth: 460,
      onSave: () {
        if (!_form.currentState!.validate()) return;
        s.simpanPengguna(
          Pengguna(
            username: username.text.trim().toLowerCase(),
            nama: nama.text.trim(),
            email: email.text.trim().toLowerCase(),
            role: role,
            aktif: aktif,
          ),
          usernameLama: widget.pengguna?.username,
        );
        Navigator.pop(context);
      },
      child: Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: username,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (v) {
              final u = (v ?? '').trim().toLowerCase();
              if (u.isEmpty) return 'Wajib diisi';
              if (u.contains(' ')) return 'Tidak boleh mengandung spasi';
              if (u != widget.pengguna?.username && s.pengguna.any((e) => e.username == u)) {
                return 'Username sudah dipakai';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nama,
            decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (untuk login)'),
            validator: (v) {
              final e = validasiEmail(v);
              if (e != null) return e;
              final lama = widget.pengguna?.email.toLowerCase();
              final baru = v!.trim().toLowerCase();
              if (baru != lama && s.penggunaDenganEmail(baru) != null) return 'Email sudah dipakai';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [for (final r in AppState.roleList) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => role = v ?? role,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Akun aktif'),
            value: aktif,
            onChanged: (v) => setState(() => aktif = v),
          ),
        ]),
      ),
    );
  }

  /// Form untuk akun asli di Supabase: email tidak bisa diubah dari sini.
  Widget _bangunDb(AppState s) {
    final kunci = widget.akunSaya;
    return FormDialog(
      title: 'Ubah Pengguna',
      maxWidth: 460,
      error: error,
      menyimpan: menyimpan,
      onSave: () => _simpanDb(s),
      child: Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: email,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Email (untuk login)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nama,
            decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [for (final r in AppState.roleList) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: kunci ? null : (v) => setState(() => role = v ?? role),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Akses ${role == 'Owner' ? 'semua menu' : menuUntuk(role).map((m) => m.label).join(', ')}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Akun aktif'),
            subtitle: const Text('Akun yang tidak aktif tidak bisa login'),
            value: aktif,
            onChanged: kunci ? null : (v) => setState(() => aktif = v),
          ),
          if (kunci)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ini akun Anda sendiri, jadi role dan status tidak bisa diubah di sini.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Perubahan role berlaku saat orangnya login ulang atau memuat ulang halaman.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
