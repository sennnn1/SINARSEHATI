import 'package:flutter/material.dart';

import '../theme.dart';
import 'auth_layout.dart';
import 'auth_service.dart';
import 'login_page.dart';

class DaftarPage extends StatefulWidget {
  const DaftarPage({super.key});

  @override
  State<DaftarPage> createState() => _DaftarPageState();
}

class _DaftarPageState extends State<DaftarPage> {
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nama, _email, _password, _konfirmasi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _daftar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final perluVerifikasi = await AuthScope.read(context).daftar(
        nama: _nama.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        perluVerifikasi
            ? 'Pendaftaran berhasil. Cek email ${_email.text.trim()} untuk verifikasi, lalu login.'
            : 'Pendaftaran berhasil. Silakan login dengan akun baru Anda.',
      );
    } on AuthGagal catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KembaliKeLogin(),
            const SizedBox(height: 12),
            const AuthHeader(
              judul: 'Buat Akun Baru',
              sorot: 'Sinar Sehati',
              deskripsi: 'Lengkapi data di bawah ini untuk mendaftar akun baru.',
            ),
            if (_error != null) PesanBox(_error!),
            TextFormField(
              controller: _nama,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
              decoration: authInput('Nama Lengkap', Icons.person_outline),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: validasiEmail,
              decoration: authInput('Email', Icons.mail_outline),
            ),
            const SizedBox(height: 18),
            PasswordField(
              controller: _password,
              hint: 'Password (min. 6 karakter)',
              textInputAction: TextInputAction.next,
              validator: validasiPassword,
            ),
            const SizedBox(height: 18),
            PasswordField(
              controller: _konfirmasi,
              hint: 'Ulangi Password',
              textInputAction: TextInputAction.done,
              validator: (v) => v != _password.text ? 'Password tidak sama' : null,
              onSubmitted: (_) => _daftar(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Akun baru otomatis mendapat peran Kasir. Admin dapat mengubah peran di menu Pengguna.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            AuthButton(label: 'Daftar Sekarang', icon: Icons.person_add_alt, loading: _loading, onPressed: _daftar),
            const Pemisah(),
            Center(
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text('Login di sini',
                    style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
