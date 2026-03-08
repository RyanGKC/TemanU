import 'dart:math';
import 'package:flutter/material.dart';

class BloodPressureChartPainter extends CustomPainter {
  final List<DateTime> timeData;
  final List<int> sysMinData;
  final List<int> sysMaxData;
  final List<int> diaMinData;
  final List<int> diaMaxData;
  final String rangeLabel;
  final int? touchedIndex;

  BloodPressureChartPainter({
    required this.timeData,
    required this.sysMinData,
    required this.sysMaxData,
    required this.diaMinData,
    required this.diaMaxData,
    required this.rangeLabel,
    this.touchedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sysPaint = Paint()..color = Colors.orange..style = PaintingStyle.fill;
    final diaPaint = Paint()..color = Colors.greenAccent..style = PaintingStyle.fill;
    final sysColumnPaint = Paint()..color = Colors.orange.withValues(alpha: 0.3)..strokeWidth = 5..strokeCap = StrokeCap.round;
    final diaColumnPaint = Paint()..color = Colors.greenAccent.withValues(alpha: 0.3)..strokeWidth = 5..strokeCap = StrokeCap.round;
    final gridPaint = Paint()..color = Colors.white54..strokeWidth = 1;
    const textStyle = TextStyle(color: Colors.white, fontSize: 11);

    // --- Y-AXIS CALCULATION ---
    final allValues = [...sysMinData, ...sysMaxData, ...diaMinData, ...diaMaxData];
    final minVal = allValues.isEmpty ? 60.0 : ((allValues.reduce(min) - 10) ~/ 10) * 10;
    final maxVal = allValues.isEmpty ? 140.0 : (((allValues.reduce(max) + 9) ~/ 10) * 10).toDouble();
    final range = maxVal - minVal == 0 ? 10 : maxVal - minVal;

    const leftPadding = 55.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;
    final usableWidth = size.width - leftPadding - 20;

    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final value = maxVal - (range * i / 5);
      final tp = TextPainter(text: TextSpan(text: value.toStringAsFixed(0), style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(8, y - 8));
    }

    // --- TIME BOUNDS & LABELS ---
    final now = DateTime.now();
    DateTime startTime;
    DateTime endTime;

    switch (rangeLabel) {
      case "Day": startTime = DateTime(now.year, now.month, now.day); endTime = startTime.add(const Duration(days: 1)); break;
      case "Week": startTime = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)); endTime = DateTime(now.year, now.month, now.day, 23, 59, 59); break;
      case "Month": startTime = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)); endTime = DateTime(now.year, now.month, now.day, 23, 59, 59); break;
      case "3 Months": startTime = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89)); endTime = DateTime(now.year, now.month, now.day, 23, 59, 59); break;
      case "6 Months": startTime = DateTime(now.year, now.month - 5, 1); endTime = DateTime(now.year, now.month + 1, 0, 23, 59, 59); break;
      case "Year": startTime = DateTime(now.year - 1, now.month, 1); endTime = DateTime(now.year, now.month + 1, 0, 23, 59, 59); break;
      default: startTime = DateTime(now.year, now.month, now.day); endTime = startTime.add(const Duration(days: 1));
    }

    final totalMillis = endTime.difference(startTime).inMilliseconds;

    final labels = _getFixedLabels(rangeLabel, startTime, endTime);
    for (int i = 0; i < labels.length; i++) {
      final step = labels.length == 1 ? 0 : usableWidth / (labels.length - 1);
      final x = leftPadding + step * i;
      final tp = TextPainter(text: TextSpan(text: labels[i], style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // --- DRAW DATA POINTS ---
    final pointCount = min(timeData.length, sysMinData.length);
    const double dotRadius = 3.5; 
    
    for (int i = 0; i < pointCount; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);

      // Systolic
      final sysMinY = chartHeight - ((sysMinData[i] - minVal) / range) * chartHeight;
      final sysMaxY = chartHeight - ((sysMaxData[i] - minVal) / range) * chartHeight;
      
      if (sysMinData[i] != sysMaxData[i]) {
        canvas.drawLine(Offset(x, sysMinY), Offset(x, sysMaxY), sysColumnPaint);
        canvas.drawCircle(Offset(x, sysMinY), dotRadius, sysPaint);
        canvas.drawCircle(Offset(x, sysMaxY), dotRadius, sysPaint);
      } else {
        canvas.drawCircle(Offset(x, sysMinY), dotRadius, sysPaint); // Single dot if Min == Max
      }

      // Diastolic
      final diaMinY = chartHeight - ((diaMinData[i] - minVal) / range) * chartHeight;
      final diaMaxY = chartHeight - ((diaMaxData[i] - minVal) / range) * chartHeight;
      
      if (diaMinData[i] != diaMaxData[i]) {
        canvas.drawLine(Offset(x, diaMinY), Offset(x, diaMaxY), diaColumnPaint);
        canvas.drawCircle(Offset(x, diaMinY), dotRadius, diaPaint);
        canvas.drawCircle(Offset(x, diaMaxY), dotRadius, diaPaint);
      } else {
        canvas.drawCircle(Offset(x, diaMinY), dotRadius, diaPaint); // Single dot if Min == Max
      }
    }

    // --- DRAW HIGHLIGHT TOOLTIP ---
    if (touchedIndex != null && touchedIndex! < pointCount) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);

      final sMin = sysMinData[touchedIndex!];
      final sMax = sysMaxData[touchedIndex!];
      final dMin = diaMinData[touchedIndex!];
      final dMax = diaMaxData[touchedIndex!];
      final highestY = chartHeight - ((sMax - minVal) / range) * chartHeight;

      _drawTooltip(canvas, size, x, highestY, chartHeight, sMin, sMax, dMin, dMax, timeData[touchedIndex!]);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double highestY, double chartHeight, int sMin, int sMax, int dMin, int dMax, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    String period = date.hour >= 12 ? "PM" : "AM";
    int h = date.hour % 12;
    if (h == 0) h = 12;
    String m = date.minute.toString().padLeft(2, '0');
    
    // Customize label based on range
    String dateStr;
    if (rangeLabel == "Day") {
      dateStr = "${date.day} ${months[date.month - 1]}, $h:00 $period"; // Show the bucket hour
    } else if (rangeLabel == "Week" || rangeLabel == "Month") {
      dateStr = "${date.day} ${months[date.month - 1]}"; // Show the day
    } else {
      dateStr = "${months[date.month - 1]} ${date.year}"; // Show the month
    }

    String sysText = sMin == sMax ? "SYS: $sMax" : "SYS: $sMin-$sMax";
    String diaText = dMin == dMax ? "DIA: $dMax" : "DIA: $dMin-$dMax";
    String text = "$sysText   $diaText\n$dateStr";

    final textSpan = TextSpan(text: text, style: const TextStyle(color: Color(0xff031447), fontSize: 12, fontWeight: FontWeight.bold));
    final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    textPainter.layout();

    final boxWidth = textPainter.width + 20;
    final boxHeight = textPainter.height + 14;
    
    double rectTop = highestY - boxHeight - 15;
    if (rectTop < 0) rectTop = highestY + 15; 

    double rectLeft = x - boxWidth / 2;
    if (rectLeft < 55) rectLeft = 55;
    if (rectLeft + boxWidth > size.width) rectLeft = size.width - boxWidth;

    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(rectLeft, rectTop, boxWidth, boxHeight), const Radius.circular(10));

    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26); 
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    textPainter.paint(canvas, Offset(rectLeft + 10, rectTop + 7));

    canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), Paint()..color = Colors.white.withOpacity(0.6)..strokeWidth = 1.5);
  }

  List<String> _getFixedLabels(String range, DateTime start, DateTime end) {
    const List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    switch (range) {
      case "Day": return ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"];
      case "Week": return List.generate(7, (i) => weekdays[start.add(Duration(days: i)).weekday - 1]);
      case "Month": return List.generate(5, (i) => "${start.add(Duration(days: (i * 7.25).round())).day}/${start.add(Duration(days: (i * 7.25).round())).month}");
      case "3 Months": return List.generate(4, (i) => months[start.add(Duration(days: i * 30)).month - 1]);
      case "6 Months": return List.generate(6, (i) { int m = start.month + i; while (m > 12) m -= 12; return months[m - 1]; });
      case "Year": return List.generate(6, (i) { int m = start.month + (i * 2); while (m > 12) m -= 12; return months[m - 1]; });
      default: return [];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}