import 'dart:math';
import 'package:flutter/material.dart';

class OxygenSaturationChartPainter extends CustomPainter {
  final List<DateTime> timeData;
  final List<int> minSpO2Data;
  final List<int> maxSpO2Data;
  final String rangeLabel;
  final int? touchedIndex;
  final int dateOffset;
  final double progress;

  OxygenSaturationChartPainter({
    required this.timeData,
    required this.minSpO2Data,
    required this.maxSpO2Data,
    required this.rangeLabel,
    this.touchedIndex,
    required this.dateOffset,
    required this.progress
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Crisp Cyan for Oxygen
    final oxyPaint = Paint()..color = const Color(0xff00E5FF)..style = PaintingStyle.fill;
    final oxyColumnPaint = Paint()..color = const Color(0xff00E5FF).withValues(alpha: 0.3)..strokeWidth = 5..strokeCap = StrokeCap.round;
    final gridPaint = Paint()..color = Colors.white54..strokeWidth = 1;
    const textStyle = TextStyle(color: Colors.white, fontSize: 11);

    // --- Y-AXIS CALCULATION (Tailored for SpO2) ---
    final allValues = [...minSpO2Data, ...maxSpO2Data];
    // SpO2 rarely drops below 85% in normal circumstances. 
    // We lock the max at 100% since you can't have more than 100% oxygen saturation.
    final minVal = allValues.isEmpty ? 85.0 : max(0.0, ((allValues.reduce(min) - 2) ~/ 5) * 5.0);
    const maxVal = 100.0;
    final range = maxVal - minVal == 0 ? 5 : maxVal - minVal;

    const leftPadding = 55.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;
    final usableWidth = size.width - leftPadding - 20;

    // Draw grid lines
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final value = maxVal - (range * i / 5);
      final tp = TextPainter(text: TextSpan(text: "${value.toStringAsFixed(0)}%", style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(8, y - 8));
    }

    // --- TIME BOUNDS & LABELS ---
    final now = DateTime.now();
    DateTime startTime;
    DateTime endTime;

    switch (rangeLabel) {
      case "D":
        startTime = DateTime(now.year, now.month, now.day + dateOffset);
        endTime = DateTime(now.year, now.month, now.day + dateOffset + 1);
        break;
      case "W":
        int daysToMonday = now.weekday - 1;
        startTime = DateTime(now.year, now.month, now.day - daysToMonday + (dateOffset * 7));
        endTime = DateTime(now.year, now.month, now.day - daysToMonday + 7 + (dateOffset * 7));
        break;
      case "M":
        startTime = DateTime(now.year, now.month + dateOffset, 1);
        endTime = DateTime(now.year, now.month + dateOffset + 1, 1);
        break;
      case "3M":
        startTime = DateTime(now.year, now.month - 2 + (dateOffset * 3), 1);
        endTime = DateTime(now.year, now.month + 1 + (dateOffset * 3), 1);
        break;
      case "6M":
        startTime = DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
        endTime = DateTime(now.year, now.month + 1 + (dateOffset * 6), 1);
        break;
      case "Y":
        startTime = DateTime(now.year + dateOffset, 1, 1);
        endTime = DateTime(now.year + dateOffset + 1, 1, 1);
        break;
      default:
        startTime = DateTime(now.year, now.month, now.day);
        endTime = startTime.add(const Duration(days: 1));
    }

    final totalMillis = endTime.difference(startTime).inMilliseconds;
    final labels = _getDynamicLabels(rangeLabel, startTime, endTime);
    
    for (var label in labels) {
      final elapsedMillis = label.time.difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      
      final x = leftPadding + (usableWidth * timeRatio);
      
      final tp = TextPainter(text: TextSpan(text: label.text, style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // --- DRAW DATA POINTS ---
    final pointCount = min(timeData.length, minSpO2Data.length);
    const double dotRadius = 3.5; 
    
    for (int i = 0; i < pointCount; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);

      final targetMinY = chartHeight - ((minSpO2Data[i] - minVal) / range) * chartHeight;
      final targetMaxY = chartHeight - ((maxSpO2Data[i] - minVal) / range) * chartHeight;

      final minY = chartHeight - ((chartHeight - targetMinY) * progress);
      final maxY = chartHeight - ((chartHeight - targetMaxY) * progress);
      
      if (minSpO2Data[i] != maxSpO2Data[i]) {
        canvas.drawLine(Offset(x, minY), Offset(x, maxY), oxyColumnPaint);
        canvas.drawCircle(Offset(x, minY), dotRadius, oxyPaint);
        canvas.drawCircle(Offset(x, maxY), dotRadius, oxyPaint);
      } else {
        canvas.drawCircle(Offset(x, minY), dotRadius, oxyPaint); 
      }
    }

    // --- DRAW HIGHLIGHT TOOLTIP ---
    if (touchedIndex != null && touchedIndex! < pointCount) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);

      final sMin = minSpO2Data[touchedIndex!];
      final sMax = maxSpO2Data[touchedIndex!];
      final highestY = chartHeight - ((sMax - minVal) / range) * chartHeight;

      _drawTooltip(canvas, size, x, highestY, chartHeight, sMin, sMax, timeData[touchedIndex!]);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double highestY, double chartHeight, int sMin, int sMax, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    String period = date.hour >= 12 ? "PM" : "AM";
    int h = date.hour % 12;
    if (h == 0) h = 12;
    
    String dateStr;
    if (rangeLabel == "D") {
      dateStr = "${date.day} ${months[date.month - 1]}, $h:00 $period"; 
    } else if (rangeLabel == "W" || rangeLabel == "M") {
      dateStr = "${date.day} ${months[date.month - 1]}"; 
    } else if (rangeLabel == "3M" || rangeLabel == "6M") {
      final weekEnd = date.add(const Duration(days: 6));
      dateStr = "${date.day} ${months[date.month - 1]} - ${weekEnd.day} ${months[weekEnd.month - 1]}";
    } else {
      dateStr = "${months[date.month - 1]} ${date.year}"; 
    }

    String oxyText = sMin == sMax ? "SpO2: $sMax%" : "SpO2: $sMin% - $sMax%";
    String text = "$oxyText\n$dateStr";

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

    canvas.drawLine(
      Offset(x, 0), Offset(x, chartHeight), 
      Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 1.5
    );

    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26); 
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    textPainter.paint(canvas, Offset(rectLeft + 10, rectTop + 7));
  }

  List<ChartLabel> _getDynamicLabels(String range, DateTime start, DateTime end) { 
    const List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const List<String> singleLetterMonths = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
    
    switch (range) {
      case "D": 
        return [
          ChartLabel("12 AM", start), 
          ChartLabel("6 AM", start.add(const Duration(hours: 6))), 
          ChartLabel("12 PM", start.add(const Duration(hours: 12))), 
          ChartLabel("6 PM", start.add(const Duration(hours: 18))), 
          ChartLabel("12 AM", start.add(const Duration(hours: 24)))
        ];
      case "W": 
        return List.generate(7, (i) => ChartLabel(weekdays[start.add(Duration(days: i)).weekday - 1], start.add(Duration(days: i))));
      case "M": 
        int daysInMonth = end.difference(start).inDays; 
        return List.generate(5, (i) { 
          DateTime t = start.add(Duration(days: (i * (daysInMonth - 1) / 4).round())); 
          return ChartLabel("${t.day} ${months[t.month - 1]}", t); 
        });
      case "3M": 
      case "6M": 
        int totalMonths = range == "3M" ? 3 : 6;
        return List.generate(totalMonths, (i) { 
          DateTime t = DateTime(start.year, start.month + i, 1); 
          return ChartLabel(months[t.month - 1], t); 
        });
      case "Y": 
        return List.generate(12, (i) { 
          DateTime t = DateTime(start.year, start.month + i, 1); 
          return ChartLabel(singleLetterMonths[t.month - 1], t); 
        });
      default: 
        return [];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ChartLabel {
  final String text;
  final DateTime time;
  ChartLabel(this.text, this.time);
}