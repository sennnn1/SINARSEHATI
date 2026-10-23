class Barang {
  Barang({
    required this.kode,
    required this.nama,
    required this.kategori,
    required this.satuan,
    required this.stok,
    required this.minStok,
    required this.hargaBeli,
    required this.hargaJual,
  });

  String kode;
  String nama;
  String kategori;
  String satuan;
  int stok;
  int minStok;
  double hargaBeli;
  double hargaJual;

  double get nilaiStok => stok * hargaBeli;

  String get statusStok => stok <= 0
      ? 'Habis'
      : stok <= minStok
          ? 'Menipis'
          : 'Aman';

  Barang copy() => Barang(
        kode: kode,
        nama: nama,
        kategori: kategori,
        satuan: satuan,
        stok: stok,
        minStok: minStok,
        hargaBeli: hargaBeli,
        hargaJual: hargaJual,
      );
}

/// Dipakai untuk Supplier maupun Pelanggan.
class Kontak {
  Kontak({
    required this.kode,
    required this.nama,
    this.telepon = '',
    this.alamat = '',
    this.daerah = '',
  });

  String kode;
  String nama;
  String telepon;
  String alamat;

  /// Kota / kabupaten, mis. Banda Aceh, Medan. Dipakai untuk laporan per daerah.
  String daerah;
}

class ItemTransaksi {
  ItemTransaksi({
    required this.kodeBarang,
    required this.namaBarang,
    required this.satuan,
    required this.qty,
    required this.harga,
    this.hargaPokok = 0,
  });

  final String kodeBarang;
  final String namaBarang;
  final String satuan;
  final int qty;
  final double harga;

  /// Harga beli barang saat dijual (untuk menghitung HPP / laba kotor).
  double hargaPokok;

  double get subtotal => qty * harga;
}

class Transaksi {
  Transaksi({
    required this.kode,
    required this.tanggal,
    required this.pihak,
    required this.items,
    required this.status,
    this.catatan = '',
    this.daerah = '',
  });

  String kode;
  final DateTime tanggal;

  /// Nama pelanggan (penjualan) atau supplier (pembelian).
  final String pihak;

  /// Daerah tujuan/asal transaksi; awalnya diambil dari daerah pelanggan,
  /// bisa diubah (mis. pelanggan UMUM dari Medan).
  final String daerah;
  final List<ItemTransaksi> items;
  String status;
  final String catatan;

  bool get lunas => status == 'Lunas';
  double get total => items.fold(0, (s, i) => s + i.subtotal);
  double get hpp => items.fold(0, (s, i) => s + i.qty * i.hargaPokok);
  double get labaKotor => total - hpp;
  int get jumlahQty => items.fold(0, (s, i) => s + i.qty);
}

class Pengguna {
  Pengguna({
    required this.username,
    required this.nama,
    required this.role,
    this.email = '',
    this.aktif = true,
    this.id,
    this.dibuatPada,
  });

  String username;
  String nama;
  String email;
  String role;
  bool aktif;

  /// Id akun di Supabase (kosong di mode demo).
  String? id;
  DateTime? dibuatPada;
}

class MutasiStok {
  MutasiStok({
    required this.tanggal,
    required this.kodeBarang,
    required this.namaBarang,
    required this.perubahan,
    required this.stokAkhir,
    required this.keterangan,
  });

  final DateTime tanggal;
  final String kodeBarang;
  final String namaBarang;
  final int perubahan;
  final int stokAkhir;
  final String keterangan;
}

class Biaya {
  Biaya({required this.tanggal, required this.keterangan, required this.jumlah});

  final DateTime tanggal;
  final String keterangan;
  final double jumlah;
}

class ProfilToko {
  ProfilToko({
    required this.nama,
    required this.alamat,
    required this.telepon,
    required this.email,
  });

  String nama;
  String alamat;
  String telepon;
  String email;
}

/// Pengaturan tampilan faktur (diatur di menu Pengaturan).
class PengaturanFaktur {
  PengaturanFaktur({
    this.ukuran = 'A5',
    this.judulPenjualan = 'FAKTUR PENJUALAN',
    this.judulPembelian = 'BUKTI PEMBELIAN',
    this.catatanKaki =
        'Terima kasih atas kepercayaan Anda.\nBarang yang sudah dibeli tidak dapat dikembalikan.',
    this.tampilkanLogo = true,
    this.tampilkanTandaTangan = true,
    this.tampilkanTerbilang = true,
    this.hitamPutih = false,
    this.rangkap = 'Tidak',
    List<String>? labelLembar,
  }) : labelLembar = labelLembar ?? ['Pelanggan', 'Arsip Toko', 'Gudang'];

  static const ukuranList = [
    'A4', 'A5', 'Continuous Form', 'Continuous 1/2', 'Struk 80 mm', 'Struk 58 mm', //
  ];

  /// - Tidak       : satu lembar biasa.
  /// - NCR 3 ply   : kertas rangkap 3 (putih/merah/kuning) untuk printer dot matrix;
  ///                 sekali cetak jadi 3, jadi PDF tetap 1 halaman + keterangan warna lembar.
  /// - 3 lembar    : kertas biasa; PDF berisi 3 salinan dengan label lembar masing-masing.
  static const rangkapList = ['Tidak', 'NCR 3 ply', '3 lembar'];
  static const warnaNcr = ['Putih', 'Merah', 'Kuning'];

  String ukuran;
  String judulPenjualan;
  String judulPembelian;
  String catatanKaki;
  bool tampilkanLogo;
  bool tampilkanTandaTangan;
  bool tampilkanTerbilang;

  /// Tanpa warna/arsiran & tanpa logo — paling jelas untuk printer dot matrix
  /// dan tembusan kertas rangkap.
  bool hitamPutih;
  String rangkap;

  /// Peruntukan lembar 1, 2, 3 (mis. Pelanggan, Arsip Toko, Gudang).
  List<String> labelLembar;

  bool get struk => ukuran.startsWith('Struk');
}
