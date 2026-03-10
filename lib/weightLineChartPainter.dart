import 'dart:math';
import 'package:flutter/material.dart';

class ChartLabel {
  final String text;
  final DateTime time;
  ChartLabel(this.text, this.time);
}

class WeightLineChartPainter extends CustomPainter {
  final List<DateTime> timeData; // <-- Now accepts DateTime
  final List<double> weightData; // <-- Now accepts dynamic weights
  final String selectedRange;
  final int? touchedIndex;
  final double progress;
  final int dateOffset;

  WeightLineChartPainter(this.timeData, this.weightData, this.selectedRange, this.touchedIndex, this.progress, this.dateOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = const Color(0xff7EF2FF)..style = PaintingStyle.fill;
    final gridPaint = Paint()..color = Colors.white54..strokeWidth = 1;
    const textStyle = TextStyle(color: Colors.white, fontSize: 12);

    final axis = _buildDynamicAxis(weightData);
    final minAxis = axis.$1;
    final maxAxis = axis.$2;
    final range = maxAxis - minAxis == 0 ? 1 : maxAxis - minAxis;

    const leftPadding = 58.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;
    final usableWidth = size.width - leftPadding - 20;

    // Grid
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final value = maxAxis - (range * i / 5);
      final tp = TextPainter(text: TextSpan(text: "${value.toStringAsFixed(1)}kg", style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y - 8));
    }

    // Time Bounds
    final now = DateTime.now();
    DateTime startTime;
    DateTime endTime;

    switch (selectedRange) {
      case "D": startTime = DateTime(now.year, now.month, now.day + dateOffset); endTime = startTime.add(const Duration(days: 1)); break;
      case "W": int dToM = now.weekday - 1; startTime = DateTime(now.year, now.month, now.day - dToM + (dateOffset * 7)); endTime = startTime.add(const Duration(days: 7)); break;
      case "M": startTime = DateTime(now.year, now.month + dateOffset, 1); endTime = DateTime(now.year, now.month + dateOffset + 1, 1); break;
      case "3M": startTime = DateTime(now.year, now.month - 2 + (dateOffset * 3), 1); endTime = DateTime(now.year, now.month + 1 + (dateOffset * 3), 1); break;
      case "6M": startTime = DateTime(now.year, now.month - 5 + (dateOffset * 6), 1); endTime = DateTime(now.year, now.month + 1 + (dateOffset * 6), 1); break;
      case "Y": startTime = DateTime(now.year + dateOffset, 1, 1); endTime = DateTime(now.year + dateOffset + 1, 1, 1); break;
      default: startTime = DateTime(now.year, now.month, now.day); endTime = startTime.add(const Duration(days: 1));
    }

    final totalMillis = endTime.difference(startTime).inMilliseconds;

    // Draw Line & Dots Proportionally!
    final path = Path();
    for (int i = 0; i < timeData.length; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      
      final targetY = chartHeight - ((weightData[i] - minAxis) / range) * chartHeight;
      final y = chartHeight - ((chartHeight - targetY) * progress);

      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
    if (timeData.isNotEmpty) canvas.drawPath(path, linePaint);

    // Dynamic Labels
    final labels = _getDynamicLabels(selectedRange, startTime, endTime);
    for (var label in labels) {
      final elapsedMillis = label.time.difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);
      final tp = TextPainter(text: TextSpan(text: label.text, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // Tooltip Highlight
    if (touchedIndex != null && touchedIndex! < timeData.length) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      final y = chartHeight - ((weightData[touchedIndex!] - minAxis) / range) * chartHeight;
      
      canvas.drawCircle(Offset(x, y), 8, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = const Color(0xff031447));
      _drawTooltip(canvas, size, x, y, weightData[touchedIndex!], timeData[touchedIndex!]);
    }
  }

  (double, double) _buildDynamicAxis(List<double> values) {
    if (values.isEmpty) return (0.0, 10.0); 
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);
    double minAxis = (minVal - 1).roundToDouble();
    double maxAxis = (maxVal + 1).roundToDouble();
    if (minAxis >= maxAxis) { minAxis -= 1; maxAxis += 1; }
    return (minAxis, maxAxis);
  }

  List<ChartLabel> _getDynamicLabels(String range, DateTime start, DateTime end) {
    const List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    switch (range) {
      case "D": return [ChartLabel("12 AM", start), ChartLabel("12 PM", start.add(const Duration(hours: 12))), ChartLabel("12 AM", start.add(const Duration(hours: 24)))];
      case "W": return List.generate(7, (i) { DateTime t = start.add(Duration(days: i)); return ChartLabel(weekdays[t.weekday - 1], t); });
      case "M": int daysInMonth = end.difference(start).inDays; return List.generate(5, (i) { DateTime t = start.add(Duration(days: (i * (daysInMonth - 1) / 4).round())); return ChartLabel("${t.day}/${t.month}", t); });
      case "3M": return List.generate(3, (i) { DateTime t = DateTime(start.year, start.month + i, 1); return ChartLabel(months[t.month - 1], t); });
      case "6M": return List.generate(6, (i) { DateTime t = DateTime(start.year, start.month + i, 1); return ChartLabel(months[t.month - 1], t); });
      case "Y": return List.generate(12, (i) { DateTime t = DateTime(start.year, start.month + i, 1); return ChartLabel(months[t.month - 1], t); });
      default: return [];
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double y, double value, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    String dateStr;
    if (selectedRange == "D") {
      String period = date.hour >= 12 ? "PM" : "AM";
      int h = date.hour % 12; if (h == 0) h = 12;
      dateStr = "${date.day} ${months[date.month - 1]}, $h:00 $period"; 
    } else if (selectedRange == "W" || selectedRange == "M") {
      dateStr = "${date.day} ${months[date.month - 1]}"; 
    } else if (selectedRange == "3M" || selectedRange == "6M") {
      final weekEnd = date.add(const Duration(days: 6));
      dateStr = "${date.day} ${months[date.month - 1]} - ${weekEnd.day} ${months[weekEnd.month - 1]}";
    } else {
      dateStr = "${months[date.month - 1]} ${date.year}"; 
    }

    final textSpan = TextSpan(text: "${value.toStringAsFixed(1)} kg\n$dateStr", style: const TextStyle(color: Color(0xff031447), fontSize: 13, fontWeight: FontWeight.bold));
    final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();

    final boxWidth = textPainter.width + 20;
    final boxHeight = textPainter.height + 14;
    double rectLeft = (x - boxWidth / 2).clamp(58.0, size.width - boxWidth);
    double rectTop = y - boxHeight - 15;
    if (rectTop < 0) rectTop = y + 15;

    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(rectLeft, rectTop, boxWidth, boxHeight), const Radius.circular(10));
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26); 
    canvas.drawRRect(rrect, Paint()..color = Colors.white); 
    textPainter.paint(canvas, Offset(rectLeft + 10, rectTop + 7)); 
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}