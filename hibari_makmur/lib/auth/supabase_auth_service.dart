import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_service.dart';

/// Login memakai Supabase Auth.
///
/// Persiapan di dashboard Supabase:
/// 1. Authentication → Providers → Email: aktif.
/// 2. Authentication → Email Templates → "Reset Password": ganti isinya agar
///    memuat kode OTP, misalnya: `Kode reset password Anda: {{ .Token }}`
///    (aplikasi meminta pengguna mengetik kode ini, jadi tidak perlu deep link).
/// 3. Role pengguna disimpan di user metadata `role` (default Kasir). Ubah lewat
///    Authentication → Users → user → Edit user metadata, mis. {"role":"Admin"}.
class SupabaseAuthService extends AuthService {
  SupabaseAuthService() {
    _sub = _auth.onAuthStateChange.listen((s) {
      if (_sedangReset) return;
      _user = _dariSupabase(s.session?.user);
      notifyListeners();
    });
    _user = _dariSupabase(_auth.currentUser);
  }

  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;
  late final StreamSubscription<sb.AuthState> _sub;
  AuthUser? _user;

  /// Selama reset password, verifikasi OTP membuat sesi sementara; jangan
  /// sampai aplikasi langsung masuk ke dashboard.
  bool _sedangReset = false;

  @override
  AuthUser? get user => _sedangReset ? null : _user;

  @override
  bool get isDemo => false;

  AuthUser? _dariSupabase(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AuthUser(
      email: u.email ?? '',
      nama: (meta['nama'] as String?) ?? (u.email ?? '').split('@').first,
      role: (meta['role'] as String?) ?? 'Kasir',
    );
  }

  Future<T> _jalankan<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on sb.AuthException catch (e) {
      throw AuthGagal(_terjemahkan(e.message));
    } catch (_) {
      throw const AuthGagal('Tidak dapat terhubung ke server. Periksa koneksi internet.');
    }
  }

  String _terjemahkan(String m) {
    final s = m.toLowerCase();
    if (s.contains('invalid login')) return 'Email atau password salah.';
    if (s.contains('email not confirmed')) return 'Email belum diverifikasi. Cek kotak masuk email Anda.';
    if (s.contains('already registered')) return 'Email sudah terdaftar.';
    if (s.contains('expired') || s.contains('invalid') && s.contains('token')) {
      return 'Kode salah atau sudah kedaluwarsa.';
    }
    if (s.contains('rate limit') || s.contains('security purposes')) {
      return 'Terlalu sering mencoba. Tunggu sebentar lalu coba lagi.';
    }
    if (s.contains('should be different')) return 'Password baru harus berbeda dari password lama.';
    return m;
  }

  @override
  Future<void> login(String email, String password) => _jalankan(() async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  @override
  Future<bool> daftar({required String nama, required String email, required String password}) =>
      _jalankan(() async {
        final r = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'nama': nama.trim(), 'role': 'Kasir'},
        );
        // Jika "Confirm email" aktif, session null sampai email diverifikasi.
        if (r.session != null) await _auth.signOut();
        return r.session == null;
      });

  @override
  Future<void> kirimKodeReset(String email) =>
      _jalankan(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> resetPassword({
    required String email,
    required String kode,
    required String passwordBaru,
  }) async {
    _sedangReset = true;
    try {
      await _jalankan(() async {
        await _auth.verifyOTP(email: email.trim(), token: kode.trim(), type: sb.OtpType.recovery);
        await _auth.updateUser(sb.UserAttributes(password: passwordBaru));
        await _auth.signOut();
      });
    } finally {
      _sedangReset = false;
      _user = _dariSupabase(_auth.currentUser);
      notifyListeners();
    }
  }

  @override
  Future<void> logout() => _jalankan(() => _auth.signOut());

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
