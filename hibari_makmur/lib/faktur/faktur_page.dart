import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../auth/auth_service.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import 'faktur_pdf.dart';

/// Membuka pratinjau faktur untuk transaksi [t].
void bukaFaktur(BuildContext context, Transaksi t, {required bool penjualan}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FakturPage(transaksi: t, penjualan: penjualan)),
  );
}

/// Data faktur [t] dengan profil toko, pengaturan faktur, dan nama pencetak.
DataFaktur dataFaktur(BuildContext context, Transaksi t, {required bool penjualan}) {
  final s = AppScope.read(context);
  return DataFaktur(
    transaksi: t,
    penjualan: penjualan,
    profil: s.profil,
    pengaturan: s.faktur,
    kontak: s.cariKontak(!penjualan, t.pihak),
    dicetakOleh: AuthScope.read(context).user?.nama ?? '',
  );
}

/// Langsung membuka dialog cetak (tanpa halaman pratinjau) memakai
/// pengaturan faktur yang tersimpan.
Future<void> cetakFaktur(BuildContext context, Transaksi t, {required bool penjualan}) {
  final data = dataFaktur(context, t, penjualan: penjualan);
  return Printing.layoutPdf(
    name: 'Faktur-${t.kode}',
    format: formatKertas(data.pengaturan.ukuran),
    onLayout: (_) => buatFakturPdf(data),
  );
}

/// Pratinjau faktur + panel pengaturan tampilan di sebelahnya.
/// Perubahan pengaturan langsung terlihat dan disimpan untuk faktur berikutnya.
class FakturPage extends StatelessWidget {
  const FakturPage({super.key, required this.transaksi, required this.penjualan});

  final Transaksi transaksi;
  final bool penjualan;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cfg = s.faktur;
    final data = DataFaktur(
      transaksi: transaksi,
      penjualan: penjualan,
      profil: s.profil,
      pengaturan: cfg,
      kontak: s.cariKontak(!penjualan, transaksi.pihak),
      dicetakOleh: AuthScope.of(context).user?.nama ?? '',
    );
    // Kunci berubah setiap pengaturan berubah supaya pratinjau digambar ulang.
    final kunci = [
      cfg.ukuran, cfg.judulPenjualan, cfg.judulPembelian, cfg.catatanKaki, //
      cfg.tampilkanLogo, cfg.tampilkanTandaTangan, cfg.tampilkanTerbilang, s.profil.nama, //
      cfg.hitamPutih, cfg.rangkap, ...cfg.labelLembar,
    ].join('|');

