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
  });

  String kode;
  String nama;
  String telepon;
  String alamat;
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
  });

  String kode;
  final DateTime tanggal;

  /// Nama pelanggan (penjualan) atau supplier (pembelian).
  final String pihak;
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
  });

  String username;
  String nama;
  String email;
  String role;
  bool aktif;
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
  });

  static const ukuranList = ['A4', 'A5', 'Continuous Form', 'Struk 80 mm', 'Struk 58 mm'];

  String ukuran;
  String judulPenjualan;
  String judulPembelian;
  String catatanKaki;
  bool tampilkanLogo;
  bool tampilkanTandaTangan;
  bool tampilkanTerbilang;

  bool get struk => ukuran.startsWith('Struk');
}
