import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Grafik batang berkelompok (mis. penjualan vs pembelian per bulan).
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.colors,
    this.height = 240,
  });

  final List<String> labels;
  final List<List<double>> series;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarPainter(labels, series, colors),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.labels, this.series, this.colors);

  final List<String> labels;
  final List<List<double>> series;
  final List<Color> colors;

  static double _nice(double raw) {
    if (raw <= 0) return 1000000;
    final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
    final f = raw / exp;
    final nf = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
    return nf * exp;
  }

  static String _juta(double v) {
    if (v == 0) return '0';
    final j = v / 1000000;
    if (j >= 1) return '${j == j.roundToDouble() ? j.toInt() : j.toStringAsFixed(1)} jt';
    return '${(v / 1000).round()} rb';
  }

  void _text(Canvas c, String s, Offset at, {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, bottom = 26.0, top = 8.0;
    final h = size.height - bottom - top;
    final w = size.width - left;
    final maks = series.expand((e) => e).fold<double>(0, max);
    final step = _nice(maks / 4);
    final axis = step * 4;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + h - h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, _juta(step * i), Offset(left - 8, y), align: TextAlign.right);
    }

    final n = labels.length;
    final groupW = w / n;
    final barW = min(16.0, groupW * 0.7 / series.length);
    for (var m = 0; m < n; m++) {
      final cx = left + groupW * (m + 0.5);
      final startX = cx - barW * series.length / 2 - (series.length - 1);
      for (var s = 0; s < series.length; s++) {
        final v = series[s][m];
        final bh = axis == 0 ? 0.0 : h * v / axis;
        final x = startX + s * (barW + 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, top + h - bh, barW, bh),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          Paint()..color = colors[s],
        );
      }
      _text(canvas, labels[m], Offset(cx, size.height - bottom / 2 + 2));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.series != series;
}

/// Grafik donat dengan teks di tengah.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.center,
    this.size = 190,
  });

  final List<double> values;
  final List<Color> colors;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _DonutPainter(values, colors)),
          center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    const stroke = 38.0;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * pi, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = AppColors.border);
      return;
    }
    var start = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * pi * values[i] / total;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        max(0, sweep - 0.02),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values;
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text))),
      ],
    );
  }
}
