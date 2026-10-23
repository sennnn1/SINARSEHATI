import 'package:flutter/material.dart';

const namaBulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const bulanPendek = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const namaHari = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

/// 12450000 -> "12.450.000"
String angka(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// 12450000 -> "Rp 12.450.000"
String rupiah(num v) => v < 0 ? '-Rp ${angka(-v)}' : 'Rp ${angka(v)}';

/// 5 -> "5%", 2.5 -> "2,5%"
String persen(num v) {
  if (v == v.roundToDouble()) return '${v.round()}%';
  final s = v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  return '${s.replaceAll('.', ',')}%';
}

/// "12.450.000" / "12450000" -> 12450000
double parseAngka(String s) =>
    double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0;

String _dua(int n) => n.toString().padLeft(2, '0');

/// 11-10-2026
String tgl(DateTime d) => '${_dua(d.day)}-${_dua(d.month)}-${d.year}';

/// Rabu, 11 Okt 2026
String tglPanjang(DateTime d) =>
    '${namaHari[d.weekday - 1]}, ${d.day} ${bulanPendek[d.month - 1]} ${d.year}';

/// 11 Oktober 2026
String tglBulan(DateTime d) => '${d.day} ${namaBulan[d.month - 1]} ${d.year}';

DateTimeRange rentangBulan(int tahun, int bulan) =>
    DateTimeRange(start: DateTime(tahun, bulan, 1), end: DateTime(tahun, bulan + 1, 0));

DateTimeRange rentangTahun(int tahun) =>
    DateTimeRange(start: DateTime(tahun, 1, 1), end: DateTime(tahun, 12, 31));

bool dalamRentang(DateTime d, DateTimeRange r) {
  final awal = DateUtils.dateOnly(r.start);
  final akhir = DateUtils.dateOnly(r.end).add(const Duration(days: 1));
  return !d.isBefore(awal) && d.isBefore(akhir);
}

/// Persentase perubahan; null kalau pembanding nol.
double? persenPerubahan(double sekarang, double sebelumnya) =>
    sebelumnya == 0 ? null : (sekarang - sebelumnya) / sebelumnya * 100;

/// 1250000 -> "satu juta dua ratus lima puluh ribu"
String terbilang(num nilai) {
  const satuan = [
    '', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', //
    'tujuh', 'delapan', 'sembilan', 'sepuluh', 'sebelas',
  ];
  String t(int n) {
    if (n < 12) return satuan[n];
    if (n < 20) return '${t(n - 10)} belas';
    if (n < 100) return '${t(n ~/ 10)} puluh ${t(n % 10)}';
    if (n < 200) return 'seratus ${t(n - 100)}';
    if (n < 1000) return '${t(n ~/ 100)} ratus ${t(n % 100)}';
    if (n < 2000) return 'seribu ${t(n - 1000)}';
    if (n < 1000000) return '${t(n ~/ 1000)} ribu ${t(n % 1000)}';
    if (n < 1000000000) return '${t(n ~/ 1000000)} juta ${t(n % 1000000)}';
    return '${t(n ~/ 1000000000)} miliar ${t(n % 1000000000)}';
  }

  final n = nilai.round().abs();
  if (n == 0) return 'nol';
  return t(n).replaceAll(RegExp(r'\s+'), ' ').trim();
}
