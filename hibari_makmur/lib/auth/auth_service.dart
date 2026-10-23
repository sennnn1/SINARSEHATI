import 'package:flutter/material.dart';

/// Data pengguna yang sedang login.
class AuthUser {
  const AuthUser({required this.email, required this.nama, required this.role});

  final String email;
  final String nama;

  /// Owner, Admin, atau Sales.
  final String role;
}

/// Error yang pesannya aman ditampilkan ke pengguna.
class AuthGagal implements Exception {
  const AuthGagal(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Kontrak layanan login. Ada dua implementasi:
/// - [DemoAuthService]   : tanpa internet, akun disimpan di memori (untuk demo/tes)
/// - [SupabaseAuthService]: akun asli di Supabase, email reset dikirim sungguhan
abstract class AuthService extends ChangeNotifier {
  AuthUser? get user;

  /// true selama profil (role & status) sedang diambil dari server.
  bool get menyiapkan => false;

  /// true kalau berjalan tanpa backend (mode demo).
  bool get isDemo;

  Future<void> login(String email, String password);

  /// Mengembalikan true kalau akun perlu verifikasi email dulu sebelum bisa login.
  Future<bool> daftar({required String nama, required String email, required String password});

  /// Langkah 1 lupa password: kirim kode OTP 6 digit ke email.
  Future<void> kirimKodeReset(String email);

  /// Langkah 2 lupa password: cocokkan kode lalu simpan password baru.
  Future<void> resetPassword({
    required String email,
    required String kode,
    required String passwordBaru,
  });

  Future<void> logout();
}

/// Menyediakan [AuthService] ke seluruh widget.
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({super.key, required AuthService auth, required super.child})
      : super(notifier: auth);

  static AuthService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;

  static AuthService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}

final _polaEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

String? validasiEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Email wajib diisi';
  if (!_polaEmail.hasMatch(s)) return 'Format email tidak valid';
  return null;
}

String? validasiPassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Password wajib diisi';
  if (s.length < 6) return 'Password minimal 6 karakter';
  return null;
}
