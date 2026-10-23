import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Akses tabel `barang` di Supabase (lihat supabase/schema.sql).
class BarangRepo {
  BarangRepo(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _tabel => _db.from('barang');

  /// Supabase membatasi 1000 baris per request, jadi diambil per halaman.
  Future<List<Barang>> semua() async {
    const perHalaman = 1000;
    final hasil = <Barang>[];
    for (var dari = 0;; dari += perHalaman) {
      final rows = await _tabel.select().order('kode').range(dari, dari + perHalaman - 1);
      hasil.addAll(rows.map(_dariMap));
      if (rows.length < perHalaman) break;
    }
    return hasil;
  }

  /// Hanya kolom yang dikelola aplikasi; kolom asal Excel (grup, isi_pack, dll.)
  /// tidak ikut tertimpa.
  Future<void> simpan(Barang b, {String? kodeLama}) async {
    if (kodeLama != null && kodeLama != b.kode) {
      await _tabel.update(_keMap(b)).eq('kode', kodeLama);
    } else {
      await _tabel.upsert(_keMap(b));
    }
  }

  Future<void> hapus(String kode) => _tabel.delete().eq('kode', kode);

  Future<void> ubahStok(String kode, int stok) => _tabel.update({'stok': stok}).eq('kode', kode);

  static Barang _dariMap(Map<String, dynamic> m) => Barang(
        kode: m['kode'] as String,
        nama: m['nama'] as String,
        kategori: m['kategori'] as String,
        satuan: m['satuan'] as String,
        stok: m['stok'] as int,
        minStok: m['min_stok'] as int,
        hargaBeli: (m['harga_beli'] as num).toDouble(),
        hargaJual: (m['harga_jual'] as num).toDouble(),
      );

  static Map<String, dynamic> _keMap(Barang b) => {
        'kode': b.kode,
        'nama': b.nama,
        'kategori': b.kategori,
        'satuan': b.satuan,
        'stok': b.stok,
        'min_stok': b.minStok,
        'harga_beli': b.hargaBeli,
        'harga_jual': b.hargaJual,
      };
}
