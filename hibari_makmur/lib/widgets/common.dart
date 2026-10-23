import 'dart:async';
import 'dart:math';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils/excel.dart';
import '../utils/format.dart';

export '../utils/excel.dart' show FormatKolom;

/// Kartu putih dasar.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEA)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x050F172A), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/// Kartu dengan judul (dan ikon / aksi opsional).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconColor = AppColors.green,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap: kalau judul dan aksi (tombol/legenda) tidak muat sebaris di
          // layar sempit, aksi turun ke baris berikutnya.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: iconColor, size: 19),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_rounded, size: 15),
      ]),
    );
  }
}

/// Judul halaman + tombol aksi.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
              ],
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Label status berwarna (Lunas, Piutang, Menipis, dst).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'Lunas' || 'Aman' || 'Aktif' => (const Color(0xFFD9F5E3), const Color(0xFF167A43)),
      'Piutang' || 'Hutang' => (const Color(0xFFFFF0B8), const Color(0xFF8A6100)),
      'Menipis' => (const Color(0xFFFFE4CC), const Color(0xFFB45309)),
      'Habis' => (const Color(0xFFFDE2E2), const Color(0xFFB91C1C)),
      _ => (const Color(0xFFE5E7EB), const Color(0xFF4B5563)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Kotak ringkasan angka kecil.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.green,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.2)),
                if (note != null)
                  Text(note!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid yang menyesuaikan jumlah kolom dengan lebar layar.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var cols = max(1, ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor());
      cols = min(cols, children.length);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Dua kolom berdampingan di layar lebar, bertumpuk di layar sempit.
class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.breakpoint = 1000,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 16), right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 16),
          Expanded(flex: rightFlex, child: right),
        ],
      );
    });
  }
}

DataColumn kol(String label, {bool angka = false}) =>
    DataColumn(label: Text(label), numeric: angka);

DataCell sel(String text, {Color? color, bool bold = false}) => DataCell(Text(
      text,
      style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : null),
    ));

/// Sel untuk teks panjang (mis. nama barang): dibatasi lebarnya dan turun
/// ke baris kedua; kalau masih kepanjangan dipotong "…" dan teks lengkap
/// muncul saat kursor diarahkan.
DataCell selPanjang(String text, {double lebar = 340, int maxBaris = 2}) => DataCell(
      Tooltip(
        message: text,
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox(
          width: lebar,
          child: Text(text, maxLines: maxBaris, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

/// Tabel sederhana dengan scroll horizontal dan paginasi opsional.
class SimpleTable extends StatefulWidget {
  SimpleTable({
    super.key,
    required this.columns,
    required List<DataRow> rows,
    this.perPage = 0,
    this.emptyText = 'Belum ada data',
  })  : jumlah = rows.length,
        baris = ((i) => rows[i]);

  /// Untuk data besar: baris dibuat hanya untuk halaman yang sedang tampil,
  /// jadi ribuan barang tidak dibangun sekaligus setiap kali layar berubah.
  const SimpleTable.builder({
    super.key,
    required this.columns,
    required this.jumlah,
    required this.baris,
    this.perPage = 0,
    this.emptyText = 'Belum ada data',
  });

  final List<DataColumn> columns;
  final int jumlah;
  final DataRow Function(int i) baris;

  /// 0 = tanpa paginasi.
  final int perPage;
  final String emptyText;

  @override
  State<SimpleTable> createState() => _SimpleTableState();
}

class _SimpleTableState extends State<SimpleTable> {
  int page = 0;
  final _geser = ScrollController();

  @override
  void dispose() {
    _geser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.jumlah;
    final paged = widget.perPage > 0 && total > widget.perPage;
    final pages = paged ? (total / widget.perPage).ceil() : 1;
    final p = min(page, pages - 1);
    final dari = paged ? p * widget.perPage : 0;
    final sampai = paged ? min(total, dari + widget.perPage) : total;
    final rows = [for (var i = dari; i < sampai; i++) widget.baris(i)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          // Scrollbar terlihat kalau tabel lebih lebar dari layar; ruang kecil
          // di kanan supaya efek hover tombol di kolom terakhir tidak terpotong.
          return Scrollbar(
            controller: _geser,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _geser,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8, bottom: 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth - 8),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDF0EE)),
                  ),
                  child: DataTable(columns: widget.columns, rows: rows),
                ),
              ),
            ),
          );
        }),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                child: const Icon(Icons.inbox_outlined, color: Color(0xFF9CA3AF), size: 26),
              ),
              const SizedBox(height: 10),
              Text(widget.emptyText,
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
        if (paged)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${p * widget.perPage + 1}–${min(total, (p + 1) * widget.perPage)} dari $total',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                IconButton(
                  tooltip: 'Sebelumnya',
                  onPressed: p > 0 ? () => setState(() => page = p - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Berikutnya',
                  onPressed: p < pages - 1 ? () => setState(() => page = p + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kotak pencarian. [onChanged] dipanggil setelah pengguna berhenti mengetik
/// sebentar, supaya daftar besar tidak difilter ulang di setiap huruf.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onChanged, this.hint = 'Cari...', this.width = 280});

  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  Timer? _tunda;

  @override
  void dispose() {
    _tunda?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return SizedBox(
      width: widget.width,
      child: TextField(
        onChanged: (v) {
          _tunda?.cancel();
          _tunda = Timer(const Duration(milliseconds: 250), () => widget.onChanged(v));
        },
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
        ),
      ),
    );
  }
}

/// Dropdown kecil untuk filter.
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 200,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        items: [
          for (final i in items)
            DropdownMenuItem(value: i, child: Text(i, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}

/// Pemilih rentang tanggal dengan tombol preset.
class RentangTanggalBar extends StatelessWidget {
  const RentangTanggalBar({super.key, required this.value, required this.onChanged});

  final DateTimeRange value;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final presets = <String, DateTimeRange>{
      'Bulan Ini': rentangBulan(now.year, now.month),
      'Bulan Lalu': rentangBulan(now.year, now.month - 1),
      '3 Bulan': DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1), end: DateTime(now.year, now.month + 1, 0)),
      'Tahun Ini': rentangTahun(now.year),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range, size: 18),
          label: Text('${tgl(value.start)}  s/d  ${tgl(value.end)}'),
          onPressed: () async {
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 5),
              initialDateRange: value,
            );
            if (r != null) onChanged(r);
          },
        ),
        for (final e in presets.entries)
          ChoiceChip(
            label: Text(e.key),
            selected: DateUtils.isSameDay(e.value.start, value.start) &&
                DateUtils.isSameDay(e.value.end, value.end),
            onSelected: (_) => onChanged(e.value),
          ),
      ],
    );
  }
}

