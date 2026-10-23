import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/auth/demo_auth_service.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/faktur/faktur_pdf.dart';
import 'package:hibari_makmur/main.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/shell.dart';

Barang _engsel(AppState s) => s.barang.firstWhere((b) => b.nama == 'Engsel Pintu');

ItemTransaksi _perDus(Barang b, {int qty = 1, required double harga}) => ItemTransaksi(
    kodeBarang: b.kode,
    namaBarang: b.nama,
    satuan: 'Dus',
    qty: qty,
    harga: harga,
    isi: b.isiSatuan('Dus'),
    satuanDasar: b.satuan);

void main() {
  test('Satuan tersedia: satuan dasar, Kotak, dan Dus beserta isinya', () {
    final b = _engsel(AppState());
    expect(b.satuanTersedia.map((s) => '${s.nama}:${s.isi}'), ['Pcs:1', 'Kotak:10', 'Dus:50']);
    expect(b.isiSatuan('Dus'), 50);
    expect(b.isiSatuan('Pcs'), 1);
    b.stok = 120;
    expect(b.stokDalamDus(), '2 Dus + 20 Pcs');
    // Satuan dasar Kotak: pilihan Kotak tidak dobel.
    b.satuan = 'Kotak';
    expect(b.satuanTersedia.map((s) => s.nama), ['Kotak', 'Dus']);
  });

  test('Barang per lusin: 1 Dus = 5 Lusin (60 Bh)', () {
    final b = AppState().barang.firstWhere((b) => b.satuan == 'Lusin');
    expect(b.keteranganIsi('Dus'), '1 Dus = 5 Lusin (60 Bh)');
    expect(_engsel(AppState()).keteranganIsi('Dus'), '1 Dus = 50 Pcs');
  });

  test('Beli 1 Dus menambah stok sebanyak isi dan harga beli jadi per Pcs', () async {
    final s = AppState();
    final b = _engsel(s);
    final awal = b.stok;
    final err = await s.tambahPembelian(Transaksi(
      kode: s.kodePembelianBaru,
      tanggal: DateTime.now(),
      pihak: 'Supplier',
      status: 'Lunas',
      items: [_perDus(b, harga: 500000)],
    ));
    expect(err, isNull);
    expect(b.stok, awal + 50);
    expect(b.hargaBeli, 10000);
    expect(s.mutasi.first.keterangan, contains('(1 Dus)'));

    // Hapus pembelian mengembalikan stok seperti semula.
    await s.hapusTransaksi(s.pembelian.single, isPenjualan: false);
    expect(b.stok, awal);
  });

  test('Jual per Dus mengurangi stok dalam Pcs dan menghitung HPP per Dus', () async {
    final s = AppState();
    final b = _engsel(s)..stok = 60;
    final t = Transaksi(
      kode: s.kodePenjualanBaru,
      tanggal: DateTime.now(),
      pihak: 'UMUM',
      status: 'Lunas',
      items: [_perDus(b, harga: b.hargaJual * 50)],
    );
    expect(await s.tambahPenjualan(t), isNull);
    expect(b.stok, 10);
    expect(t.items.single.hargaPokok, b.hargaBeli * 50);
    expect(t.labaKotor, (b.hargaJual - b.hargaBeli) * 50);
    // Stok tidak cukup untuk 1 Dus lagi.
    final lagi = Transaksi(
        kode: 'X', tanggal: DateTime.now(), pihak: 'UMUM', status: 'Lunas', items: [_perDus(b, harga: 1)]);
    expect(await s.tambahPenjualan(lagi), isNotNull);
  });

  test('Faktur dengan barang per Dus terbentuk', () async {
    final s = AppState();
    final t = Transaksi(
        kode: 'PB00001',
        tanggal: DateTime(2026, 10, 23),
        pihak: 'Supplier',
        status: 'Lunas',
        items: [_perDus(_engsel(s), qty: 2, harga: 500000)]);
    for (final ukuran in ['A5', 'Struk 58 mm']) {
      final bytes = await buatFakturPdf(DataFaktur(
          transaksi: t, penjualan: false, profil: s.profil, pengaturan: PengaturanFaktur(ukuran: ukuran)));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });

  testWidgets('Form pembelian: pilih Dus, harga & stok ikut isi dus', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    final auth = DemoAuthService(state, jeda: Duration.zero);
    await auth.login(DemoAuthService.emailDemo, DemoAuthService.passwordDemo);
    await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
    await tester.pumpAndSettle();

    final b = _engsel(state);
    final awal = b.stok;
    final hargaPcs = b.hargaBeli;
    tester.widget<ShellNav>(find.byType(ShellNav)).buka('Pembelian');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Supplier'), state.supplier.first.nama);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Barang 1'), b.nama);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${b.kode} — ${b.nama}').last);
    await tester.pumpAndSettle();

    // Pilih Dus di kolom Qty.
    await tester.tap(find.text('Pcs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dus').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Dus = 50 Pcs'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Harga / Dus'), findsOneWidget);

    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final it = state.pembelian.single.items.single;
    expect(it.satuan, 'Dus');
    expect(it.isi, 50);
    expect(it.harga, (hargaPcs * 50).roundToDouble());
    expect(b.stok, awal + 50);
  });

  testWidgets('Gagal simpan ke Supabase tampil sebagai peringatan', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    final auth = DemoAuthService(state, jeda: Duration.zero);
    await auth.login(DemoAuthService.emailDemo, DemoAuthService.passwordDemo);
    await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
    await tester.pumpAndSettle();

    state
      ..errorSinkron = 'Perubahan terakhir gagal disimpan ke Supabase: kolom isi_dus tidak ada'
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('gagal disimpan ke Supabase'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gagal disimpan ke Supabase'), findsNothing);
  });

  testWidgets('Stok bisa diubah dari tombol pensil dan tercatat di mutasi', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    final auth = DemoAuthService(state, jeda: Duration.zero);
    await auth.login(DemoAuthService.emailDemo, DemoAuthService.passwordDemo);
    await tester.pumpWidget(SinarSehatiApp(state: state, auth: auth));
    await tester.pumpAndSettle();

    tester.widget<ShellNav>(find.byType(ShellNav)).buka('Stok Barang');
    await tester.pumpAndSettle();
    final b = state.barang.reduce((a, c) => a.kode.compareTo(c.kode) <= 0 ? a : c);
    final awal = b.stok;
    await tester.ensureVisible(find.byTooltip('Ubah data barang').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ubah data barang').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Stok'), '${awal + 36}');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(state.cariBarang(b.kode)!.stok, awal + 36);
    expect(state.mutasi.first.perubahan, 36);
    expect(state.mutasi.first.keterangan, 'Ubah data barang');
  });
}
