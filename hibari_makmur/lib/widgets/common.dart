import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils/format.dart';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 26),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
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
    return InkWell(
      onTap: onTap,
      child: Text(text,
          style: const TextStyle(
              color: AppColors.link, decoration: TextDecoration.underline, fontSize: 13.5)),
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
      padding: const EdgeInsets.only(bottom: 16),
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
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
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

/// Tabel sederhana dengan scroll horizontal dan paginasi opsional.
class SimpleTable extends StatefulWidget {
  const SimpleTable({
    super.key,
    required this.columns,
    required this.rows,
    this.perPage = 0,
    this.emptyText = 'Belum ada data',
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  /// 0 = tanpa paginasi.
  final int perPage;
  final String emptyText;

  @override
  State<SimpleTable> createState() => _SimpleTableState();
}

class _SimpleTableState extends State<SimpleTable> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.rows.length;
    final paged = widget.perPage > 0 && total > widget.perPage;
    final pages = paged ? (total / widget.perPage).ceil() : 1;
    final p = min(page, pages - 1);
    final rows = paged
        ? widget.rows.sublist(p * widget.perPage, min(total, (p + 1) * widget.perPage))
        : widget.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(columns: widget.columns, rows: rows),
            ),
          );
        }),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
                child: Text(widget.emptyText, style: const TextStyle(color: AppColors.muted))),
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

class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.onChanged, this.hint = 'Cari...', this.width = 280});

  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
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
      title: const Text('Konfirmasi'),
      content: Text(pesan),
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
      content: Text(pesan),
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
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(child: SingleChildScrollView(child: child)),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFDE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (footer != null) Expanded(child: footer!) else const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ],
              ),
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

/// Menyalin teks CSV ke clipboard.
Future<void> salinCsv(BuildContext context, List<String> header, List<List<Object>> rows) async {
  String esc(Object v) {
    final s = v.toString();
    return s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final buf = StringBuffer()..writeln(header.map(esc).join(','));
  for (final r in rows) {
    buf.writeln(r.map(esc).join(','));
  }
  await Clipboard.setData(ClipboardData(text: buf.toString()));
  if (context.mounted) toast(context, 'Data CSV disalin ke clipboard — tempel di Excel.');
}
