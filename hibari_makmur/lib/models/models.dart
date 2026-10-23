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
    this.isiKotak = 0,
    this.isiDus = 0,
  });

  String kode;
  String nama;
  String kategori;
  String satuan;
  int stok;
  int minStok;

  /// Harga beli & jual per [satuan] (satuan dasar: Pcs, Lusin, Kotak, dst).
  double hargaBeli;
  double hargaJual;

  /// Isi satu Kotak / satu Dus dalam [satuan] dasar; 0 = tidak dijual per kotak/dus.
  /// Diisi dari Pack 1 / Pack 2 di price list (untuk barang per lusin sudah dibagi 12).
  int isiKotak;
  int isiDus;

  double get nilaiStok => stok * hargaBeli;

  /// Satuan yang bisa dipilih di transaksi beserta isinya dalam satuan dasar,
  /// mis. Pcs (1), Kotak (10), Dus (50).
  List<({String nama, int isi})> get satuanTersedia => [
        (nama: satuan, isi: 1),
        if (isiKotak > 1 && satuan != 'Kotak') (nama: 'Kotak', isi: isiKotak),
        if (isiDus > 1 && satuan != 'Dus') (nama: 'Dus', isi: isiDus),
      ];

  /// Isi [namaSatuan] dalam satuan dasar (1 kalau satuan dasar / tidak dikenal).
  int isiSatuan(String namaSatuan) =>
      satuanTersedia.where((s) => s.nama == namaSatuan).firstOrNull?.isi ?? 1;

  /// Mis. "1 Dus = 5 Lusin (60 Bh)" untuk barang per lusin, "1 Dus = 400 Bh" untuk lainnya.
  String keteranganIsi(String namaSatuan) {
    final isi = isiSatuan(namaSatuan);
    final bh = satuan == 'Lusin' ? ' (${isi * 12} Bh)' : '';
    return '1 $namaSatuan = $isi $satuan$bh';
  }

  /// Stok dalam bentuk dus + sisa, mis. "2 Dus + 20 Pcs"; null kalau tidak ada dus.
  String? stokDalamDus() {
    if (isiDus <= 1 || satuan == 'Dus' || stok < isiDus) return null;
    final sisa = stok % isiDus;
    return '${stok ~/ isiDus} Dus${sisa == 0 ? '' : ' + $sisa $satuan'}';
  }

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
        isiKotak: isiKotak,
        isiDus: isiDus,
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
    this.diskon = 0,
    this.hargaPokok = 0,
    this.isi = 1,
    String? satuanDasar,
  }) : satuanDasar = satuanDasar ?? satuan;

  final String kodeBarang;
  final String namaBarang;

  /// Satuan yang dipakai di transaksi (mis. Dus); [qty] dan [harga] dalam satuan ini.
  final String satuan;
  final int qty;
  final double harga;

  /// Isi satu [satuan] dalam [satuanDasar] barang, mis. 1 Dus = 50 Pcs.
  final int isi;
  final String satuanDasar;

  /// Jumlah dalam satuan dasar; inilah yang menambah / mengurangi stok.
  int get qtyDasar => qty * isi;

  /// Harga per satuan dasar (per buah / per lusin), mis. harga per Dus ÷ 36.
  double get hargaDasar => harga / isi;

  /// Diskon per barang dalam persen (0–100).
  final double diskon;

  /// Harga beli per [satuan] saat transaksi (untuk menghitung HPP / laba kotor).
  double hargaPokok;

  /// Qty × harga sebelum diskon.
  double get bruto => qty * harga;
  double get nilaiDiskon => bruto * diskon / 100;

  /// Harga satuan setelah diskon barang.
  double get hargaBersih => harga * (1 - diskon / 100);
  double get subtotal => bruto - nilaiDiskon;
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
    this.diskon = 0,
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

  /// Potongan untuk seluruh faktur dalam rupiah (di luar diskon per barang).
  final double diskon;

  bool get lunas => status == 'Lunas';

  /// Jumlah subtotal barang (sudah dikurangi diskon per barang).
  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  double get diskonBarang => items.fold(0, (s, i) => s + i.nilaiDiskon);
  double get totalDiskon => diskonBarang + diskon;
  bool get adaDiskon => totalDiskon > 0;
  double get total => subtotal - diskon < 0 ? 0 : subtotal - diskon;

  /// Bagian [total] milik satu barang: potongan faktur dibagi rata
  /// sebanding subtotal tiap barang (dipakai di laporan per barang/daerah).
  double porsiTotal(ItemTransaksi i) => subtotal == 0 ? 0 : i.subtotal / subtotal * total;
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