/// Field tanggal yang membuka date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(DateTime.now().year + 5),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(tgl(value)),
      ),
    );
  }
}

/// Input khusus angka (hanya digit).
List<TextInputFormatter> get hanyaAngka => [FilteringTextInputFormatter.digitsOnly];

Future<bool> konfirmasi(BuildContext context, String pesan, {String tombol = 'Hapus'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.help_outline_rounded, color: AppColors.red, size: 32),
      title: const Text('Konfirmasi'),
      content: Text(pesan, textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tombol),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void toast(BuildContext context, String pesan, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(pesan)),
      ]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : const Color(0xFF1F2937),
      width: 420,
    ));
}

/// Kerangka dialog form dengan judul, isi scrollable, dan tombol Simpan.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.maxWidth = 560,
    this.error,
    this.footer,
    this.menyimpan = false,
    this.labelSimpan = 'Simpan',
    this.ikonSimpan = Icons.save_outlined,
  });

  final String labelSimpan;
  final IconData ikonSimpan;

  final String title;
  final Widget child;
  final VoidCallback onSave;

  /// True selama data sedang disimpan; tombol dinonaktifkan.
  final bool menyimpan;
  final double maxWidth;
  final String? error;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      border: Border.all(color: const Color(0xFFF9CACA)),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final tombol = [
                  TextButton(
                      onPressed: menyimpan ? null : () => Navigator.pop(context), child: const Text('Batal')),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: menyimpan ? null : onSave,
                      icon: menyimpan
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(ikonSimpan, size: 18),
                      label: Text(menyimpan ? 'Menyimpan...' : labelSimpan, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ];
                // Layar sempit: ringkasan (mis. total) di atas, tombol di bawahnya.
                if (c.maxWidth < 480) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (footer != null) ...[footer!, const SizedBox(height: 10)],
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: tombol),
                  ]);
                }
                return Row(children: [
                  if (footer != null) Expanded(child: footer!) else const Spacer(),
                  ...tombol,
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon kecil untuk kolom aksi tabel.
class AksiButton extends StatelessWidget {
  const AksiButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.muted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: color,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

/// Tombol "Unduh Excel" di kepala halaman laporan.
class UnduhExcelButton extends StatelessWidget {
  const UnduhExcelButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Unduh Excel'),
        onPressed: onPressed,
      );
}

/// Membuat file .xlsx lalu mengunduhnya (web) atau menyimpannya (Android).
Future<void> unduhExcel(
  BuildContext context, {
  required String namaFile,
  required String judul,
  String subjudul = '',
  required List<String> header,
  required List<List<Object>> rows,
  Map<int, FormatKolom> format = const {},
}) async {
  try {
    final bytes = buatXlsx(judul: judul, subjudul: subjudul, header: header, rows: rows, format: format);
    final nama = namaFile.replaceAll(RegExp(r'[\/:*?"<>|]'), '-');
    final lokasi = await FileSaver.instance.saveFile(
      name: nama,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
    if (context.mounted) {
      toast(context, kIsWeb ? 'File $nama.xlsx diunduh.' : 'File tersimpan di $lokasi');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Gagal membuat file Excel: $e', error: true);
  }
}

/// Kolom teks dengan saran yang muncul saat mengetik; isian bebas tetap boleh.
/// Isinya bisa diubah dari luar lewat [controller] (mis. diisi otomatis).
class SaranField extends StatefulWidget {
  const SaranField({
    super.key,
    required this.controller,
    required this.saran,
    required this.label,
    this.hint,
    this.icon,
  });

  final TextEditingController controller;
  final Iterable<String> Function() saran;
  final String label;
  final String? hint;
  final IconData? icon;

  @override
  State<SaranField> createState() => _SaranFieldState();
}

class _SaranFieldState extends State<SaranField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        return widget.saran().where((d) => d.toLowerCase().contains(q)).take(20);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        onSubmitted: (_) => onSubmit(),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          suffixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options) ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
