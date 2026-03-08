import 'dart:math';
import 'package:flutter/material.dart';

class BloodPressureChartPainter extends CustomPainter {
  final List<int> sysData;
  final List<int> diaData;
  final List<int>? sysMinData;
  final List<int>? sysMaxData;
  final List<int>? diaMinData;
  final List<int>? diaMaxData;
  final String rangeLabel;

  BloodPressureChartPainter({
    required this.sysData,
    required this.diaData,
    required this.rangeLabel,
    this.sysMinData,
    this.sysMaxData,
    this.diaMinData,
    this.diaMaxData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sysPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final diaPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final rangePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 2;

    final gridPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;

    const textStyle = TextStyle(color: Colors.white, fontSize: 11);

    final allValues = [...sysData, ...diaData];
    final minVal = ((allValues.reduce(min) - 10) ~/ 10) * 10;
    final maxVal = (((allValues.reduce(max) + 9) ~/ 10) * 10).toDouble();
    final range = maxVal - minVal == 0 ? 10 : maxVal - minVal;

    const leftPadding = 55.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);

      final value = maxVal - (range * i / 5);
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(8, y - 8));
    }

    final pointCount = min(sysData.length, diaData.length);
    if (pointCount == 0) return;

    final usableWidth = size.width - leftPadding - 20;
    final step = pointCount == 1 ? 0 : usableWidth / (pointCount - 1);

    for (int i = 0; i < pointCount; i++) {
      final x = leftPadding + step * i;

      final sysY = chartHeight - ((sysData[i] - minVal) / range) * chartHeight;
      final diaY = chartHeight - ((diaData[i] - minVal) / range) * chartHeight;

      // Multiple readings range
      if (sysMinData != null &&
          sysMaxData != null &&
          i < sysMinData!.length &&
          i < sysMaxData!.length) {
        final sysMinY =
            chartHeight - ((sysMinData![i] - minVal) / range) * chartHeight;
        final sysMaxY =
            chartHeight - ((sysMaxData![i] - minVal) / range) * chartHeight;
        canvas.drawLine(Offset(x, sysMinY), Offset(x, sysMaxY), rangePaint);
        canvas.drawCircle(Offset(x, sysMinY), 4, rangePaint);
        canvas.drawCircle(Offset(x, sysMaxY), 4, rangePaint);
      }

      if (diaMinData != null &&
          diaMaxData != null &&
          i < diaMinData!.length &&
          i < diaMaxData!.length) {
        final diaMinY =
            chartHeight - ((diaMinData![i] - minVal) / range) * chartHeight;
        final diaMaxY =
            chartHeight - ((diaMaxData![i] - minVal) / range) * chartHeight;
        canvas.drawLine(Offset(x + 6, diaMinY), Offset(x + 6, diaMaxY), rangePaint);
        canvas.drawCircle(Offset(x + 6, diaMinY), 4, rangePaint);
        canvas.drawCircle(Offset(x + 6, diaMaxY), 4, rangePaint);
      }

      // Systolic = orange rectangle
      final sysRect = Rect.fromCenter(center: Offset(x, sysY), width: 12, height: 12);
      canvas.drawRect(sysRect, sysPaint);

      // Diastolic = green dot
      canvas.drawCircle(Offset(x + 6, diaY), 5, diaPaint);
    }

    final labels = _getLabels(rangeLabel, pointCount);
    for (int i = 0; i < min(labels.length, pointCount); i++) {
      final x = leftPadding + step * i;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }
  }

  List<String> _getLabels(String range, int length) {
    switch (range) {
      case "Week":
        return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      case "Month":
        return List.generate(length, (i) => "${i + 1}");
      case "3 Months":
        return List.generate(length, (i) => "W${i + 1}");
      case "6 Months":
        return ["M1", "M2", "M3", "M4", "M5", "M6"];
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