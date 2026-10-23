import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/faktur/faktur_pdf.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/utils/format.dart';

/// Penjualan contoh dari barang demo (data transaksi bawaan sudah dihapus).
Transaksi contohPenjualan(AppState s) => Transaksi(
      kode: 'PJ00001',
      tanggal: DateTime(2026, 10, 19),
      pihak: s.pelanggan.first.nama,
      status: 'Lunas',
      catatan: 'Contoh',
      items: [
        for (final b in s.barang.take(2))
          ItemTransaksi(
              kodeBarang: b.kode, namaBarang: b.nama, satuan: b.satuan, qty: 3, harga: b.hargaJual,
              hargaPokok: b.hargaBeli),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('terbilang', () {
    expect(terbilang(0), 'nol');
    expect(terbilang(11), 'sebelas');
    expect(terbilang(115), 'seratus lima belas');
    expect(terbilang(1000), 'seribu');
    expect(terbilang(1250000), 'satu juta dua ratus lima puluh ribu');
    expect(terbilang(2011500), 'dua juta sebelas ribu lima ratus');
  });

  test('PDF faktur terbentuk untuk semua ukuran kertas', () async {
    final s = AppState();
    final t = contohPenjualan(s);
    for (final ukuran in PengaturanFaktur.ukuranList) {
      for (final logo in [true, false]) {
        final bytes = await buatFakturPdf(DataFaktur(
          transaksi: t,
          penjualan: true,
          profil: s.profil,
          pengaturan: PengaturanFaktur(ukuran: ukuran, tampilkanLogo: logo),
          kontak: s.cariKontak(false, t.pihak),
          dicetakOleh: 'Administrator',
        ));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: ukuran);
      }
    }
  });

  test('Faktur rangkap: NCR 1 halaman, 3 lembar jadi 3 halaman', () async {
    final s = AppState();
    final t = contohPenjualan(s);
    Future<int> jumlahHalaman(PengaturanFaktur cfg) async {
      final bytes = await buatFakturPdf(DataFaktur(
        transaksi: t,
        penjualan: true,
        profil: s.profil,
        pengaturan: cfg,
      ));
      return RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;
    }

    expect(await jumlahHalaman(PengaturanFaktur(ukuran: 'Continuous 1/2')), 1);
    expect(
        await jumlahHalaman(PengaturanFaktur(ukuran: 'Continuous 1/2', rangkap: 'NCR 3 ply', hitamPutih: true)), 1);
    expect(await jumlahHalaman(PengaturanFaktur(ukuran: 'A5', rangkap: '3 lembar')), 3);
  });
}
