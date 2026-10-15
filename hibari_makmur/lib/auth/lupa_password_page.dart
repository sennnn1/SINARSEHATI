import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'auth_layout.dart';
import 'auth_service.dart';
import 'demo_auth_service.dart';
import 'login_page.dart';

/// Lupa password dalam 2 langkah:
/// 1. Masukkan email → kode 6 digit dikirim ke email.
/// 2. Masukkan kode + password baru.
class LupaPasswordPage extends StatefulWidget {
  const LupaPasswordPage({super.key, this.emailAwal = ''});

  final String emailAwal;

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage> {
  final _formEmail = GlobalKey<FormState>();
  final _formReset = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailAwal);
  final _kode = TextEditingController();
  final _password = TextEditingController();
  final _konfirmasi = TextEditingController();

  bool _kodeTerkirim = false;
  bool _loading = false;
  String? _error;
  String? _info;

  /// Detik tersisa sebelum boleh kirim ulang kode.
  int _tunggu = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _kode, _password, _konfirmasi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _mulaiHitungMundur() {
    _timer?.cancel();
    setState(() => _tunggu = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _tunggu--);
      if (_tunggu <= 0) t.cancel();
    });
  }

  Future<void> _proses(Future<void> Function() aksi) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await aksi();
    } on AuthGagal catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kirimKode() async {
    if (!_kodeTerkirim && !_formEmail.currentState!.validate()) return;
    final auth = AuthScope.read(context);
    await _proses(() async {
      await auth.kirimKodeReset(_email.text);
      if (!mounted) return;
      var info = 'Jika email ${_email.text.trim()} terdaftar, kode 6 digit telah dikirim. '
          'Cek kotak masuk atau folder spam.';
      if (auth is DemoAuthService) {
        info = auth.kodeTerakhir == null
            ? 'Mode demo: email ini tidak terdaftar, jadi tidak ada kode yang dibuat.'
            : 'Mode demo: email tidak benar-benar dikirim. Kode Anda: ${auth.kodeTerakhir}';
      }
      setState(() {
        _kodeTerkirim = true;
        _info = info;
      });
      _mulaiHitungMundur();
    });
  }

  Future<void> _simpan() async {
    if (!_formReset.currentState!.validate()) return;
    final auth = AuthScope.read(context);
    await _proses(() async {
      await auth.resetPassword(email: _email.text, kode: _kode.text, passwordBaru: _password.text);
      if (mounted) Navigator.pop(context, 'Password berhasil diubah. Silakan login dengan password baru.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KembaliKeLogin(),
          const SizedBox(height: 12),
          AuthHeader(
            judul: 'Lupa Password',
            sorot: _kodeTerkirim ? 'Buat Password Baru' : 'Atur Ulang Akun',
            deskripsi: _kodeTerkirim
                ? 'Masukkan kode 6 digit dari email beserta password baru Anda.'
                : 'Masukkan email akun Anda. Kami akan mengirim kode untuk mengatur ulang password.',
          ),
          _Langkah(aktif: _kodeTerkirim ? 2 : 1),
          const SizedBox(height: 20),
          if (_info != null) PesanBox(_info!, sukses: true),
          if (_error != null) PesanBox(_error!),
          if (!_kodeTerkirim) _langkahEmail() else _langkahReset(),
        ],
      ),
    );
  }

  Widget _langkahEmail() {
    return Form(
      key: _formEmail,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _email,
          autofocus: _email.text.isEmpty,
          keyboardType: TextInputType.emailAddress,
          validator: validasiEmail,
          onFieldSubmitted: (_) => _kirimKode(),
          decoration: authInput('Email', Icons.mail_outline),
        ),
        const SizedBox(height: 24),
        AuthButton(label: 'Kirim Kode', icon: Icons.send_outlined, loading: _loading, onPressed: _kirimKode),
      ]),
    );
  }

  Widget _langkahReset() {
    return Form(
      key: _formReset,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.mail_outline, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(_email.text.trim(), style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _kodeTerkirim = false;
                      _info = null;
                      _error = null;
                    }),
            child: const Text('Ganti email'),
          ),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: _kode,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w600),
          validator: (v) => (v ?? '').length != 6 ? 'Kode harus 6 digit' : null,
          decoration: authInput('Kode 6 digit', Icons.pin_outlined).copyWith(
            counterText: '',
            hintStyle: const TextStyle(fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.w400),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _tunggu > 0 || _loading ? null : _kirimKode,
            child: Text(_tunggu > 0 ? 'Kirim ulang kode ($_tunggu dtk)' : 'Kirim ulang kode'),
          ),
        ),
        PasswordField(
          controller: _password,
          hint: 'Password baru (min. 6 karakter)',
          textInputAction: TextInputAction.next,
          validator: validasiPassword,
        ),
        const SizedBox(height: 18),
        PasswordField(
          controller: _konfirmasi,
          hint: 'Ulangi password baru',
          textInputAction: TextInputAction.done,
          validator: (v) => v != _password.text ? 'Password tidak sama' : null,
          onSubmitted: (_) => _simpan(),
        ),
        const SizedBox(height: 24),
        AuthButton(label: 'Simpan Password Baru', icon: Icons.check, loading: _loading, onPressed: _simpan),
      ]),
    );
  }
}

/// Indikator langkah 1 – 2.
class _Langkah extends StatelessWidget {
  const _Langkah({required this.aktif});

  final int aktif;

  @override
  Widget build(BuildContext context) {
    Widget bulat(int n, String label) {
      final on = n <= aktif;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: on ? AppColors.brand : AppColors.border,
          child: n < aktif
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text('$n', style: TextStyle(fontSize: 12.5, color: on ? Colors.white : AppColors.muted)),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: on ? AppColors.text : AppColors.muted, fontSize: 13)),
      ]);
    }

    return Row(children: [
      bulat(1, 'Email'),
      Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: aktif > 1 ? AppColors.brand : AppColors.border,
        ),
      ),
      bulat(2, 'Password baru'),
    ]);
  }
}
