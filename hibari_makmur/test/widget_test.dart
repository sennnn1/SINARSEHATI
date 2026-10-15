import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/auth/demo_auth_service.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/main.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/shell.dart';

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
      ('Laba Rugi', 'Catat Biaya'),
    ]) {
      nav.buka(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tombol));
      await tester.pumpAndSettle();
      expect(find.text('Simpan'), findsOneWidget, reason: menu);
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
    await tester.enterText(find.byType(TextFormField).first, 'kasir@sinarsehati.id');
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

    await expectLater(auth.login('kasir@sinarsehati.id', DemoAuthService.passwordDemo), throwsA(anything));
    await auth.login('kasir@sinarsehati.id', 'rahasia99');
    await tester.pumpAndSettle();
    expect(find.text('Total Penjualan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar akun baru lalu login sebagai Kasir', (tester) async {
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
    expect(state.penggunaDenganEmail('siti@contoh.id')?.role, 'Kasir');

    await auth.login('siti@contoh.id', 'siti1234');
    await tester.pumpAndSettle();
    // Kasir tidak melihat menu khusus Admin/Gudang
    Finder diSidebar(String t) => find.descendant(of: find.byType(Sidebar), matching: find.text(t));
    expect(diSidebar('Penjualan'), findsOneWidget);
    expect(diSidebar('Pembelian'), findsNothing);
    expect(diSidebar('Pengaturan'), findsNothing);
    expect(diSidebar('Pengguna'), findsNothing);
  });

  testWidgets('Akun nonaktif tidak bisa login', (tester) async {
    final s = AppState();
    final auth = DemoAuthService(s, jeda: Duration.zero);
    expect(() => auth.login('dewi@sinarsehati.id', DemoAuthService.passwordDemo), throwsA(anything));
  });

  testWidgets('Tambah penjualan mengurangi stok', (tester) async {
    final s = AppState();
    final b = s.barang.firstWhere((e) => e.stok > 10);
    final awal = b.stok;
    final err = s.tambahPenjualan(Transaksi(
      kode: s.kodePenjualanBaru,
      tanggal: DateTime.now(),
      pihak: 'UMUM',
      items: [ItemTransaksi(kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 3, harga: b.hargaJual)],
      status: 'Lunas',
    ));
    expect(err, isNull);
    expect(b.stok, awal - 3);
    expect(
        s.tambahPenjualan(Transaksi(
          kode: s.kodePenjualanBaru,
          tanggal: DateTime.now(),
          pihak: 'UMUM',
          items: [ItemTransaksi(kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 99999, harga: 1)],
          status: 'Lunas',
        )),
        isNotNull);
  });
}
