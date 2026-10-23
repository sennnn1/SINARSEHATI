import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Akses tabel kontak di Supabase, mis. `pelanggan` (lihat supabase/pelanggan.sql).
class KontakRepo {
  KontakRepo(this._db, this.tabel);

  final SupabaseClient _db;
  final String tabel;

  SupabaseQueryBuilder get _tabel => _db.from(tabel);

  Future<List<Kontak>> semua() async {
    final rows = await _tabel.select().order('kode');
    return rows.map(_dariMap).toList();
  }

  Future<void> simpan(Kontak k, {String? kodeLama}) async {
    if (kodeLama != null && kodeLama != k.kode) {
      await _tabel.update(_keMap(k)).eq('kode', kodeLama);
    } else {
      await _tabel.upsert(_keMap(k));
    }
  }

  Future<void> hapus(String kode) => _tabel.delete().eq('kode', kode);

  static Kontak _dariMap(Map<String, dynamic> m) => Kontak(
        kode: m['kode'] as String,
        nama: m['nama'] as String,
        telepon: (m['telepon'] as String?) ?? '',
        alamat: (m['alamat'] as String?) ?? '',
        daerah: (m['daerah'] as String?) ?? '',
      );

  static Map<String, dynamic> _keMap(Kontak k) => {
        'kode': k.kode,
        'nama': k.nama,
        'telepon': k.telepon,
        'alamat': k.alamat,
        'daerah': k.daerah,
      };
}
