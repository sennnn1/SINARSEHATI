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
/// 3. Role & status akun disimpan di tabel `pengguna` (jalankan supabase/pengguna.sql).
///    Owner mengubahnya dari menu Pengguna di aplikasi. Kalau tabelnya belum ada,
///    sementara dipakai role dari user metadata `role`.
class SupabaseAuthService extends AuthService {
  SupabaseAuthService() {
    _sub = _auth.onAuthStateChange.listen((s) async {
      if (_sedangReset) return;
      final u = s.session?.user;
      if (u == null) {
        _user = null;
      } else {
        // Role dibaca ulang tiap sesi diperbarui, jadi perubahan role atau
        // penonaktifan akun ikut berlaku tanpa menunggu login ulang.
        try {
          _user = await _muat(u);
        } catch (_) {
          // Gagal membaca profil (mis. internet putus sesaat): jangan keluarkan
          // pengguna yang sedang bekerja; sesi berikutnya dicoba lagi.
        }
      }
      notifyListeners();
    });
    final u = _auth.currentUser;
    if (u != null) {
      _menyiapkan = true;
      _muat(u).then<void>((v) => _user = v).catchError((_) => _user = null).whenComplete(() {
        _menyiapkan = false;
        notifyListeners();
      });
    }
  }

  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;
  late final StreamSubscription<sb.AuthState> _sub;
  AuthUser? _user;
  bool _menyiapkan = false;

  /// Alasan akun ditolak masuk (nonaktif / belum disetujui), untuk pesan login.
  String? _alasanTolak;

  /// Selama reset password, verifikasi OTP membuat sesi sementara; jangan
  /// sampai aplikasi langsung masuk ke dashboard.
  bool _sedangReset = false;

  @override
  AuthUser? get user => _sedangReset ? null : _user;

  @override
  bool get menyiapkan => _menyiapkan;

  @override
  bool get isDemo => false;

  /// Mengambil nama, role, dan status dari tabel `pengguna`. Akun yang tidak
  /// aktif langsung dikeluarkan dan hasilnya null.
  Future<AuthUser?> _muat(sb.User u) async {
    final meta = u.userMetadata ?? const {};
    var nama = (meta['nama'] as String?) ?? (u.email ?? '').split('@').first;
    var role = _role(meta['role'] as String?);
    try {
      final row = await sb.Supabase.instance.client
          .from('pengguna')
          .select('nama, role, aktif')
          .eq('id', u.id)
          .maybeSingle();
      if (row == null || row['aktif'] != true) {
        _alasanTolak = 'Akun Anda belum aktif atau dinonaktifkan. Hubungi Owner untuk mengaktifkannya.';
        await _auth.signOut();
        return null;
      }
      nama = (row['nama'] as String?)?.trim().isNotEmpty == true ? row['nama'] as String : nama;
      role = _role(row['role'] as String?);
    } on sb.PostgrestException catch (e) {
      // Tabel belum dibuat (pengguna.sql belum dijalankan): pakai user metadata.
      if (e.code != '42P01' && e.code != 'PGRST205') rethrow;
    }
    _alasanTolak = null;
    return AuthUser(email: u.email ?? '', nama: nama, role: role);
  }

  /// Role lama (Kasir/Gudang) dipetakan ke role baru.
  static String _role(String? r) => switch (r) {
        'Owner' || 'Admin' || 'Sales' => r!,
        'Gudang' => 'Admin',
        _ => 'Sales',
      };

  Future<T> _jalankan<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on AuthGagal {
      rethrow;
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
        final r = await _auth.signInWithPassword(email: email.trim(), password: password);
        final u = r.user;
        if (u == null) return;
        final profil = await _muat(u);
        if (profil == null) throw AuthGagal(_alasanTolak ?? 'Akun tidak bisa dipakai.');
        _user = profil;
        notifyListeners();
      });

  @override
  Future<bool> daftar({required String nama, required String email, required String password}) =>
      _jalankan(() async {
        final r = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'nama': nama.trim()},
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
      final u = _auth.currentUser;
      try {
        _user = u == null ? null : await _muat(u);
      } catch (_) {
        _user = null;
      }
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
