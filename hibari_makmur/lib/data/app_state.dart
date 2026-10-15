import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// Penyimpanan data aplikasi (in-memory). Ganti isi method-method di sini
/// dengan pemanggilan API / database kalau backend sudah siap.
class AppState extends ChangeNotifier {
  AppState() {
    muatDataContoh();
  }

  static const kategoriList = [
    'Besi & Baja',
    'Cat',
    'Perlengkapan Bangunan',
    'Alat Pertukangan',
    'Kunci & Engsel',
    'Lainnya',
  ];
  static const satuanList = [
    'Pcs', 'Sak', 'Kaleng', 'Kg', 'Tube', 'Batang', //
    'Lembar', 'Galon', 'Set', 'Meter', 'Box',
  ];
  static const roleList = ['Admin', 'Kasir', 'Gudang'];

  final List<Barang> barang = [];
  final List<Kontak> supplier = [];
  final List<Kontak> pelanggan = [];
  final List<Transaksi> penjualan = [];
  final List<Transaksi> pembelian = [];
  final List<Pengguna> pengguna = [];
  final List<MutasiStok> mutasi = [];
  final List<Biaya> biaya = [];
  ProfilToko profil = ProfilToko(nama: '', alamat: '', telepon: '', email: '');
  PengaturanFaktur faktur = PengaturanFaktur();

  // ---------------------------------------------------------------- Barang
  Barang? cariBarang(String kode) {
    for (final b in barang) {
      if (b.kode == kode) return b;
    }
    return null;
  }

  List<Barang> get stokMenipis =>
      barang.where((b) => b.stok <= b.minStok).toList()
        ..sort((a, b) => (a.stok / max(a.minStok, 1)).compareTo(b.stok / max(b.minStok, 1)));

  double get nilaiStok => barang.fold(0, (s, b) => s + b.nilaiStok);

  void simpanBarang(Barang b, {String? kodeLama}) {
    final i = barang.indexWhere((e) => e.kode == (kodeLama ?? b.kode));
    if (i >= 0) {
      barang[i] = b;
    } else {
      barang.add(b);
    }
    notifyListeners();
  }

  void hapusBarang(String kode) {
    barang.removeWhere((b) => b.kode == kode);
    notifyListeners();
  }

  /// Penyesuaian stok manual (stock opname).
  void sesuaikanStok(String kode, int stokBaru, String keterangan) {
    final b = cariBarang(kode);
    if (b == null) return;
    _ubahStok(b, stokBaru - b.stok, keterangan, DateTime.now());
    notifyListeners();
  }

  void _ubahStok(Barang b, int delta, String keterangan, DateTime tanggal) {
    b.stok = max(0, b.stok + delta);
    mutasi.insert(
      0,
      MutasiStok(
        tanggal: tanggal,
        kodeBarang: b.kode,
        namaBarang: b.nama,
        perubahan: delta,
        stokAkhir: b.stok,
        keterangan: keterangan,
      ),
    );
  }

  // ------------------------------------------------------ Supplier/Pelanggan
  void simpanKontak(bool isSupplier, Kontak k, {String? kodeLama}) {
    final list = isSupplier ? supplier : pelanggan;
    final i = list.indexWhere((e) => e.kode == (kodeLama ?? k.kode));
    if (i >= 0) {
      list[i] = k;
    } else {
      list.add(k);
    }
    notifyListeners();
  }

  void hapusKontak(bool isSupplier, String kode) {
    (isSupplier ? supplier : pelanggan).removeWhere((e) => e.kode == kode);
    notifyListeners();
  }

