import 'dart:math';

import 'package:flutter/material.dart';

class WeightBarChartPainter extends CustomPainter {
  final List<double> data;
  final String selectedRange;

  WeightBarChartPainter(this.data, this.selectedRange);

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = const Color(0xff7EF2FF);

    final gridPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
    );

    final axis = _buildFixed10kgAxis(data);
    final double minAxis = axis.$1;
    final double maxAxis = axis.$2;
    final double range = maxAxis - minAxis;

    const double leftPadding = 58;
    const double bottomPadding = 24;
    final double chartHeight = size.height - bottomPadding;

    // 固定每格10kg，共6条线
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );

      final value = maxAxis - i * 10;
      final tp = TextPainter(
        text: TextSpan(
          text: "${value.toStringAsFixed(0)}kg",
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y - 8));
    }

    final usableWidth = size.width - leftPadding - 20;
    final step = usableWidth / data.length;
    final barWidth = step * 0.55;

    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + step * i + (step - barWidth) / 2;
      final barHeight = ((data[i] - minAxis) / range) * chartHeight;
      final y = chartHeight - barHeight;

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        barPaint,
      );
    }

    final labels = _getLabels(selectedRange, data.length);

    for (int i = 0; i < min(labels.length, data.length); i++) {
      final x =
          leftPadding + (size.width - leftPadding - 20) * i / (data.length - 1);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - 12, size.height - 18));
    }
  }

  (double, double) _buildFixed10kgAxis(List<double> values) {
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);

    double minAxis = (minVal / 10).floor() * 10;
    double maxAxis = minAxis + 50;

    while (maxAxis < maxVal) {
      maxAxis += 10;
    }

    return (minAxis, maxAxis);
  }

  List<String> _getLabels(String range, int length) {
    switch (range) {
      case "Month":
        return List.generate(length, (i) => "${i + 1}");
      case "3 Months":
        return List.generate(length, (i) => "W${i + 1}");
      case "Year":
        return [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
      default:
        return List.generate(length, (i) => "${i + 1}");
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}