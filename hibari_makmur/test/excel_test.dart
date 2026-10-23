import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hibari_makmur/utils/excel.dart';

void main() {
  test('buatXlsx menghasilkan file xlsx berisi judul, header, dan angka', () {
    final bytes = buatXlsx(
      judul: 'Laba Kotor per Barang',
      subjudul: 'Periode 1 Oktober 2026 – 31 Oktober 2026',
      header: ['Kode', 'Barang', 'Qty', 'Penjualan', 'Margin'],
      rows: [
        ['BRG0052', 'Gergaji Kayu & <Besi>', 66, 4620000.0, 21.4],
        ['BRG0050', 'Palu Kambing', 28, 1260000.0, -2.5],
      ],
      format: const {2: FormatKolom.angka, 3: FormatKolom.rupiah, 4: FormatKolom.persen},
    );
    final arsip = ZipDecoder().decodeBytes(bytes);
    expect(arsip.files.map((f) => f.name),
        containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/styles.xml']));
    final sheet = utf8.decode(arsip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(sheet, contains('Laba Kotor per Barang'));
    expect(sheet, contains('Gergaji Kayu &amp; &lt;Besi&gt;'));
    expect(sheet, contains('<c r="D5" s="5"><v>4620000.0</v></c>'));

    final keluar = Platform.environment['XLSX_OUT'];
    if (keluar != null) File(keluar).writeAsBytesSync(bytes);
  });
}
