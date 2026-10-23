import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, LogicalKeyboardKey;

import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/auth/demo_auth_service.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/main.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/shell.dart';

/// Lebar layar yang diuji: HP kecil, HP, HP besar, tablet kecil, tablet.
const _ukuran = [Size(320, 640), Size(360, 740), Size(414, 800), Size(600, 900), Size(768, 1024)];

/// Mengumpulkan semua error tampilan (overflow, dll.) selama [kerja] berjalan,
/// tidak hanya yang pertama.
/// Langkah yang sedang diuji; ikut dicatat di laporan error.
String _lokasi = '';

Future<List<String>> _kumpulkanError(Future<void> Function() kerja) async {
  final hasil = <String>[];
  final lama = FlutterError.onError;
  FlutterError.onError = (d) {
    final teks = d.toString(minLevel: DiagnosticLevel.debug);
    final judul = d.exceptionAsString().split('\n').first;
    final kode = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(teks)?.group(0) ?? '?';
    hasil.add('$_lokasi | $judul | $kode');
  };
  try {
    await kerja();
  } finally {
    FlutterError.onError = lama;
  }
  return hasil.toSet().toList();
}

/// Memuat font Roboto dari Flutter SDK. Tanpa ini tes memakai font Ahem yang
/// setiap hurufnya selebar kotak penuh, jadi teks tampak jauh lebih lebar dari
/// aslinya dan hasil ukuran layar tidak bisa dipercaya.
Future<void> _muatFont() async {
  // Cadangan: .../bin/cache/dart-sdk/bin/dart → naik lima tingkat = akar Flutter.
  final akar = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final loader = FontLoader('Roboto');
  var ada = false;
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final file = File('$akar/bin/cache/artifacts/material_fonts/$f');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()))));
      ada = true;
    }
  }
  if (ada) await loader.load();
}

void main() {
  setUpAll(_muatFont);

  for (final ukuran in _ukuran) {
    testWidgets('Tidak ada overflow: login, daftar, lupa password di lebar ${ukuran.width.toInt()}', (tester) async {
      tester.view.physicalSize = ukuran;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = AppState();
      final auth = DemoAuthService(state, jeda: Duration.zero);
      final error = await _kumpulkanError(() async {
        await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
        await tester.pumpAndSettle();
        _lokasi = 'Login';
        await tester.ensureVisible(find.text('Daftar sekarang'));
        await tester.tap(find.text('Daftar sekarang'));
        await tester.pumpAndSettle();
        _lokasi = 'Daftar';
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Lupa password?'));
        await tester.tap(find.text('Lupa password?'));
        await tester.pumpAndSettle();
        _lokasi = 'Lupa password';
        await tester.enterText(find.byType(TextFormField).first, 'sales@sinarsehati.id');
        await tester.ensureVisible(find.text('Kirim Kode'));
        await tester.tap(find.text('Kirim Kode'));
        await tester.pumpAndSettle();
      });
      expect(error, isEmpty, reason: error.join('\n'));
    });

    testWidgets('Tidak ada overflow: semua halaman & dialog di lebar ${ukuran.width.toInt()}', (tester) async {
      tester.view.physicalSize = ukuran;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = AppState();
      final auth = DemoAuthService(state, jeda: Duration.zero);
      await auth.login(DemoAuthService.emailDemo, DemoAuthService.passwordDemo);
      // Satu penjualan agar tabel, detail, dan faktur punya isi.
      final b = state.barang.firstWhere((e) => e.stok > 5);
      await state.tambahPenjualan(Transaksi(
        kode: 'PJ00001',
        tanggal: DateTime.now(),
        pihak: 'TOKO MAJU',
        status: 'Piutang',
        daerah: 'Banda Aceh',
        items: [ItemTransaksi(kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 2, harga: b.hargaJual)],
      ));

      final error = await _kumpulkanError(() async {
        await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
        await tester.pumpAndSettle();
        final nav = tester.widget<ShellNav>(find.byType(ShellNav));

        Future<void> tutupDialog() async {
          for (var i = 0; i < 3; i++) {
            if (find.byType(Dialog).evaluate().isEmpty) break;
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
        }

        // Semua halaman
        for (final m in menus) {
          _lokasi = 'Halaman ${m.label}';
          nav.buka(m.label);
          await tester.pumpAndSettle();
          final e = tester.takeException();
          if (e != null) FlutterError.onError!(FlutterErrorDetails(exception: e, library: m.label));
        }

        // Dialog form
        for (final (menu, tombol) in [
          ('Penjualan', 'Transaksi Baru'),
          ('Pembelian', 'Transaksi Baru'),
          ('Data Barang', 'Tambah Barang'),
          ('Data Supplier', 'Tambah Supplier'),
          ('Data Pelanggan', 'Tambah Pelanggan'),
          ('Pengguna', 'Tambah Pengguna'),
        ]) {
          nav.buka(menu);
          await tester.pumpAndSettle();
          _lokasi = 'Dialog $tombol ($menu)';
          await tester.tap(find.text(tombol), warnIfMissed: false);
          await tester.pumpAndSettle();
          await tutupDialog();
        }

        // Detail transaksi dan halaman faktur
        nav.buka('Penjualan');
        await tester.pumpAndSettle();
        _lokasi = 'Detail transaksi';
        final lihat = find.byTooltip('Detail');
        if (lihat.evaluate().isNotEmpty) {
          await tester.ensureVisible(lihat.first);
          await tester.tap(lihat.first, warnIfMissed: false);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      });

      expect(error, isEmpty, reason: error.join('\n'));
    });
  }
}
