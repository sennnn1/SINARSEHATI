import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Daftar pengguna (role & status akun). Dibuat abstrak supaya bisa diganti
/// tiruan saat pengujian.
abstract class PenggunaRepo {
  Future<List<Pengguna>> semua();

  /// Mengubah nama, role, dan status. Melempar error kalau tidak diizinkan
  /// (hanya Owner yang boleh).
  Future<void> ubah(String id, {required String nama, required String role, required bool aktif});
}

/// Tabel `pengguna` di Supabase (lihat supabase/pengguna.sql). Hak ubah dijaga
/// oleh RLS di database, bukan hanya oleh tampilan aplikasi.
class SupabasePenggunaRepo implements PenggunaRepo {
  SupabasePenggunaRepo(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Pengguna>> semua() async {
    final rows = await _db.from('pengguna').select().order('dibuat_pada', ascending: false);
    return [
      for (final m in rows)
        Pengguna(
          id: m['id'] as String,
          username: (m['email'] as String).split('@').first,
          email: m['email'] as String,
          nama: m['nama'] as String,
          role: m['role'] as String,
          aktif: m['aktif'] as bool,
          dibuatPada: DateTime.tryParse(m['dibuat_pada'] as String? ?? '')?.toLocal(),
        ),
    ];
  }

  @override
  Future<void> ubah(String id, {required String nama, required String role, required bool aktif}) async {
    final hasil = await _db.from('pengguna').update({'nama': nama, 'role': role, 'aktif': aktif}).eq('id', id).select();
    // RLS menolak diam-diam (0 baris) kalau yang mengubah bukan Owner.
    if (hasil.isEmpty) throw const PostgrestException(message: 'Hanya Owner yang boleh mengubah pengguna.');
  }
}

/// Pesan error yang ramah untuk ditampilkan ke pengguna.
String pesanErrorPengguna(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42P01' || e.code == 'PGRST205') {
      return 'Tabel pengguna belum ada di Supabase. Jalankan supabase/pengguna.sql di SQL Editor.';
    }
    return e.message;
  }
  return 'Tidak bisa terhubung ke database. Periksa koneksi internet.';
}
