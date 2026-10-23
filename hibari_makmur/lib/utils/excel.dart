import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Format angka per kolom di file Excel.
enum FormatKolom { teks, angka, rupiah, persen }

/// Membuat file .xlsx sederhana (satu sheet): judul, subjudul, lalu tabel
/// dengan header tebal. Angka disimpan sebagai angka asli, jadi masih bisa
/// dijumlah atau diurutkan di Excel.
Uint8List buatXlsx({
  required String judul,
  String subjudul = '',
  required List<String> header,
  required List<List<Object>> rows,
  Map<int, FormatKolom> format = const {},
}) {
  const xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String kolom(int i) {
    var s = '';
    for (var n = i + 1; n > 0; n = (n - 1) ~/ 26) {
      s = String.fromCharCode(65 + (n - 1) % 26) + s;
    }
    return s;
  }

  // Nomor style sesuai urutan cellXfs di styles.xml.
  const sJudul = 1, sHeader = 2, sTeks = 3, sAngka = 4, sRupiah = 5, sPersen = 6, sSub = 7;
  int styleData(int c) => switch (format[c]) {
        FormatKolom.rupiah => sRupiah,
        FormatKolom.angka => sAngka,
        FormatKolom.persen => sPersen,
        _ => sTeks,
      };

  final sheet = StringBuffer();
  void sel(int r, int c, Object v, int style) {
    final ref = '${kolom(c)}$r';
    if (v is num) {
      sheet.write('<c r="$ref" s="$style"><v>${v.isFinite ? v : 0}</v></c>');
    } else {
      sheet.write('<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${esc('$v')}</t></is></c>');
    }
  }

  void baris(int r, void Function() isi) {
    sheet.write('<row r="$r">');
    isi();
    sheet.write('</row>');
  }

  var r = 1;
  baris(r++, () => sel(1, 0, judul, sJudul));
  if (subjudul.isNotEmpty) baris(r++, () => sel(2, 0, subjudul, sSub));
  r++;
  final rHeader = r;
  baris(r++, () {
    for (var c = 0; c < header.length; c++) {
      sel(rHeader, c, header[c], sHeader);
    }
  });
  for (final row in rows) {
    final rr = r++;
    baris(rr, () {
      for (var c = 0; c < row.length; c++) {
        sel(rr, c, row[c], styleData(c));
      }
    });
  }

  // Lebar kolom kira-kira mengikuti isi terpanjang.
  final lebar = <double>[];
  for (var c = 0; c < header.length; c++) {
    var maks = header[c].length;
    for (final row in rows.take(500)) {
      if (c >= row.length) continue;
      final v = row[c];
      final n = v is num ? (format[c] == FormatKolom.rupiah ? 4 : 0) + v.round().toString().length * 4 ~/ 3 : '$v'.length;
      if (n > maks) maks = n;
    }
    lebar.add((maks + 3).clamp(6, 60).toDouble());
  }

  final sheetXml = '$xmlHead<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="$rHeader" topLeftCell="A${rHeader + 1}" '
      'activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
      '<cols>${[for (var c = 0; c < lebar.length; c++) '<col min="${c + 1}" max="${c + 1}" width="${lebar[c]}" customWidth="1"/>'].join()}</cols>'
      '<sheetData>$sheet</sheetData>'
      '${rows.isEmpty ? '' : '<autoFilter ref="A$rHeader:${kolom(header.length - 1)}${r - 1}"/>'}'
      '</worksheet>';

  const styles = '$xmlHead<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="3">'
      '<numFmt numFmtId="164" formatCode="&quot;Rp &quot;#,##0;[Red]&quot;-Rp &quot;#,##0"/>'
      '<numFmt numFmtId="165" formatCode="#,##0"/>'
      '<numFmt numFmtId="166" formatCode="0.0&quot;%&quot;"/>'
      '</numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="14"/><name val="Calibri"/></font>'
      '<font><i/><sz val="10"/><color rgb="FF6B7280"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF156143"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FFD1D5DB"/></left><right style="thin"><color rgb="FFD1D5DB"/></right>'
      '<top style="thin"><color rgb="FFD1D5DB"/></top><bottom style="thin"><color rgb="FFD1D5DB"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="8">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  final arsip = Archive()
    ..addFile(ArchiveFile.string(
        '[Content_Types].xml',
        '$xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '<Override PartName="/xl/styles.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            '</Types>'))
    ..addFile(ArchiveFile.string(
        '_rels/.rels',
        '$xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Target="xl/workbook.xml" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"/>'
            '</Relationships>'))
    ..addFile(ArchiveFile.string(
        'xl/workbook.xml',
        '$xmlHead<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Laporan" sheetId="1" r:id="rId1"/></sheets>'
            '${rows.isEmpty ? '' : '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">'
                'Laporan!\$A\$$rHeader:\$${kolom(header.length - 1)}\$${r - 1}</definedName></definedNames>'}'
            '</workbook>'))
    ..addFile(ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        '$xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Target="worksheets/sheet1.xml" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"/>'
            '<Relationship Id="rId2" Target="styles.xml" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"/>'
            '</Relationships>'))
    ..addFile(ArchiveFile.bytes('xl/worksheets/sheet1.xml', utf8.encode(sheetXml)))
    ..addFile(ArchiveFile.string('xl/styles.xml', styles));
  return ZipEncoder().encodeBytes(arsip);
}
