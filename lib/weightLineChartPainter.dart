import 'dart:math';
import 'package:flutter/material.dart';

class WeightLineChartPainter extends CustomPainter {
  final List<double> data;
  final String selectedRange;
  final int? touchedIndex;

  WeightLineChartPainter(this.data, this.selectedRange, this.touchedIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xff7EF2FF)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
    );

    final axis = _buildDynamicAxis(data);
    final double minAxis = axis.$1;
    final double maxAxis = axis.$2;
    final double range = maxAxis - minAxis;

    const double leftPadding = 58;
    const double bottomPadding = 24;
    final double chartHeight = size.height - bottomPadding;

    // Draw 5 equal intervals (6 grid lines) dynamically based on the new range
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Calculate the value for this specific grid line
      final value = maxAxis - (range * i / 5);
      final tp = TextPainter(
        text: TextSpan(
          text: "${value.toStringAsFixed(1)}kg", // Using 1 decimal so fractions display neatly
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y - 8));
    }

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x =
          leftPadding + (size.width - leftPadding - 20) * i / (data.length - 1);
      final y =
          chartHeight - ((data[i] - minAxis) / range) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
    canvas.drawPath(path, linePaint);

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

    // Draw Tooltip
    if (touchedIndex != null && touchedIndex! < data.length) {
      final x = leftPadding + (size.width - leftPadding - 20) * touchedIndex! / (data.length - 1);
      final y = chartHeight - ((data[touchedIndex!] - minAxis) / range) * chartHeight;
      
      // Draw highlighted dot
      canvas.drawCircle(Offset(x, y), 8, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = const Color(0xff031447));

      _drawTooltip(canvas, size, x, y, data[touchedIndex!], touchedIndex!);
    }
  }

  (double, double) _buildDynamicAxis(List<double> values) {
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);

    // Subtract 1 from the min and add 1 to the max, rounded to the nearest whole digit
    double minAxis = (minVal - 1).roundToDouble();
    double maxAxis = (maxVal + 1).roundToDouble();

    // Failsafe: Ensure there is always a gap in case all data points are identical
    if (minAxis >= maxAxis) {
      minAxis -= 1;
      maxAxis += 1;
    }

    return (minAxis, maxAxis);
  }

  List<String> _getLabels(String range, int length) {
    final now = DateTime.now();
    const List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    switch (range) {
      case "Week":
        return List.generate(length, (i) {
          final date = now.subtract(Duration(days: length - 1 - i));
          return weekdays[date.weekday - 1];
        });
      case "Month":
        return List.generate(length, (i) {
          if ((i + 1) % 7 == 0) {
            final date = now.subtract(Duration(days: length - 1 - i));
            return "${date.day}/${date.month}";
          }
          return "";
        });
      case "3 Months":
        int lastMonth = -1;
        return List.generate(length, (i) {
          final date = now.subtract(Duration(days: (length - 1 - i) * 7));
          if (date.month != lastMonth) {
            lastMonth = date.month;
            return months[date.month - 1]; 
          }
          return ""; 
        });
      case "6 Months":
        return List.generate(length, (i) {
          int m = now.month - (length - 1 - i);
          while (m <= 0) m += 12; 
          return months[m - 1];
        });
      case "Year":
        return List.generate(length, (i) {
          int m = now.month - (length - 1 - i);
          while (m <= 0) m += 12;
          return months[m - 1];
        });
      default:
        return List.generate(length, (i) => "${i + 1}");
    }
  }

  String _getFullDateLabel(String range, int length, int index) {
    final now = DateTime.now();
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    switch (range) {
      case "Week":
      case "Month":
        final date = now.subtract(Duration(days: length - 1 - index));
        return "${date.day} ${months[date.month - 1]}";
      case "3 Months":
        final date = now.subtract(Duration(days: (length - 1 - index) * 7));
        return "Week of ${date.day} ${months[date.month - 1]}";
      case "6 Months":
      case "Year":
        int m = now.month - (length - 1 - index);
        int y = now.year;
        while (m <= 0) {
          m += 12;
          y -= 1;
        }
        return "${months[m - 1]} $y";
      default:
        return "Day ${index + 1}";
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double y, double value, int index) {
    final dateLabel = _getFullDateLabel(selectedRange, data.length, index);
    final text = "${value.toStringAsFixed(1)} kg\n$dateLabel";

    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(color: Color(0xff031447), fontSize: 13, fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final boxWidth = textPainter.width + 20;
    final boxHeight = textPainter.height + 14;
    
    // Keep tooltip on screen
    double rectLeft = x - boxWidth / 2;
    if (rectLeft < 58) rectLeft = 58;
    if (rectLeft + boxWidth > size.width) rectLeft = size.width - boxWidth;
    
    double rectTop = y - boxHeight - 15;
    if (rectTop < 0) rectTop = y + 15; // Flip below dot if too close to top

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rectLeft, rectTop, boxWidth, boxHeight),
      const Radius.circular(10),
    );

    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26); // Shadow
    canvas.drawRRect(rrect, Paint()..color = Colors.white); // Background
    textPainter.paint(canvas, Offset(rectLeft + 10, rectTop + 7)); // Text
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}