    final preview = PdfPreview(
      key: ValueKey(kunci),
      build: (_) => buatFakturPdf(data),
      initialPageFormat: formatKertas(cfg.ukuran),
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      pdfFileName: 'Faktur-${transaksi.kode}.pdf',
      previewPageMargin: const EdgeInsets.all(12),
      loadingWidget: const CircularProgressIndicator(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        foregroundColor: Colors.white,
        title: Text('Faktur ${transaksi.kode}'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 330,
              child: Material(color: Colors.white, child: PengaturanFakturPanel(state: s)),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: preview),
          ]);
        }
        return Stack(children: [
          preview,
          Positioned(
            left: 16,
            top: 16,
            child: FloatingActionButton.extended(
              heroTag: 'atur-faktur',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand,
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AppScope(
                  state: s,
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.75,
                    child: PengaturanFakturPanel(state: s),
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('Atur Faktur'),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Form pengaturan faktur. Dipakai di halaman pratinjau dan menu Pengaturan.
class PengaturanFakturPanel extends StatefulWidget {
  const PengaturanFakturPanel({super.key, required this.state, this.scroll = true});

  final AppState state;
  final bool scroll;

  @override
  State<PengaturanFakturPanel> createState() => _PengaturanFakturPanelState();
}

class _PengaturanFakturPanelState extends State<PengaturanFakturPanel> {
  late final cfg = widget.state.faktur;
  late final _judulJual = TextEditingController(text: cfg.judulPenjualan);
  late final _judulBeli = TextEditingController(text: cfg.judulPembelian);
  late final _catatan = TextEditingController(text: cfg.catatanKaki);
  late final _label = [for (final l in cfg.labelLembar) TextEditingController(text: l)];

  @override
  void dispose() {
    _judulJual.dispose();
    _judulBeli.dispose();
    _catatan.dispose();
    for (final c in _label) {
      c.dispose();
    }
    super.dispose();
  }

  void _ubah(void Function(PengaturanFaktur f) f) {
    setState(() => f(cfg));
    widget.state.simpanFaktur(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final isi = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Ukuran Kertas', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final u in PengaturanFaktur.ukuranList)
            ChoiceChip(
              label: Text(u),
              selected: cfg.ukuran == u,
              onSelected: (_) => _ubah((f) => f.ukuran = u),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          switch (cfg.ukuran) {
            'A4' => '21 x 29,7 cm — printer biasa (inkjet/laser).',
            'A5' => '14,8 x 21 cm — setengah A4, umum untuk faktur toko.',
            'Continuous Form' => '9,5 x 11 inci — kertas berlubang printer dot matrix (Epson LX).',
            'Continuous 1/2' => '9,5 x 5,5 inci — setengah continuous form, umum untuk faktur rangkap.',
            'Struk 80 mm' => 'Printer thermal kasir lebar 80 mm.',
            _ => 'Printer thermal kecil / bluetooth lebar 58 mm.',
          },
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        const Text('Rangkap', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in PengaturanFaktur.rangkapList)
            ChoiceChip(
              label: Text(r),
              selected: cfg.rangkap == r,
              onSelected: (_) => _ubah((f) {
                f.rangkap = r;
                if (r == 'NCR 3 ply') {
                  // Kertas NCR dipakai di printer dot matrix: hitam-putih & ukuran continuous.
                  f.hitamPutih = true;
                  if (!f.ukuran.startsWith('Continuous')) f.ukuran = 'Continuous 1/2';
                }
              }),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          switch (cfg.rangkap) {
            'NCR 3 ply' => 'Kertas rangkap 3 (putih/merah/kuning) di printer dot matrix: sekali cetak '
                'langsung jadi 3 lembar. Keterangan warna lembar dicetak di bagian bawah.',
            '3 lembar' => 'Untuk printer biasa: faktur dicetak 3 kali, tiap lembar diberi label peruntukannya.',
            _ => 'Cetak satu lembar saja.',
          },
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (cfg.rangkap != 'Tidak') ...[
          const SizedBox(height: 10),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _label[i],
                decoration: InputDecoration(
                  labelText: cfg.rangkap == 'NCR 3 ply'
                      ? 'Lembar ${PengaturanFaktur.warnaNcr[i].toLowerCase()} untuk'
                      : 'Lembar ${i + 1} untuk',
                ),
                onChanged: (v) => _ubah((f) => f.labelLembar[i] = v),
              ),
            ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hitam-putih (dot matrix)'),
          subtitle: const Text('Tanpa warna, arsiran, dan logo agar tembusan rangkap tetap jelas'),
          value: cfg.hitamPutih,
          onChanged: (v) => _ubah((f) => f.hitamPutih = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _judulJual,
          decoration: const InputDecoration(labelText: 'Judul faktur penjualan'),
          onChanged: (v) => _ubah((f) => f.judulPenjualan = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _judulBeli,
          decoration: const InputDecoration(labelText: 'Judul bukti pembelian'),
          onChanged: (v) => _ubah((f) => f.judulPembelian = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _catatan,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Catatan kaki', alignLabelWithHint: true),
          onChanged: (v) => _ubah((f) => f.catatanKaki = v),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tampilkan logo'),
          value: cfg.tampilkanLogo,
          onChanged: (v) => _ubah((f) => f.tampilkanLogo = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tampilkan terbilang'),
          subtitle: const Text('mis. "Satu juta dua ratus ribu rupiah"'),
          value: cfg.tampilkanTerbilang,
          onChanged: (v) => _ubah((f) => f.tampilkanTerbilang = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kolom tanda tangan'),
          subtitle: const Text('Tidak dipakai di ukuran struk'),
          value: cfg.tampilkanTandaTangan,
          onChanged: (v) => _ubah((f) => f.tampilkanTandaTangan = v),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nama, alamat, dan telepon toko diambil dari menu Pengaturan → Profil Toko.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
    if (!widget.scroll) return isi;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.receipt_long, color: AppColors.brand),
          SizedBox(width: 8),
          Text('Atur Tampilan Faktur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        isi,
      ]),
    );
  }
}