  // -------------------------------------------------------------- Transaksi
  /// Mengembalikan pesan error, atau null kalau berhasil.
  String? tambahPenjualan(Transaksi t) {
    final butuh = <String, int>{};
    for (final i in t.items) {
      butuh[i.kodeBarang] = (butuh[i.kodeBarang] ?? 0) + i.qty;
    }
    for (final e in butuh.entries) {
      final b = cariBarang(e.key);
      if (b == null) return 'Barang ${e.key} tidak ditemukan';
      if (b.stok < e.value) {
        return 'Stok ${b.nama} tidak cukup (tersedia ${b.stok} ${b.satuan})';
      }
    }
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang)!;
      i.hargaPokok = b.hargaBeli;
      _ubahStok(b, -i.qty, 'Penjualan ${t.kode}', t.tanggal);
    }
    penjualan.add(t);
    notifyListeners();
    return null;
  }

  void tambahPembelian(Transaksi t) {
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang);
      if (b == null) continue;
      b.hargaBeli = i.harga; // harga beli terakhir
      _ubahStok(b, i.qty, 'Pembelian ${t.kode}', t.tanggal);
    }
    pembelian.add(t);
    notifyListeners();
  }

  /// Menghapus transaksi dan mengembalikan stok seperti semula.
  void hapusTransaksi(Transaksi t, {required bool isPenjualan}) {
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang);
      if (b == null) continue;
      _ubahStok(b, isPenjualan ? i.qty : -i.qty, 'Batal ${t.kode}', DateTime.now());
    }
    (isPenjualan ? penjualan : pembelian).remove(t);
    notifyListeners();
  }

  void ubahStatus(Transaksi t, String status) {
    t.status = status;
    notifyListeners();
  }

  Iterable<Transaksi> dalam(List<Transaksi> list, DateTimeRange r) =>
      list.where((t) => dalamRentang(t.tanggal, r));

  double totalDalam(List<Transaksi> list, DateTimeRange r) =>
      dalam(list, r).fold(0, (s, t) => s + t.total);

  double labaKotorDalam(DateTimeRange r) =>
      dalam(penjualan, r).fold(0, (s, t) => s + t.labaKotor);

  double biayaDalam(DateTimeRange r) =>
      biaya.where((b) => dalamRentang(b.tanggal, r)).fold(0, (s, b) => s + b.jumlah);

  List<int> get tahunTersedia {
    final set = <int>{DateTime.now().year};
    for (final t in [...penjualan, ...pembelian]) {
      set.add(t.tanggal.year);
    }
    return set.toList()..sort();
  }

  // -------------------------------------------------------------- Kode baru
  String _kodeBerikut(String prefix, Iterable<String> kode, int digit) {
    var maks = 0;
    for (final k in kode) {
      if (!k.startsWith(prefix)) continue;
      final n = int.tryParse(k.substring(prefix.length));
      if (n != null && n > maks) maks = n;
    }
    return '$prefix${(maks + 1).toString().padLeft(digit, '0')}';
  }

  String get kodeBarangBaru => _kodeBerikut('BRG', barang.map((e) => e.kode), 4);
  String get kodePenjualanBaru => _kodeBerikut('PJ', penjualan.map((e) => e.kode), 5);
  String get kodePembelianBaru => _kodeBerikut('PB', pembelian.map((e) => e.kode), 5);
  String kodeKontakBaru(bool isSupplier) => isSupplier
      ? _kodeBerikut('SUP', supplier.map((e) => e.kode), 3)
      : _kodeBerikut('PLG', pelanggan.map((e) => e.kode), 3);

  // ---------------------------------------------------- Pengguna & lainnya
  void simpanPengguna(Pengguna p, {String? usernameLama}) {
    final i = pengguna.indexWhere((e) => e.username == (usernameLama ?? p.username));
    if (i >= 0) {
      pengguna[i] = p;
    } else {
      pengguna.add(p);
    }
    notifyListeners();
  }

  Pengguna? penggunaDenganEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final p in pengguna) {
      if (p.email.toLowerCase() == e) return p;
    }
    return null;
  }

  void hapusPengguna(String username) {
    pengguna.removeWhere((e) => e.username == username);
    notifyListeners();
  }

  void tambahBiaya(Biaya b) {
    biaya.add(b);
    notifyListeners();
  }

  void hapusBiaya(Biaya b) {
    biaya.remove(b);
    notifyListeners();
  }

  void simpanFaktur(PengaturanFaktur f) {
    faktur = f;
    notifyListeners();
  }

  Kontak? cariKontak(bool isSupplier, String nama) {
    for (final k in isSupplier ? supplier : pelanggan) {
      if (k.nama == nama) return k;
    }
    return null;
  }

  void simpanProfil(ProfilToko p) {
    profil = p;
    notifyListeners();
  }

  // ------------------------------------------------------------ Data contoh
  void muatDataContoh() {
    barang
      ..clear()
      ..addAll([
        _b('BRG0003', 'Besi Beton 10mm', 'Besi & Baja', 'Batang', 120, 30, 65000, 75000),
        _b('BRG0005', 'Plat Besi 2mm', 'Besi & Baja', 'Lembar', 40, 10, 180000, 210000),
        _b('BRG0012', 'Semen Tiga Roda', 'Perlengkapan Bangunan', 'Sak', 5, 20, 45000, 50000),
        _b('BRG0021', 'Besi Hollow 4x4', 'Besi & Baja', 'Pcs', 80, 20, 16000, 20000),
        _b('BRG0031', 'Cat Nippon 1kg', 'Cat', 'Kaleng', 3, 15, 21000, 25000),
        _b('BRG0034', 'Cat Avian 5kg', 'Cat', 'Galon', 25, 10, 95000, 115000),
        _b('BRG0045', 'Paku 5 cm', 'Perlengkapan Bangunan', 'Kg', 2, 10, 8000, 10000),
        _b('BRG0050', 'Palu Kambing', 'Alat Pertukangan', 'Pcs', 30, 10, 35000, 45000),
        _b('BRG0052', 'Gergaji Kayu', 'Alat Pertukangan', 'Pcs', 18, 5, 55000, 70000),
        _b('BRG0067', 'Lem Kaca', 'Lainnya', 'Tube', 6, 20, 10000, 13000),
        _b('BRG0071', 'Kunci Pintu Solid', 'Kunci & Engsel', 'Set', 22, 8, 85000, 110000),
        _b('BRG0089', 'Engsel Pintu', 'Kunci & Engsel', 'Pcs', 3, 15, 11000, 15000),
        _b('BRG0090', 'Pipa PVC 3/4"', 'Perlengkapan Bangunan', 'Batang', 60, 20, 22000, 28000),
        _b('BRG0095', 'Meteran 5m', 'Alat Pertukangan', 'Pcs', 15, 5, 25000, 35000),
        _b('BRG0098', 'Amplas Kayu', 'Lainnya', 'Lembar', 90, 30, 2500, 4000),
      ]);

    supplier
      ..clear()
      ..addAll([
        Kontak(kode: 'SUP001', nama: 'PT BESI UTAMA', telepon: '021-5550123', alamat: 'Jl. Industri No. 12, Jakarta'),
        Kontak(kode: 'SUP002', nama: 'CV CAT MAKMUR', telepon: '0812-3456-7890', alamat: 'Jl. Merdeka No. 45, Bandung'),
        Kontak(kode: 'SUP003', nama: 'TOKO TEKNIK JAYA', telepon: '0813-2222-1111', alamat: 'Jl. Pahlawan No. 8, Bekasi'),
        Kontak(kode: 'SUP004', nama: 'SINAR LOGAM', telepon: '021-7778899', alamat: 'Jl. Raya Bogor Km 20, Jakarta'),
        Kontak(kode: 'SUP005', nama: 'MITRA BANGUNAN', telepon: '0815-9090-1212', alamat: 'Jl. Sudirman No. 101, Tangerang'),
      ]);

    pelanggan
      ..clear()
      ..addAll([
        Kontak(kode: 'PLG001', nama: 'TOKO MAJU', telepon: '0812-1111-2222', alamat: 'Jl. Melati No. 3'),
        Kontak(kode: 'PLG002', nama: 'BANGUN JAYA', telepon: '0813-3333-4444', alamat: 'Jl. Kenanga No. 17'),
        Kontak(kode: 'PLG003', nama: 'PERINTIS MAKMUR', telepon: '0821-5555-6666', alamat: 'Jl. Anggrek No. 9'),
        Kontak(kode: 'PLG004', nama: 'KITA BAKARAN BATU', telepon: '0857-7777-8888', alamat: 'Jl. Mawar No. 21'),
        Kontak(kode: 'PLG005', nama: 'KO FENDY', telepon: '0819-9999-0000', alamat: 'Jl. Dahlia No. 5'),
        Kontak(kode: 'PLG006', nama: 'UMUM', alamat: '-'),
      ]);

    pengguna
      ..clear()
      ..addAll([
        Pengguna(username: 'admin', nama: 'Administrator', role: 'Admin', email: 'admin@sinarsehati.id'),
        Pengguna(username: 'kasir1', nama: 'Rina Lestari', role: 'Kasir', email: 'kasir@sinarsehati.id'),
        Pengguna(username: 'gudang1', nama: 'Budi Santoso', role: 'Gudang', email: 'gudang@sinarsehati.id'),
        Pengguna(
            username: 'kasir2', nama: 'Dewi Anggraini', role: 'Kasir', email: 'dewi@sinarsehati.id', aktif: false),
      ]);

    profil = ProfilToko(
      nama: 'Sinar Sehati',
      alamat: 'Toko Perkakas & Kunci Pintu',
      telepon: '0812-0000-1234',
      email: 'admin@sinarsehati.id',
    );

    _buatTransaksiContoh();
    mutasi.clear();
    notifyListeners();
  }

  Barang _b(String kode, String nama, String kat, String sat, int stok, int min,
          double beli, double jual) =>
      Barang(
        kode: kode,
        nama: nama,
        kategori: kat,
        satuan: sat,
        stok: stok,
        minStok: min,
        hargaBeli: beli,
        hargaJual: jual,
      );

  void _buatTransaksiContoh() {
    final rnd = Random(7);
    final now = DateTime.now();
    final pj = <Transaksi>[];
    final pb = <Transaksi>[];
    biaya.clear();

    List<ItemTransaksi> acakItem({required bool jual}) {
      final pilih = [...barang]..shuffle(rnd);
      return pilih.take(1 + rnd.nextInt(3)).map((b) {
        final mahal = b.hargaBeli >= 60000;
        var qty = mahal ? 1 + rnd.nextInt(5) : 5 + rnd.nextInt(30);
        if (!jual) qty *= 2;
        return ItemTransaksi(
          kodeBarang: b.kode,
          namaBarang: b.nama,
          satuan: b.satuan,
          qty: qty,
          harga: jual ? b.hargaJual : b.hargaBeli,
          hargaPokok: b.hargaBeli,
        );
      }).toList();
    }

    for (var y = now.year - 1; y <= now.year; y++) {
      for (var m = 1; m <= 12; m++) {
        if (DateTime(y, m, 1).isAfter(now)) break;
        final bulanIni = y == now.year && m == now.month;
        final hariMaks = bulanIni ? now.day : DateUtils.getDaysInMonth(y, m);
        final musim = 1 + (m >= 6 && m <= 9 ? 0.3 : 0.0);
        final nPj = ((6 + rnd.nextInt(5)) * musim).round();
        for (var i = 0; i < nPj; i++) {
          pj.add(Transaksi(
            kode: '',
            tanggal: DateTime(y, m, 1 + rnd.nextInt(hariMaks)),
            pihak: pelanggan[rnd.nextInt(pelanggan.length)].nama,
            items: acakItem(jual: true),
            status: rnd.nextDouble() < (bulanIni ? 0.3 : 0.08) ? 'Piutang' : 'Lunas',
          ));
        }
        final nPb = 2 + rnd.nextInt(2);
        for (var i = 0; i < nPb; i++) {
          pb.add(Transaksi(
            kode: '',
            tanggal: DateTime(y, m, 1 + rnd.nextInt(hariMaks)),
            pihak: supplier[rnd.nextInt(supplier.length)].nama,
            items: acakItem(jual: false),
            status: rnd.nextDouble() < (bulanIni ? 0.3 : 0.05) ? 'Hutang' : 'Lunas',
          ));
        }
        biaya
          ..add(Biaya(tanggal: DateTime(y, m, 1), keterangan: 'Listrik & Air', jumlah: 350000))
          ..add(Biaya(tanggal: DateTime(y, m, 1), keterangan: 'Transportasi / Ongkir', jumlah: 250000));
      }
    }

    pj.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    pb.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    for (var i = 0; i < pj.length; i++) {
      pj[i].kode = 'PJ${(i + 1).toString().padLeft(5, '0')}';
    }
    for (var i = 0; i < pb.length; i++) {
      pb[i].kode = 'PB${(i + 1).toString().padLeft(5, '0')}';
    }
    penjualan
      ..clear()
      ..addAll(pj);
    pembelian
      ..clear()
      ..addAll(pb);
  }
}

/// Menyediakan [AppState] ke seluruh widget. Ambil dengan `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Ambil state tanpa ikut rebuild (untuk dipakai di callback).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
