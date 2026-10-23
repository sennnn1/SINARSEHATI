import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Akses tabel transaksi, transaksi_item, dan mutasi_stok di Supabase
/// (lihat supabase/transaksi.sql). Simpan/hapus lewat fungsi database supaya
/// nomor faktur, stok, dan kartu stok berubah bersamaan.
class TransaksiRepo {
  TransaksiRepo(this._db);

  final SupabaseClient _db;

  /// Semua transaksi beserta itemnya, dipisah penjualan & pembelian.
  Future<({List<Transaksi> penjualan, List<Transaksi> pembelian})> semua() async {
    const perHalaman = 1000;
    final pj = <Transaksi>[];
    final pb = <Transaksi>[];
    for (var dari = 0;; dari += perHalaman) {
      final rows = await _db
          .from('transaksi')
          .select('*, transaksi_item(*)')
          .order('kode')
          .range(dari, dari + perHalaman - 1);
      for (final m in rows) {
        (m['jenis'] == 'penjualan' ? pj : pb).add(_dariMap(m));
      }
      if (rows.length < perHalaman) break;
    }
    return (penjualan: pj, pembelian: pb);
  }

  /// Menyimpan transaksi baru; mengembalikan nomor faktur dari database.
  Future<String> simpan(Transaksi t, {required bool penjualan}) async {
    final kode = await _db.rpc('simpan_transaksi', params: {
      'p_jenis': penjualan ? 'penjualan' : 'pembelian',
      'p_tanggal': _tgl(t.tanggal),
      'p_pihak': t.pihak,
      'p_status': t.status,
      'p_catatan': t.catatan,
      'p_daerah': t.daerah,
      'p_items': [
        for (final i in t.items)
          {
            'kode_barang': i.kodeBarang,
            'nama_barang': i.namaBarang,
            'satuan': i.satuan,
            'qty': i.qty,
            'harga': i.harga,
          },
      ],
    });
    return kode as String;
  }

  Future<void> hapus(String kode) => _db.rpc('hapus_transaksi', params: {'p_kode': kode});

  Future<void> ubahStatus(String kode, String status) =>
      _db.from('transaksi').update({'status': status}).eq('kode', kode);

  /// Kartu stok terbaru.
  Future<List<MutasiStok>> mutasi({int batas = 1000}) async {
    final rows = await _db.from('mutasi_stok').select().order('id', ascending: false).limit(batas);
    return [
      for (final m in rows)
        MutasiStok(
          tanggal: DateTime.parse(m['tanggal'] as String).toLocal(),
          kodeBarang: m['kode_barang'] as String,
          namaBarang: m['nama_barang'] as String,
          perubahan: m['perubahan'] as int,
          stokAkhir: m['stok_akhir'] as int,
          keterangan: m['keterangan'] as String,
        ),
    ];
  }

  Future<void> sesuaikanStok(String kode, int stok, String keterangan) => _db.rpc('sesuaikan_stok',
      params: {'p_kode': kode, 'p_stok': stok, 'p_keterangan': keterangan});

  static String _tgl(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Transaksi _dariMap(Map<String, dynamic> m) {
    final items = [...(m['transaksi_item'] as List).cast<Map<String, dynamic>>()]
      ..sort((a, b) => (a['urutan'] as int).compareTo(b['urutan'] as int));
    return Transaksi(
      kode: m['kode'] as String,
      tanggal: DateTime.parse(m['tanggal'] as String),
      pihak: m['pihak'] as String,
      status: m['status'] as String,
      catatan: (m['catatan'] as String?) ?? '',
      daerah: (m['daerah'] as String?) ?? '',
      items: [
        for (final i in items)
          ItemTransaksi(
            kodeBarang: i['kode_barang'] as String,
            namaBarang: i['nama_barang'] as String,
            satuan: i['satuan'] as String,
            qty: i['qty'] as int,
            harga: (i['harga'] as num).toDouble(),
            hargaPokok: (i['harga_pokok'] as num).toDouble(),
          ),
      ],
    );
  }
}

/// Pesan error Supabase yang ramah untuk ditampilkan ke pengguna.
String pesanErrorDb(Object e) {
  if (e is PostgrestException) {
    // Fungsi atau tabel belum dibuat di Supabase.
    if (e.code == 'PGRST202' || e.code == '42P01' || e.code == 'PGRST205') {
      return 'Database belum diperbarui. Jalankan (ulang) supabase/transaksi.sql di SQL Editor Supabase.';
    }
    return e.message;
  }
  return 'Tidak bisa terhubung ke database. Periksa koneksi internet. ($e)';
}
