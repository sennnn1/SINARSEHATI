import 'package:flutter/material.dart';

import '../theme.dart';
import 'auth_layout.dart';
import 'auth_service.dart';
import 'daftar_page.dart';
import 'demo_auth_service.dart';
import 'lupa_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      // Kalau berhasil, AuthGate otomatis berpindah ke dashboard.
      await AuthScope.read(context).login(_email.text, _password.text);
    } on AuthGagal catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Membuka halaman lain dan menampilkan pesan yang dikembalikan (mis. "Password berhasil diubah").
  Future<void> _buka(Widget page) async {
    final pesan = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => page));
    if (pesan != null && mounted) {
      setState(() {
        _info = pesan;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return AuthLayout(
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                judul: 'Selamat Datang di',
                sorot: 'Sinar Sehati',
                deskripsi: 'Silakan login untuk mengakses akun Anda dan kelola toko dengan lebih mudah.',
              ),
              if (_info != null) PesanBox(_info!, sukses: true),
              if (_error != null) PesanBox(_error!),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: validasiEmail,
                decoration: authInput('Email', Icons.person_outline),
              ),
              const SizedBox(height: 18),
              PasswordField(
                controller: _password,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v ?? '').isEmpty ? 'Password wajib diisi' : null,
                onSubmitted: (_) => _login(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _buka(LupaPasswordPage(emailAwal: _email.text.trim())),
                  child: const Text('Lupa password?', style: TextStyle(color: AppColors.text)),
                ),
              ),
              const SizedBox(height: 4),
              AuthButton(label: 'Login', icon: Icons.arrow_forward, loading: _loading, onPressed: _login),
              const Pemisah(),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Belum punya akun? ', style: TextStyle(color: AppColors.muted)),
                  InkWell(
                    onTap: () => _buka(const DaftarPage()),
                    child: const Text('Daftar sekarang',
                        style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (auth.isDemo) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Mode demo (belum terhubung ke Supabase)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Data & akun hanya tersimpan sementara selama aplikasi terbuka.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        _email.text = DemoAuthService.emailDemo;
                        _password.text = DemoAuthService.passwordDemo;
                      },
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Isi akun Owner demo'),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tautan "← Kembali ke Login" di atas form.
class KembaliKeLogin extends StatelessWidget {
  const KembaliKeLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: AppColors.muted, padding: EdgeInsets.zero),
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Kembali ke Login'),
      ),
    );
  }
}
