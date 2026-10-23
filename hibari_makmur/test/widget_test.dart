import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:hibari_makmur/auth/demo_auth_service.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/data/pengguna_repo.dart';
import 'package:hibari_makmur/main.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/shell.dart';

/// Tiruan tabel `pengguna` di Supabase untuk menguji halaman Pengguna.
class PenggunaRepoTiruan implements PenggunaRepo {
  final data = [
    Pengguna(
        id: '1', username: 'owner', email: 'owner@sinarsehati.id', nama: 'Pemilik', role: 'Owner',
        dibuatPada: DateTime(2026, 10, 1)),
    Pengguna(
        id: '2', username: 'fendy', email: 'fendy@x.id', nama: 'Fendy', role: 'Sales', aktif: false,
        dibuatPada: DateTime(2026, 10, 5)),
  ];
  String? tolak;

  @override
  Future<List<Pengguna>> semua() async => [for (final p in data) p];

  @override
  Future<void> ubah(String id, {required String nama, required String role, required bool aktif}) async {
    if (tolak != null) throw PostgrestException(message: tolak!);
    final p = data.firstWhere((e) => e.id == id);
    p
      ..nama = nama
      ..role = role
      ..aktif = aktif;
  }
}

/// Menjalankan aplikasi (mode demo) dan login sebagai [email].
Future<(AppState, DemoAuthService)> bukaApp(WidgetTester tester,
    {String? email = DemoAuthService.emailDemo, Size size = const Size(1600, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState();
  final auth = DemoAuthService(state, jeda: Duration.zero);
  if (email != null) await auth.login(email, DemoAuthService.passwordDemo);
  await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
  await tester.pumpAndSettle();
  return (state, auth);
}

void main() {
  for (final size in const [Size(1600, 1100), Size(800, 1000)]) {
    testWidgets('Semua halaman tampil tanpa error (${size.width.toInt()}px)', (tester) async {
      await bukaApp(tester, size: size);
      expect(find.text('Grafik Penjualan & Pembelian'), findsOneWidget);
      final nav = tester.widget<ShellNav>(find.byType(ShellNav));
      for (final m in menus) {
        nav.buka(m.label);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: m.label);
      }
    });
  }

  testWidgets('Dialog transaksi & form terbuka', (tester) async {
    await bukaApp(tester);
    final nav = tester.widget<ShellNav>(find.byType(ShellNav));
    for (final (menu, tombol) in [
      ('Penjualan', 'Transaksi Baru'),
      ('Pembelian', 'Transaksi Baru'),
      ('Data Barang', 'Tambah Barang'),
      ('Data Supplier', 'Tambah Supplier'),
      ('Pengguna', 'Tambah Pengguna'),
    ]) {
      nav.buka(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tombol));
      await tester.pumpAndSettle();
      expect(find.textContaining('Simpan'), findsOneWidget, reason: menu);
      expect(tester.takeException(), isNull, reason: menu);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Login lewat form (layar lebar & HP)', (tester) async {
    for (final size in const [Size(1400, 900), Size(400, 800)]) {
      await bukaApp(tester, email: null, size: size);
      expect(find.text('Selamat Datang di'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Password salah
      await tester.enterText(find.byType(TextFormField).at(0), DemoAuthService.emailDemo);
      await tester.enterText(find.byType(TextFormField).at(1), 'salah123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Email atau password salah.'), findsOneWidget);

      // Password benar
      await tester.enterText(find.byType(TextFormField).at(1), DemoAuthService.passwordDemo);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Total Penjualan'), findsOneWidget);
    }
  });

  testWidgets('Lupa password: kirim kode lalu ganti password', (tester) async {
    final (_, auth) = await bukaApp(tester, email: null);
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'sales@sinarsehati.id');
    await tester.tap(find.text('Kirim Kode'));
    await tester.pumpAndSettle();
    final kode = auth.kodeTerakhir!;
    expect(find.textContaining(kode), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '000000' == kode ? '111111' : '000000');
    await tester.enterText(fields.at(1), 'rahasia99');
    await tester.enterText(fields.at(2), 'rahasia99');
    await tester.tap(find.text('Simpan Password Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Kode salah.'), findsOneWidget);

    await tester.enterText(fields.at(0), kode);
    await tester.tap(find.text('Simpan Password Baru'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Password berhasil diubah'), findsOneWidget);

    await expectLater(auth.login('sales@sinarsehati.id', DemoAuthService.passwordDemo), throwsA(anything));
    await auth.login('sales@sinarsehati.id', 'rahasia99');
    await tester.pumpAndSettle();
    expect(find.text('Total Penjualan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar akun baru lalu login sebagai Sales', (tester) async {
    final (state, auth) = await bukaApp(tester, email: null);
    await tester.tap(find.text('Daftar sekarang'));
    await tester.pumpAndSettle();
    final f = find.byType(TextFormField);
    await tester.enterText(f.at(0), 'Siti Aminah');
    await tester.enterText(f.at(1), 'siti@contoh.id');
    await tester.enterText(f.at(2), 'siti1234');
    await tester.enterText(f.at(3), 'siti1234');
    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pendaftaran berhasil'), findsOneWidget);
    expect(state.penggunaDenganEmail('siti@contoh.id')?.role, 'Sales');

    await auth.login('siti@contoh.id', 'siti1234');
    await tester.pumpAndSettle();
    // Sales tidak melihat menu khusus Owner/Admin
    Finder diSidebar(String t) => find.descendant(of: find.byType(Sidebar), matching: find.text(t));
    expect(diSidebar('Penjualan'), findsOneWidget);
    expect(diSidebar('Pembelian'), findsNothing);
    expect(diSidebar('Pengaturan'), findsNothing);
    expect(diSidebar('Pengguna'), findsNothing);
    expect(diSidebar('Laba Kotor'), findsNothing);

    // Admin melihat menu operasional, tapi tidak Laba Kotor & Pengguna
    await auth.login('admin@sinarsehati.id', DemoAuthService.passwordDemo);
    await tester.pumpAndSettle();
    expect(diSidebar('Pembelian'), findsOneWidget);
    expect(diSidebar('Pengaturan'), findsOneWidget);
    expect(diSidebar('Laba Kotor'), findsNothing);
    expect(diSidebar('Pengguna'), findsNothing);
  });

  testWidgets('Akun nonaktif tidak bisa login', (tester) async {
    final s = AppState();
    final auth = DemoAuthService(s, jeda: Duration.zero);
    expect(() => auth.login('dewi@sinarsehati.id', DemoAuthService.passwordDemo), throwsA(anything));
  });

  testWidgets('Form penjualan: pelanggan bisa diketik, baris barang bertambah otomatis', (tester) async {
    final (state, _) = await bukaApp(tester);
    final nav = tester.widget<ShellNav>(find.byType(ShellNav));
    nav.buka('Penjualan');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Barang'), findsNothing);

    // Nama pelanggan lengkap → daerahnya terisi otomatis.
    TextField daerahField() => tester.widget<TextField>(find.widgetWithText(TextField, 'Daerah'));
    await tester.enterText(find.widgetWithText(TextField, 'Pelanggan'), 'toko maju');
    await tester.pumpAndSettle();
    expect(daerahField().controller!.text, 'Banda Aceh');

    // Ketik sebagian nama pelanggan lalu pilih dari daftar; daerah diganti manual.
    await tester.enterText(find.widgetWithText(TextField, 'Pelanggan'), 'umu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('UMUM').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Daerah'), ' medan');
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero); // tutup daftar saran
    await tester.pumpAndSettle();

    // Pilih barang di baris 1 → baris 2 muncul sendiri.
    final b = state.barang.firstWhere((e) => e.stok > 5);
    expect(find.widgetWithText(TextField, 'Barang 2'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Barang 1'), b.nama);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${b.kode} — ${b.nama}').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Barang 2'), findsOneWidget);

    // Dialog cetak sistem tidak ada di tes, jadi cetak gagal; transaksi harus tetap tersimpan.
    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('tersimpan'), findsOneWidget);
    expect(state.penjualan, hasLength(1));
    expect(state.penjualan.single.pihak, 'UMUM');
    expect(state.penjualan.single.daerah, 'Medan');
    expect(state.penjualan.single.items.single.kodeBarang, b.kode);
  });

  testWidgets('Pelanggan baru dengan daerah, lalu laba kotor per daerah', (tester) async {
    final (state, _) = await bukaApp(tester);
    final nav = tester.widget<ShellNav>(find.byType(ShellNav));
    nav.buka('Data Pelanggan');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Pelanggan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Pelanggan'), 'TOKO SEJAHTERA');
    await tester.enterText(find.widgetWithText(TextFormField, 'Daerah / Kota'), '  medan ');
    await tester.pumpAndSettle();
    expect(find.text('Medan'), findsWidgets); // saran daerah muncul
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(state.cariKontak(false, 'TOKO SEJAHTERA')?.daerah, 'Medan');
    expect(state.daerahPihak(false, 'UMUM'), AppState.tanpaDaerah);

    nav.buka('Laba Kotor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per Daerah'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pengguna (database): Owner menyetujui akun & mengubah role', (tester) async {
    final (state, _) = await bukaApp(tester); // login sebagai owner@sinarsehati.id
    final repo = PenggunaRepoTiruan();
    state.penggunaRepo = repo;
    await state.muatPenggunaDariSupabase();
    final nav = tester.widget<ShellNav>(find.byType(ShellNav));
    nav.buka('Pengguna');
    await tester.pumpAndSettle();

    // Tabel lebar bisa digeser; geser dulu ke tombol yang dituju.
    Future<void> ketuk(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    expect(find.text('Tambah Pengguna'), findsNothing);
    expect(find.textContaining('1 akun belum aktif'), findsOneWidget);
    expect(find.text('fendy@x.id'), findsOneWidget);

    // Akun yang belum aktif ada di atas. Setujui & jadikan Admin.
    await ketuk(find.byTooltip('Ubah').first);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repo.data[1].role, 'Admin');
    expect(repo.data[1].aktif, isTrue);
    expect(state.pengguna.firstWhere((p) => p.id == '2').role, 'Admin');
    expect(find.textContaining('akun belum aktif'), findsNothing);

    // Akun sendiri: role & status terkunci.
    await ketuk(find.byTooltip('Ubah').last);
    expect(find.textContaining('akun Anda sendiri'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Penolakan dari database ditampilkan, perubahan tidak diterapkan.
    repo.tolak = 'Minimal harus ada satu Owner yang aktif.';
    await ketuk(find.byTooltip('Ubah').first);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Minimal harus ada satu Owner yang aktif.'), findsOneWidget);
    expect(repo.data[1].aktif, isTrue);
  });

  testWidgets('Tambah penjualan mengurangi stok', (tester) async {
    final s = AppState();
    final b = s.barang.firstWhere((e) => e.stok > 10);
    final awal = b.stok;
    final err = await s.tambahPenjualan(Transaksi(
      kode: s.kodePenjualanBaru,
      tanggal: DateTime.now(),
      pihak: 'UMUM',
      items: [ItemTransaksi(kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 3, harga: b.hargaJual)],
      status: 'Lunas',
    ));
    expect(err, isNull);
    expect(b.stok, awal - 3);
    expect(
        await s.tambahPenjualan(Transaksi(
          kode: s.kodePenjualanBaru,
          tanggal: DateTime.now(),
          pihak: 'UMUM',
          items: [ItemTransaksi(kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 99999, harga: 1)],
          status: 'Lunas',
        )),
        isNotNull);
  });
}
