import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/data/app_state.dart';
import 'package:hibari_makmur/faktur/faktur_pdf.dart';
import 'package:hibari_makmur/models/models.dart';
import 'package:hibari_makmur/utils/format.dart';

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
    final t = s.penjualan.last;
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
}
