import 'dart:math';
import 'package:flutter/material.dart';
import 'package:temanu/theme.dart';

class HeartRateChartPainter extends CustomPainter {
  final List<DateTime> timeData;
  final List<int> minBpmData;
  final List<int> maxBpmData;
  final String rangeLabel;
  final int? touchedIndex;
  final int dateOffset;
  final double progress;

  HeartRateChartPainter({
    required this.timeData,
    required this.minBpmData,
    required this.maxBpmData,
    required this.rangeLabel,
    this.touchedIndex,
    required this.dateOffset,
    required this.progress
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hrPaint = Paint()..color = AppTheme.primaryColor..style = PaintingStyle.fill;
    final hrColumnPaint = Paint()..color = AppTheme.primaryColor.withOpacity(0.3)..strokeWidth = 5..strokeCap = StrokeCap.round;
    final gridPaint = Paint()..color = AppTheme.textSecondary.withOpacity(0.5)..strokeWidth = 1;
    const textStyle = TextStyle(color: AppTheme.textPrimary, fontSize: 11);

    // --- Y-AXIS CALCULATION ---
    final allValues = [...minBpmData, ...maxBpmData];
    final minVal = allValues.isEmpty ? 40.0 : ((allValues.reduce(min) - 10) ~/ 10) * 10.0;
    final maxVal = allValues.isEmpty ? 150.0 : (((allValues.reduce(max) + 9) ~/ 10) * 10).toDouble();
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

    // --- TIME BOUNDS ---
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
    final pointCount = min(timeData.length, minBpmData.length);
    const double dotRadius = 3.5; 
    
    for (int i = 0; i < pointCount; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);

      final targetMinY = chartHeight - ((minBpmData[i] - minVal) / range) * chartHeight;
      final targetMaxY = chartHeight - ((maxBpmData[i] - minVal) / range) * chartHeight;

      final minY = chartHeight - ((chartHeight - targetMinY) * progress);
      final maxY = chartHeight - ((chartHeight - targetMaxY) * progress);
      
      if (minBpmData[i] != maxBpmData[i]) {
        canvas.drawLine(Offset(x, minY), Offset(x, maxY), hrColumnPaint);
        canvas.drawCircle(Offset(x, minY), dotRadius, hrPaint);
        canvas.drawCircle(Offset(x, maxY), dotRadius, hrPaint);
      } else {
        canvas.drawCircle(Offset(x, minY), dotRadius, hrPaint); 
      }

      // Highlight rings for touched point — drawn on top of dots
      if (touchedIndex == i) {
        canvas.drawCircle(Offset(x, maxY), 8, Paint()..color = AppTheme.textPrimary);
        canvas.drawCircle(Offset(x, maxY), 5, Paint()..color = AppTheme.background);
        if (minBpmData[i] != maxBpmData[i]) {
          canvas.drawCircle(Offset(x, minY), 8, Paint()..color = AppTheme.textPrimary);
          canvas.drawCircle(Offset(x, minY), 5, Paint()..color = AppTheme.background);
        }
      }
    }

    // --- DRAW TOOLTIP (drawn last so it sits above everything) ---
    if (touchedIndex != null && touchedIndex! < pointCount) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);

      final bMin = minBpmData[touchedIndex!];
      final bMax = maxBpmData[touchedIndex!];
      final highestY = chartHeight - ((bMax - minVal) / range) * chartHeight;

      _drawTooltip(canvas, size, x, highestY, bMin, bMax, timeData[touchedIndex!]);
    }
  }

  // --- UPDATED: Dark box tooltip matching body weight style (date row 1, value row 2) ---
  void _drawTooltip(Canvas canvas, Size size, double x, double highestY, int bMin, int bMax, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    // Row 1: date/timeframe
    String dateStr;
    if (rangeLabel == "D") {
      String period = date.hour >= 12 ? "PM" : "AM";
      int h = date.hour % 12;
      if (h == 0) h = 12;
      dateStr = "${date.day} ${months[date.month - 1]}, $h:00 $period";
    } else if (rangeLabel == "W" || rangeLabel == "M") {
      dateStr = "${date.day} ${months[date.month - 1]}";
    } else if (rangeLabel == "3M" || rangeLabel == "6M") {
      final weekEnd = date.add(const Duration(days: 6));
      dateStr = "${date.day} ${months[date.month - 1]} - ${weekEnd.day} ${months[weekEnd.month - 1]}";
    } else {
      dateStr = "${months[date.month - 1]} ${date.year}";
    }

    // Row 2: value — show range if min != max, otherwise single value
    String valueStr = bMin == bMax ? "$bMax bpm" : "$bMin–$bMax bpm";

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: "$dateStr\n",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: valueStr,
          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final boxWidth = textPainter.width + 24;
    final boxHeight = textPainter.height + 16;

    double rectLeft = (x - boxWidth / 2).clamp(55.0, size.width - boxWidth);
    double rectTop = highestY - boxHeight - 15;
    if (rectTop < 0) rectTop = highestY + 15;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rectLeft, rectTop, boxWidth, boxHeight),
      const Radius.circular(8),
    );

    // Shadow
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26);
    // Dark box
    canvas.drawRRect(rrect, Paint()..color = AppTheme.background);
    // Text
    textPainter.paint(canvas, Offset(rectLeft + 12, rectTop + 8));
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