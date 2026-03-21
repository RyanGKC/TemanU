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
  final int dateOffset;
  final double progress;

  BloodPressureChartPainter({
    required this.timeData,
    required this.sysMinData,
    required this.sysMaxData,
    required this.diaMinData,
    required this.diaMaxData,
    required this.rangeLabel,
    this.touchedIndex,
    required this.dateOffset,
    required this.progress
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
    final pointCount = min(timeData.length, sysMinData.length);
    const double dotRadius = 3.5; 
    
    for (int i = 0; i < pointCount; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);

      final targetSysMinY = chartHeight - ((sysMinData[i] - minVal) / range) * chartHeight;
      final targetSysMaxY = chartHeight - ((sysMaxData[i] - minVal) / range) * chartHeight;
      final targetDiaMinY = chartHeight - ((diaMinData[i] - minVal) / range) * chartHeight;
      final targetDiaMaxY = chartHeight - ((diaMaxData[i] - minVal) / range) * chartHeight;

      final sysMinY = chartHeight - ((chartHeight - targetSysMinY) * progress);
      final sysMaxY = chartHeight - ((chartHeight - targetSysMaxY) * progress);
      final diaMinY = chartHeight - ((chartHeight - targetDiaMinY) * progress);
      final diaMaxY = chartHeight - ((chartHeight - targetDiaMaxY) * progress);
      
      // Systolic
      if (sysMinData[i] != sysMaxData[i]) {
        canvas.drawLine(Offset(x, sysMinY), Offset(x, sysMaxY), sysColumnPaint);
        canvas.drawCircle(Offset(x, sysMinY), dotRadius, sysPaint);
        canvas.drawCircle(Offset(x, sysMaxY), dotRadius, sysPaint);
      } else {
        canvas.drawCircle(Offset(x, sysMinY), dotRadius, sysPaint); 
      }

      // Diastolic
      if (diaMinData[i] != diaMaxData[i]) {
        canvas.drawLine(Offset(x, diaMinY), Offset(x, diaMaxY), diaColumnPaint);
        canvas.drawCircle(Offset(x, diaMinY), dotRadius, diaPaint);
        canvas.drawCircle(Offset(x, diaMaxY), dotRadius, diaPaint);
      } else {
        canvas.drawCircle(Offset(x, diaMinY), dotRadius, diaPaint); 
      }

      // Highlight ring for touched point — drawn on top of all dots
      if (touchedIndex == i) {
        // Draw highlight rings on the systolic dot(s)
        canvas.drawCircle(Offset(x, sysMaxY), 8, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x, sysMaxY), 5, Paint()..color = const Color(0xff031447));
        // Draw highlight rings on the diastolic dot(s)
        canvas.drawCircle(Offset(x, diaMinY), 8, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x, diaMinY), 5, Paint()..color = const Color(0xff031447));
      }
    }

    // --- DRAW TOOLTIP (drawn last so it sits above everything) ---
    if (touchedIndex != null && touchedIndex! < pointCount) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);

      final sMin = sysMinData[touchedIndex!];
      final sMax = sysMaxData[touchedIndex!];
      final dMin = diaMinData[touchedIndex!];
      final dMax = diaMaxData[touchedIndex!];
      // Anchor tooltip to the highest point (systolic max)
      final highestY = chartHeight - ((sMax - minVal) / range) * chartHeight;

      _drawTooltip(canvas, size, x, highestY, chartHeight, sMin, sMax, dMin, dMax, timeData[touchedIndex!]);
    }
  }

  // --- UPDATED: Tooltip now matches body weight style (dark box, date row 1, value row 2) ---
  void _drawTooltip(Canvas canvas, Size size, double x, double highestY, double chartHeight, int sMin, int sMax, int dMin, int dMax, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    // Build the date string (row 1) based on range
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

    // Build the value string (row 2) — show range if min != max, otherwise single value
    String sysStr = sMin == sMax ? "$sMax" : "$sMin–$sMax";
    String diaStr = dMin == dMax ? "$dMax" : "$dMin–$dMax";
    String valueStr = "$sysStr / $diaStr mmHg";

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: "$dateStr\n",
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: valueStr,
          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 14, fontWeight: FontWeight.bold),
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
    // Dark box (matches body weight)
    canvas.drawRRect(rrect, Paint()..color = const Color(0xff1A3F6B));
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
        return List.generate(7, (i) { 
          DateTime t = start.add(Duration(days: i)); 
          return ChartLabel(weekdays[t.weekday - 1], t); 
        });

      case "M": 
        int daysInMonth = end.difference(start).inDays; 
        return List.generate(5, (i) { 
          DateTime t = start.add(Duration(days: (i * (daysInMonth - 1) / 4).round())); 
          return ChartLabel("${t.day} ${months[t.month - 1]}", t); 
        });

      case "3M": 
        return List.generate(3, (i) { 
          DateTime t = DateTime(start.year, start.month + i, 1); 
          return ChartLabel(months[t.month - 1], t); 
        });

      case "6M": 
        return List.generate(6, (i) { 
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