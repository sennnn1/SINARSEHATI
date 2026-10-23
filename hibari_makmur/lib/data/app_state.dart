import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'barang_repo.dart';
import 'kontak_repo.dart';
import 'pengguna_repo.dart';
import 'transaksi_repo.dart';
import '../utils/format.dart';

/// Penyimpanan data aplikasi. Data barang, pelanggan, transaksi, dan kartu
/// stok disinkronkan ke Supabase kalau repo-nya diisi; data lain masih in-memory.
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
    'Bh', 'Pcs', 'Lusin', 'Pasang', 'Sak', 'Kaleng', 'Kg', 'Tube', 'Batang', //
    'Lembar', 'Galon', 'Set', 'Meter', 'Box', 'Kotak', 'Dus', 'Roll', //
  ];
  static const roleList = ['Owner', 'Admin', 'Sales'];

  /// Saran daerah di form pelanggan/supplier; daerah lain tetap bisa diketik.
  static const daerahSaran = [
    'Banda Aceh', 'Aceh Besar', 'Sabang', 'Lhokseumawe', 'Langsa', 'Meulaboh', //
    'Sigli', 'Bireuen', 'Takengon', 'Lhoksukon', 'Kuala Simpang', //
    'Medan', 'Binjai', 'Deli Serdang', 'Pematangsiantar', 'Tebing Tinggi', //
    'Kisaran', 'Tanjung Balai', 'Rantau Prapat', 'Kabanjahe', 'Sibolga', 'Padang Sidempuan',
  ];

  /// Label untuk pelanggan/supplier yang daerahnya belum diisi.
  static const tanpaDaerah = 'Belum diisi';

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

  /// Diisi di main.dart saat aplikasi memakai Supabase.
  BarangRepo? repo;
  KontakRepo? pelangganRepo;
  TransaksiRepo? transaksiRepo;
  PenggunaRepo? penggunaRepo;

  /// Pesan error saat memuat daftar pengguna (mis. pengguna.sql belum dijalankan).
  String? errorPengguna;

  /// Pesan error saat memuat transaksi (mis. transaksi.sql belum dijalankan).
  String? errorTransaksi;

  /// Pesan error saat memuat pelanggan (mis. tabel belum dibuat di Supabase).
  String? errorPelanggan;

  /// True selama daftar barang sedang diambil dari Supabase.
  bool memuatBarang = false;

  /// Pesan error terakhir saat sinkron ke Supabase (null kalau tidak ada).
  String? errorSinkron;

  /// Mengambil semua data yang disimpan di Supabase sekaligus (paralel).
  Future<void> muatDariSupabase() => Future.wait([
        muatBarangDariSupabase(),
        muatPelangganDariSupabase(),
        muatTransaksiDariSupabase(),
        muatPenggunaDariSupabase(),
      ]);

  /// Mengganti daftar pengguna dengan isi tabel `pengguna` di Supabase.
  /// Owner mendapat semua akun; role lain hanya melihat akunnya sendiri.
  Future<void> muatPenggunaDariSupabase() async {
    final r = penggunaRepo;
    if (r == null) return;
    try {
      final data = await r.semua();
      pengguna
        ..clear()
        ..addAll(data);
      errorPengguna = null;
    } catch (e) {
      errorPengguna = 'Daftar pengguna belum bisa dimuat. ${pesanErrorPengguna(e)}';
      debugPrint(errorPengguna);
    }
    notifyListeners();
  }

  /// Menyimpan perubahan nama / role / status ke database.
  /// Mengembalikan pesan error, atau null kalau berhasil.
  Future<String?> ubahPenggunaDb(Pengguna p) async {
    final r = penggunaRepo;
    if (r == null || p.id == null) return 'Pengguna tidak ditemukan.';
    try {
      await r.ubah(p.id!, nama: p.nama, role: p.role, aktif: p.aktif);
    } catch (e) {
      return pesanErrorPengguna(e);
    }
    final i = pengguna.indexWhere((e) => e.id == p.id);
    if (i >= 0) pengguna[i] = p;
    notifyListeners();
    return null;
  }

  /// Mengganti penjualan, pembelian, dan kartu stok dengan isi Supabase.
  Future<void> muatTransaksiDariSupabase() async {
    final r = transaksiRepo;
    if (r == null) return;
    try {
      final data = await r.semua();
      final kartu = await r.mutasi();
      penjualan
        ..clear()
        ..addAll(data.penjualan);
      pembelian
        ..clear()
        ..addAll(data.pembelian);
      mutasi
        ..clear()
        ..addAll(kartu);
      errorTransaksi = null;
    } catch (e) {
      errorTransaksi = 'Data transaksi belum bisa dimuat. ${pesanErrorDb(e)}';
      debugPrint(errorTransaksi);
    }
    notifyListeners();
  }

  /// Mengganti daftar pelanggan dengan isi tabel `pelanggan` di Supabase.
  Future<void> muatPelangganDariSupabase() async {
    final r = pelangganRepo;
    if (r == null) return;
    try {
      final data = await r.semua();
      pelanggan
        ..clear()
        ..addAll(data);
      errorPelanggan = null;
    } catch (e) {
      errorPelanggan =
          'Data pelanggan belum bisa dimuat dari Supabase. '
          'Pastikan supabase/pelanggan.sql sudah dijalankan. ($e)';
      debugPrint(errorPelanggan);
    }
    notifyListeners();
  }

  /// Mengganti daftar barang dengan isi tabel `barang` di Supabase.
  Future<void> muatBarangDariSupabase() async {
    final r = repo;
    if (r == null) return;
    memuatBarang = true;
    notifyListeners();
    try {
      final data = await r.semua();
      barang
        ..clear()
        ..addAll(data);
      errorSinkron = null;
    } catch (e) {
      errorSinkron = 'Gagal memuat barang dari Supabase: $e';
      debugPrint(errorSinkron);
    }
    memuatBarang = false;
    notifyListeners();
  }

  void _sinkron(Future<void> Function(BarangRepo r) aksi) {
    final r = repo;
    if (r != null) _tangkapError(aksi(r));
  }

  void _sinkronPelanggan(Future<void> Function(KontakRepo r) aksi) {
    final r = pelangganRepo;
    if (r != null) _tangkapError(aksi(r));
  }

  void _tangkapError(Future<void> f) {
    f.catchError((Object e) {
      errorSinkron = 'Gagal menyimpan ke Supabase: $e';
      debugPrint(errorSinkron);
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------- Barang
  Barang? cariBarang(String kode) {
    for (final b in barang) {
      if (b.kode == kode) return b;
    }
    return null;
  }

  /// Barang yang perlu diisi ulang. Barang dengan min. stok 0 (belum diatur)
  /// tidak ikut, supaya notifikasi tidak penuh oleh barang hasil impor Excel.
  List<Barang> get stokMenipis =>
      barang.where((b) => b.minStok > 0 && b.stok <= b.minStok).toList()
        ..sort((a, b) => (a.stok / max(a.minStok, 1)).compareTo(b.stok / max(b.minStok, 1)));

  double get nilaiStok => barang.fold(0, (s, b) => s + b.nilaiStok);

  void simpanBarang(Barang b, {String? kodeLama}) {
    final i = barang.indexWhere((e) => e.kode == (kodeLama ?? b.kode));
    if (i >= 0) {
      barang[i] = b;
    } else {
      barang.add(b);
    }
    _sinkron((r) => r.simpan(b, kodeLama: kodeLama));
    notifyListeners();
  }

  void hapusBarang(String kode) {
    barang.removeWhere((b) => b.kode == kode);
    _sinkron((r) => r.hapus(kode));
    notifyListeners();
  }

  /// Penyesuaian stok manual (stock opname).
  void sesuaikanStok(String kode, int stokBaru, String keterangan) {
    final b = cariBarang(kode);
    if (b == null) return;
    final r = transaksiRepo;
    if (r != null) {
      // Database mencatat stok dan kartu stok sekaligus.
      _tangkapError(r.sesuaikanStok(kode, stokBaru, keterangan));
    }
    _ubahStok(b, stokBaru - b.stok, keterangan, DateTime.now(), sinkron: r == null);
    notifyListeners();
  }

  /// [sinkron] false kalau stok di database sudah diubah oleh fungsi database.
  void _ubahStok(Barang b, int delta, String keterangan, DateTime tanggal, {bool sinkron = true}) {
    b.stok = max(0, b.stok + delta);
    if (sinkron) _sinkron((r) => r.ubahStok(b.kode, b.stok));
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
    if (!isSupplier) _sinkronPelanggan((r) => r.simpan(k, kodeLama: kodeLama));
    notifyListeners();
  }

  void hapusKontak(bool isSupplier, String kode) {
    (isSupplier ? supplier : pelanggan).removeWhere((e) => e.kode == kode);
    if (!isSupplier) _sinkronPelanggan((r) => r.hapus(kode));
    notifyListeners();
  }

  // -------------------------------------------------------------- Transaksi
  /// Menyimpan penjualan. Mengembalikan pesan error, atau null kalau berhasil.
  /// Dengan Supabase, nomor faktur [Transaksi.kode] diganti nomor dari database.
  Future<String?> tambahPenjualan(Transaksi t) async {
    final butuh = <String, int>{};
    for (final i in t.items) {
      butuh[i.kodeBarang] = (butuh[i.kodeBarang] ?? 0) + i.qtyDasar;
    }
    for (final e in butuh.entries) {
      final b = cariBarang(e.key);
      if (b == null) return 'Barang ${e.key} tidak ditemukan';
      if (b.stok < e.value) {
        return 'Stok ${b.nama} tidak cukup (tersedia ${b.stok} ${b.satuan})';
      }
    }
    final err = await _simpanKeDb(t, penjualan: true);
    if (err != null) return err;
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang)!;
      i.hargaPokok = b.hargaBeli * i.isi;
      _ubahStok(b, -i.qtyDasar, 'Penjualan ${t.kode}${_keteranganSatuan(i)}', t.tanggal,
          sinkron: transaksiRepo == null);
    }
    penjualan.add(t);
    notifyListeners();
    return null;
  }

  /// Menyimpan pembelian. Mengembalikan pesan error, atau null kalau berhasil.
  Future<String?> tambahPembelian(Transaksi t) async {
    final err = await _simpanKeDb(t, penjualan: false);
    if (err != null) return err;
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang);
      if (b == null) continue;
      // Harga beli terakhir per satuan dasar = harga setelah diskon ÷ isi (mis. per Dus ÷ 50).
      b.hargaBeli = i.hargaBersih / i.isi;
      i.hargaPokok = i.hargaBersih;
      _ubahStok(b, i.qtyDasar, 'Pembelian ${t.kode}${_keteranganSatuan(i)}', t.tanggal,
          sinkron: transaksiRepo == null);
    }
    pembelian.add(t);
    notifyListeners();
    return null;
  }

  /// Mis. " (2 Dus)" untuk kartu stok kalau dibeli/dijual bukan dalam satuan dasar.
  static String _keteranganSatuan(ItemTransaksi i) => i.isi > 1 ? ' (${i.qty} ${i.satuan})' : '';

  Future<String?> _simpanKeDb(Transaksi t, {required bool penjualan}) async {
    final r = transaksiRepo;
    if (r == null) return null;
    try {
      t.kode = await r.simpan(t, penjualan: penjualan);
      return null;
    } catch (e) {
      return pesanErrorDb(e);
    }
  }

  /// Menghapus transaksi dan mengembalikan stok seperti semula.
  /// Mengembalikan pesan error, atau null kalau berhasil.
  Future<String?> hapusTransaksi(Transaksi t, {required bool isPenjualan}) async {
    final r = transaksiRepo;
    if (r != null) {
      try {
        await r.hapus(t.kode);
      } catch (e) {
        return pesanErrorDb(e);
      }
    }
    for (final i in t.items) {
      final b = cariBarang(i.kodeBarang);
      if (b == null) continue;
      _ubahStok(b, isPenjualan ? i.qtyDasar : -i.qtyDasar, 'Batal ${t.kode}', DateTime.now(), sinkron: r == null);
    }
    (isPenjualan ? penjualan : pembelian).remove(t);
    notifyListeners();
    return null;
  }

  void ubahStatus(Transaksi t, String status) {
    t.status = status;
    final r = transaksiRepo;
    if (r != null) _tangkapError(r.ubahStatus(t.kode, status));
    notifyListeners();
  }

  Iterable<Transaksi> dalam(List<Transaksi> list, DateTimeRange r) => list.where((t) => dalamRentang(t.tanggal, r));

  double totalDalam(List<Transaksi> list, DateTimeRange r) => dalam(list, r).fold(0, (s, t) => s + t.total);

  double labaKotorDalam(DateTimeRange r) => dalam(penjualan, r).fold(0, (s, t) => s + t.labaKotor);

  double biayaDalam(DateTimeRange r) => biaya.where((b) => dalamRentang(b.tanggal, r)).fold(0, (s, b) => s + b.jumlah);

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

  /// Daerah yang sudah dipakai pelanggan & supplier (urut abjad).
  List<String> get daerahTerpakai {
    final set = <String>{};
    for (final d in [
      for (final k in [...pelanggan, ...supplier]) k.daerah,
      for (final t in [...penjualan, ...pembelian]) t.daerah,
    ]) {
      if (d.trim().isNotEmpty) set.add(d.trim());
    }
    return set.toList()..sort();
  }

  /// Daerah pelanggan (atau supplier) dengan nama [nama].
  String daerahPihak(bool isSupplier, String nama) {
    final d = cariKontak(isSupplier, nama)?.daerah.trim() ?? '';
    return d.isEmpty ? tanpaDaerah : d;
  }

  /// Daerah transaksi [t]; transaksi lama tanpa daerah memakai daerah pelanggannya.
  String daerahTransaksi(Transaksi t, {required bool penjualan}) =>
      t.daerah.trim().isNotEmpty ? t.daerah.trim() : daerahPihak(!penjualan, t.pihak);

  /// Menyamakan penulisan daerah dengan yang sudah ada (mis. "medan" → "Medan"),
  /// supaya laporan per daerah tidak terpecah karena beda huruf besar/kecil.
  String rapikanDaerah(String daerah) {
    final d = daerah.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (d.isEmpty) return '';
    for (final x in [...daerahTerpakai, ...daerahSaran]) {
      if (x.toLowerCase() == d.toLowerCase()) return x;
    }
    return d.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
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
        _b('BRG0031', 'Cat Nippon 1kg', 'Cat', 'Kaleng', 3, 15, 21000, 25000)..isiDus = 12,
        _b('BRG0034', 'Cat Avian 5kg', 'Cat', 'Galon', 25, 10, 95000, 115000),
        _b('BRG0045', 'Paku 5 cm', 'Perlengkapan Bangunan', 'Kg', 2, 10, 8000, 10000),
        _b('BRG0050', 'Palu Kambing', 'Alat Pertukangan', 'Pcs', 30, 10, 35000, 45000),
        _b('BRG0052', 'Gergaji Kayu', 'Alat Pertukangan', 'Pcs', 18, 5, 55000, 70000),
        _b('BRG0067', 'Lem Kaca', 'Lainnya', 'Tube', 6, 20, 10000, 13000)..isiKotak = 12..isiDus = 144,
        _b('BRG0071', 'Kunci Pintu Solid', 'Kunci & Engsel', 'Set', 22, 8, 85000, 110000),
        _b('BRG0089', 'Engsel Pintu', 'Kunci & Engsel', 'Pcs', 3, 15, 11000, 15000)..isiKotak = 10..isiDus = 50,
        _b('BRG0090', 'Pipa PVC 3/4"', 'Perlengkapan Bangunan', 'Batang', 60, 20, 22000, 28000),
        _b('BRG0095', 'Meteran 5m', 'Alat Pertukangan', 'Pcs', 15, 5, 25000, 35000),
        _b('BRG0098', 'Amplas Kayu', 'Lainnya', 'Lembar', 90, 30, 2500, 4000)..isiDus = 100,
        // Dijual per lusin: 1 Dus = 5 Lusin (60 Bh).
        _b('BRG0099', 'Water Pas Eurostar 12"', 'Alat Pertukangan', 'Lusin', 8, 2, 300000, 360000)..isiDus = 5,
      ]);

    supplier
      ..clear()
      ..addAll([
        Kontak(
          kode: 'SUP001',
          nama: 'PT BESI UTAMA',
          telepon: '061-4550123',
          alamat: 'Jl. Industri No. 12',
          daerah: 'Medan',
        ),
        Kontak(
          kode: 'SUP002',
          nama: 'CV CAT MAKMUR',
          telepon: '0812-3456-7890',
          alamat: 'Jl. Merdeka No. 45',
          daerah: 'Medan',
        ),
        Kontak(
          kode: 'SUP003',
          nama: 'TOKO TEKNIK JAYA',
          telepon: '0813-2222-1111',
          alamat: 'Jl. Pahlawan No. 8',
          daerah: 'Banda Aceh',
        ),
        Kontak(
          kode: 'SUP004',
          nama: 'SINAR LOGAM',
          telepon: '061-7778899',
          alamat: 'Jl. Sisingamangaraja',
          daerah: 'Medan',
        ),
        Kontak(
          kode: 'SUP005',
          nama: 'MITRA BANGUNAN',
          telepon: '0815-9090-1212',
          alamat: 'Jl. Teuku Umar No. 101',
          daerah: 'Banda Aceh',
        ),
      ]);

    pelanggan
      ..clear()
      ..addAll([
        Kontak(
          kode: 'PLG001',
          nama: 'TOKO MAJU',
          telepon: '0812-1111-2222',
          alamat: 'Jl. Melati No. 3',
          daerah: 'Banda Aceh',
        ),
        Kontak(
          kode: 'PLG002',
          nama: 'BANGUN JAYA',
          telepon: '0813-3333-4444',
          alamat: 'Jl. Kenanga No. 17',
          daerah: 'Medan',
        ),
        Kontak(
          kode: 'PLG003',
          nama: 'PERINTIS MAKMUR',
          telepon: '0821-5555-6666',
          alamat: 'Jl. Anggrek No. 9',
          daerah: 'Lhokseumawe',
        ),
        Kontak(
          kode: 'PLG004',
          nama: 'KITA BAKARAN BATU',
          telepon: '0857-7777-8888',
          alamat: 'Jl. Mawar No. 21',
          daerah: 'Medan',
        ),
        Kontak(
          kode: 'PLG005',
          nama: 'KO FENDY',
          telepon: '0819-9999-0000',
          alamat: 'Jl. Dahlia No. 5',
          daerah: 'Binjai',
        ),
        Kontak(kode: 'PLG006', nama: 'UMUM', alamat: '-'),
      ]);

    pengguna
      ..clear()
      ..addAll([
        Pengguna(username: 'owner', nama: 'Pemilik Toko', role: 'Owner', email: 'owner@sinarsehati.id'),
        Pengguna(username: 'admin', nama: 'Budi Santoso', role: 'Admin', email: 'admin@sinarsehati.id'),
        Pengguna(username: 'sales1', nama: 'Rina Lestari', role: 'Sales', email: 'sales@sinarsehati.id'),
        Pengguna(username: 'sales2', nama: 'Dewi Anggraini', role: 'Sales', email: 'dewi@sinarsehati.id', aktif: false),
      ]);

    profil = ProfilToko(
      nama: 'Sinar Sehati',
      alamat: 'Toko Perkakas & Kunci Pintu',
      telepon: '0812-0000-1234',
      email: 'admin@sinarsehati.id',
    );

    // Penjualan & pembelian mulai kosong; dengan Supabase diambil dari database.
    penjualan.clear();
    pembelian.clear();
    biaya.clear();
    mutasi.clear();
    notifyListeners();
    // Saat memakai Supabase, barang, pelanggan & transaksi tetap diambil dari database.
    if (repo != null) muatDariSupabase();
  }

  Barang _b(String kode, String nama, String kat, String sat, int stok, int min, double beli, double jual) => Barang(
    kode: kode,
    nama: nama,
    kategori: kat,
    satuan: sat,
    stok: stok,
    minStok: min,
    hargaBeli: beli,
    hargaJual: jual,
  );
}

/// Menyediakan [AppState] ke seluruh widget. Ambil dengan `AppScope.of(context)`.
///
/// [pemicu] (opsional) menentukan kapan widget di bawahnya dibangun ulang;
/// dipakai shell agar halaman yang sedang tersembunyi tidak ikut rebuild.
class AppScope extends InheritedNotifier<Listenable> {
  const AppScope({super.key, required this.state, Listenable? pemicu, required super.child})
    : super(notifier: pemicu ?? state);

  final AppState state;

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;

  /// Ambil state tanpa ikut rebuild (untuk dipakai di callback).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.state;
}
