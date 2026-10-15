import 'dart:math';

import '../data/app_state.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// Login tanpa backend. Profil (nama, role, aktif) diambil dari menu Pengguna
/// di [AppState]; password disimpan di memori dan hilang saat aplikasi ditutup.
///
/// Akun demo — semua memakai password `admin123`:
///   admin@sinarsehati.id  (Admin)
///   kasir@sinarsehati.id  (Kasir)
///   gudang@sinarsehati.id (Gudang)
class DemoAuthService extends AuthService {
  DemoAuthService(this.data, {this.jeda = const Duration(milliseconds: 400)}) {
    for (final p in data.pengguna) {
      if (p.email.isNotEmpty) _password[p.email.toLowerCase()] = passwordDemo;
    }
  }

  static const emailDemo = 'admin@sinarsehati.id';
  static const passwordDemo = 'admin123';

  final AppState data;

  /// Jeda buatan agar indikator loading terlihat seperti memanggil server.
  final Duration jeda;
  final _password = <String, String>{};
  final _kodeReset = <String, ({String kode, DateTime kedaluwarsa})>{};
  final _rnd = Random.secure();
  AuthUser? _user;

  /// Di mode demo email tidak benar-benar dikirim, jadi kode terakhir
  /// ditampilkan di layar agar alur lupa password tetap bisa dicoba.
  String? kodeTerakhir;

  @override
  AuthUser? get user => _user;

  @override
  bool get isDemo => true;

  Future<void> _jeda() async {
    if (jeda > Duration.zero) await Future.delayed(jeda);
  }

  @override
  Future<void> login(String email, String password) async {
    await _jeda();
    final e = email.trim().toLowerCase();
    final p = data.penggunaDenganEmail(e);
    if (p == null || _password[e] != password) {
      throw const AuthGagal('Email atau password salah.');
    }
    if (!p.aktif) throw const AuthGagal('Akun ini dinonaktifkan. Hubungi admin.');
    _user = AuthUser(email: e, nama: p.nama, role: p.role);
    notifyListeners();
  }

  @override
  Future<bool> daftar({required String nama, required String email, required String password}) async {
    await _jeda();
    final e = email.trim().toLowerCase();
    if (data.penggunaDenganEmail(e) != null) throw const AuthGagal('Email sudah terdaftar.');
    var username = e.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (username.isEmpty) username = 'user';
    final dasar = username;
    for (var i = 2; data.pengguna.any((x) => x.username == username); i++) {
      username = '$dasar$i';
    }
    data.simpanPengguna(Pengguna(username: username, nama: nama.trim(), role: 'Kasir', email: e));
    _password[e] = password;
    return false;
  }

  @override
  Future<void> kirimKodeReset(String email) async {
    await _jeda();
    final e = email.trim().toLowerCase();
    // Pesan sengaja tidak membedakan email terdaftar atau tidak (keamanan),
    // tapi kode hanya dibuat untuk akun yang ada.
    if (data.penggunaDenganEmail(e) == null) {
      kodeTerakhir = null;
      return;
    }
    final kode = (_rnd.nextInt(900000) + 100000).toString();
    _kodeReset[e] = (kode: kode, kedaluwarsa: DateTime.now().add(const Duration(minutes: 10)));
    kodeTerakhir = kode;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String kode,
    required String passwordBaru,
  }) async {
    await _jeda();
    final e = email.trim().toLowerCase();
    final r = _kodeReset[e];
    if (r == null || r.kode != kode.trim()) throw const AuthGagal('Kode salah.');
    if (DateTime.now().isAfter(r.kedaluwarsa)) {
      throw const AuthGagal('Kode sudah kedaluwarsa. Kirim ulang kode.');
    }
    _password[e] = passwordBaru;
    _kodeReset.remove(e);
    kodeTerakhir = null;
  }

  @override
  Future<void> logout() async {
    _user = null;
    notifyListeners();
  }
}
