import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../shell.dart' show menuUntuk;
import '../theme.dart';
import '../widgets/common.dart';

class PenggunaPage extends StatelessWidget {
  const PenggunaPage({super.key});

  static String _hakAkses(String role) =>
      role == 'Admin' ? 'Semua menu' : menuUntuk(role).map((m) => m.label).join(', ');

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Pengguna',
          subtitle: 'Kelola akun yang dapat mengakses aplikasi',
          actions: [
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const PenggunaFormDialog()),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Tambah Pengguna'),
            ),
          ],
        ),
        SectionCard(
          title: 'Daftar Pengguna',
          child: SimpleTable(
            columns: [
              kol('No'),
              kol('Username'),
              kol('Email'),
              kol('Nama Lengkap'),
              kol('Role'),
              kol('Hak Akses'),
              kol('Status'),
              kol('Aksi'),
            ],
            rows: [
              for (final (i, p) in s.pengguna.indexed)
                DataRow(cells: [
                  sel('${i + 1}'),
                  sel(p.username),
                  sel(p.email.isEmpty ? '-' : p.email),
                  sel(p.nama),
                  sel(p.role),
                  DataCell(SizedBox(width: 260, child: Text(_hakAkses(p.role)))),
                  DataCell(StatusBadge(p.aktif ? 'Aktif' : 'Nonaktif')),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    AksiButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Ubah',
                      color: AppColors.blue,
                      onPressed: () =>
                          showDialog(context: context, builder: (_) => PenggunaFormDialog(pengguna: p)),
                    ),
                    AksiButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Hapus',
                      color: AppColors.red,
                      onPressed: () async {
                        if (p.role == 'Admin' && s.pengguna.where((e) => e.role == 'Admin').length == 1) {
                          toast(context, 'Minimal harus ada satu Admin.', error: true);
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

class PenggunaFormDialog extends StatefulWidget {
  const PenggunaFormDialog({super.key, this.pengguna});

  final Pengguna? pengguna;

  @override
  State<PenggunaFormDialog> createState() => _PenggunaFormDialogState();
}

class _PenggunaFormDialogState extends State<PenggunaFormDialog> {
  final _form = GlobalKey<FormState>();
  late final username = TextEditingController(text: widget.pengguna?.username);
  late final nama = TextEditingController(text: widget.pengguna?.nama);
  late final email = TextEditingController(text: widget.pengguna?.email);
  late String role = widget.pengguna?.role ?? 'Kasir';
  late bool aktif = widget.pengguna?.aktif ?? true;

  @override
  void dispose() {
    username.dispose();
    nama.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
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
}
