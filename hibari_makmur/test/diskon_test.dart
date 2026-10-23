import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/auth/demo_auth_service.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/faktur/faktur_pdf.dart';
import 'package:hibari_makmur/main.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/shell.dart';
import 'package:hibari_makmur/utils/format.dart';

ItemTransaksi _item(Barang b, {int qty = 1, double? harga, double diskon = 0}) => ItemTransaksi(
    kodeBarang: b.kode,
    namaBarang: b.nama,
    satuan: b.satuan,
    qty: qty,
    harga: harga ?? b.hargaJual,
    diskon: diskon,
    hargaPokok: b.hargaBeli);

Future<AppState> _bukaApp(WidgetTester tester, String email) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState();
  final auth = DemoAuthService(state, jeda: Duration.zero);
  await auth.login(email, DemoAuthService.passwordDemo);
  await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
  await tester.pumpAndSettle();
  return state;
}

/// Membuka form penjualan baru, memilih pelanggan UMUM dan barang [b].
Future<void> _isiFormPenjualan(WidgetTester tester, Barang b) async {
  tester.widget<ShellNav>(find.byType(ShellNav)).buka('Penjualan');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transaksi Baru'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Pelanggan'), 'UMUM');
  await tester.pumpAndSettle();
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Barang 1'), b.nama);
  await tester.pumpAndSettle();
  await tester.tap(find.text('${b.kode} — ${b.nama}').last);
  await tester.pumpAndSettle();
}

void main() {
  test('Total transaksi memperhitungkan diskon barang dan diskon faktur', () {
    final s = AppState();
    final [a, b] = s.barang.take(2).toList();
    final t = Transaksi(
      kode: 'PJ1',
      tanggal: DateTime(2026, 10, 1),
      pihak: 'UMUM',
      status: 'Lunas',
      diskon: 5000,
      items: [_item(a, qty: 2, harga: 10000, diskon: 10), _item(b, qty: 1, harga: 30000)],
    );
    expect(t.items[0].subtotal, 18000);
    expect(t.subtotal, 48000);
    expect(t.diskonBarang, 2000);
    expect(t.totalDiskon, 7000);
    expect(t.total, 43000);
    // Potongan faktur dibagi sebanding subtotal, jumlahnya tetap = total.
    expect(t.items.fold<double>(0, (x, i) => x + t.porsiTotal(i)), closeTo(43000, 0.001));
    expect(persen(10), '10%');
    expect(persen(2.5), '2,5%');
  });

  test('Pembelian dengan diskon memperbarui harga beli ke harga bersih', () async {
    final s = AppState();
    final b = s.barang.first;
    final err = await s.tambahPembelian(Transaksi(
      kode: s.kodePembelianBaru,
      tanggal: DateTime.now(),
      pihak: 'Supplier',
      status: 'Lunas',
      items: [_item(b, qty: 4, harga: 20000, diskon: 25)],
    ));
    expect(err, isNull);
    expect(b.hargaBeli, 15000);
  });

  test('Faktur PDF dengan diskon terbentuk di semua ukuran kertas', () async {
    final s = AppState();
    final t = Transaksi(
      kode: 'PJ00009',
      tanggal: DateTime(2026, 10, 19),
      pihak: s.pelanggan.first.nama,
      status: 'Lunas',
      diskon: 2500,
      items: [_item(s.barang[0], qty: 3, diskon: 5), _item(s.barang[1], qty: 2)],
    );
    for (final ukuran in PengaturanFaktur.ukuranList) {
      final bytes = await buatFakturPdf(DataFaktur(
        transaksi: t,
        penjualan: true,
        profil: s.profil,
        pengaturan: PengaturanFaktur(ukuran: ukuran, tampilkanLogo: false),
      ));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: ukuran);
    }
  });

  testWidgets('Form penjualan: diskon barang & diskon faktur tersimpan', (tester) async {
    final state = await _bukaApp(tester, DemoAuthService.emailDemo);
    final b = state.barang.firstWhere((e) => e.stok > 5 && e.hargaJual > 0);
    await _isiFormPenjualan(tester, b);
    await tester.enterText(find.widgetWithText(TextField, 'Qty').first, '2');
    await tester.enterText(find.widgetWithText(TextField, 'Disc').first, '10');
    await tester.enterText(find.widgetWithText(TextField, 'Diskon Faktur'), '5');
    await tester.pumpAndSettle();
    expect(find.textContaining('Diskon −'), findsOneWidget);

    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final t = state.penjualan.single;
    expect(t.items.single.diskon, 10);
    final subtotal = 2 * b.hargaJual * 0.9;
    expect(t.diskon, (subtotal * 0.05).roundToDouble());
    expect(t.total, subtotal - t.diskon);
  });

  testWidgets('Sales: stok hanya bisa dilihat dan harga jual terkunci', (tester) async {
    final state = await _bukaApp(tester, 'sales@sinarsehati.id');
    tester.widget<ShellNav>(find.byType(ShellNav)).buka('Stok Barang');
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode lihat saja'), findsOneWidget);
    expect(find.text('Tambah Barang'), findsNothing);
    expect(find.text('Sesuaikan'), findsNothing);
    expect(find.byTooltip('Ubah data barang'), findsNothing);

    final b = state.barang.firstWhere((e) => e.stok > 5 && e.hargaJual > 0);
    await _isiFormPenjualan(tester, b);
    final harga = tester.widget<TextField>(find.widgetWithText(TextField, 'Harga').first);
    expect(harga.readOnly, isTrue);
    await tester.enterText(find.widgetWithText(TextField, 'Disc').first, '5');
    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pumpAndSettle();
    final it = state.penjualan.single.items.single;
    expect(it.harga, b.hargaJual);
    expect(it.diskon, 5);
  });
}
