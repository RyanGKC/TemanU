import 'dart:ui';
import 'dart:math';
import 'package:temanu/MockBpData.dart';
import 'package:flutter/material.dart';
import 'package:temanu/bloodPressureSharePage.dart';
import 'package:temanu/bloodPresureChartPainter.dart';
import 'package:temanu/assistantpage.dart';

class BpReading {
  final DateTime time;
  final int sys;
  final int dia;
  BpReading(this.time, this.sys, this.dia);
}
class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  int systolic = 118;
  int diastolic = 76;
  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  // 1. Calculates the EXACT start time based on the offset
  DateTime get _startTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D": return DateTime(now.year, now.month, now.day + dateOffset);
      case "W": 
        // Find how many days to subtract to get back to Monday
        int daysToMonday = now.weekday - 1; 
        return DateTime(now.year, now.month, now.day - daysToMonday + (dateOffset * 7));
      case "M": return DateTime(now.year, now.month + dateOffset, 1);
      case "3M": return DateTime(now.year, now.month - 2 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
      case "Y": return DateTime(now.year + dateOffset, 1, 1);
      default: return DateTime(now.year, now.month, now.day);
    }
  }

  // 2. Calculates the EXACT end time based on the offset
  DateTime get _endTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D": return DateTime(now.year, now.month, now.day + dateOffset + 1);
      case "W": 
        // End time is exactly 7 days after the Monday start time
        int daysToMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysToMonday + 7 + (dateOffset * 7));
      case "M": return DateTime(now.year, now.month + dateOffset + 1, 1);
      case "3M": return DateTime(now.year, now.month + 1 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month + 1 + (dateOffset * 6), 1);
      case "Y": return DateTime(now.year + dateOffset + 1, 1, 1);
      default: return DateTime(now.year, now.month, now.day + 1);
    }
  }

  // 3. Formats a beautiful label for the UI (e.g., "2 Mar - 8 Mar")
  String get dateRangeLabel {
    final start = _startTime;
    final visualEnd = _endTime.subtract(const Duration(days: 1)); 
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    switch (selectedRange) {
      case "D": return "${start.day} ${months[start.month - 1]} ${start.year}";
      case "W": return "${start.day} ${months[start.month - 1]} - ${visualEnd.day} ${months[visualEnd.month - 1]}";
      case "M": return "${months[start.month - 1]} ${start.year}";
      case "3M":
      case "6M": return "${months[start.month - 1]} - ${months[visualEnd.month - 1]} ${visualEnd.year}";
      case "Y": return "${start.year}";
      default: return "";
    }
  }

  String get fullRangeName {
    switch (selectedRange) {
      case "D": return "Day";
      case "W": return "Week";
      case "M": return "Month";
      case "3M": return "3 Months";
      case "6M": return "6 Months";
      case "Y": return "Year";
      default: return "Day";
    }
  }

  // Master lists holding the aggregated data to pass to the painter
  List<DateTime> aggTimes = [];
  List<int> aggSysMin = [];
  List<int> aggSysMax = [];
  List<int> aggDiaMin = [];
  List<int> aggDiaMax = [];

  @override
  void initState() {
    super.initState();
    _aggregateData(); // Calculate on load
  }

  void _aggregateData() {
    final rawData = MockBpData.allReadings; 
    Map<DateTime, List<BpReading>> grouped = {};

    // 1. Fetch the valid time window using our new offset getters!
    final startTime = _startTime;
    final endTime = _endTime;

    // 2. Group the data into Hours, Days, Weeks, or Months
    for (var reading in rawData) {
      if (reading.time.isBefore(startTime) || reading.time.isAfter(endTime)) {
        continue; 
      }

      DateTime bucket;
      
      if (selectedRange == "D") {
        bucket = DateTime(reading.time.year, reading.time.month, reading.time.day, reading.time.hour);
      } else if (selectedRange == "W" || selectedRange == "M") {
        bucket = DateTime(reading.time.year, reading.time.month, reading.time.day);
      } else if (selectedRange == "3M" || selectedRange == "6M") {
        bucket = DateTime(reading.time.year, reading.time.month, reading.time.day - reading.time.weekday + 1);
      } else {
        bucket = DateTime(reading.time.year, reading.time.month, 1);
      }

      grouped.putIfAbsent(bucket, () => []).add(reading);
    }

    // Sort the buckets chronologically
    var sortedKeys = grouped.keys.toList()..sort();

    // Clear the arrays and calculate Min/Max for each bucket
    aggTimes.clear();
    aggSysMin.clear();
    aggSysMax.clear();
    aggDiaMin.clear();
    aggDiaMax.clear();

    for (var key in sortedKeys) {
      var readings = grouped[key]!;
      aggTimes.add(key); 
      
      int sysMin = readings.map((e) => e.sys).reduce(min);
      int sysMax = readings.map((e) => e.sys).reduce(max);
      int diaMin = readings.map((e) => e.dia).reduce(min);
      int diaMax = readings.map((e) => e.dia).reduce(max);

      aggSysMin.add(sysMin);
      aggSysMax.add(sysMax);
      aggDiaMin.add(diaMin);
      aggDiaMax.add(diaMax);
    }
  }

  String get zoneText {
    if (systolic > 180 || diastolic > 120) {
      return "Crisis";
    } else if (systolic >= 140 || diastolic >= 90) {
      return "High";
    } else if (systolic >= 130 || diastolic >= 80) {
      return "Stage 1";
    } else if (systolic >= 120 && diastolic < 80) {
      return "Elevated";
    } else {
      return "Healthy";
    }
  }

  Color get zoneColor {
    switch (zoneText) {
      case "Healthy":
        return const Color(0xff4DA5E0);
      case "Elevated":
        return Colors.orange;
      case "Stage 1":
        return Colors.deepOrange;
      case "High":
        return Colors.red;
      case "Crisis":
        return Colors.purple;
      default:
        return const Color(0xff4DA5E0);
    }
  }

  String get aiTips {
    switch (zoneText) {
      case "Healthy":
        return "Your blood pressure is in a healthy range. Keep maintaining your healthy lifestyle.";
      case "Elevated":
        return "Your blood pressure is slightly elevated. Reduce salt intake and monitor regularly.";
      case "Stage 1":
        return "Your blood pressure is in Stage 1 hypertension range. Consider lifestyle changes and regular monitoring.";
      case "High":
        return "Your blood pressure is high. Please reduce stress, improve diet, and consult a healthcare professional if needed.";
      case "Crisis":
        return "Your reading is in hypertensive crisis range. Seek medical attention immediately.";
      default:
        return "Monitor your blood pressure regularly.";
    }
  }

  void _handleChartTap(TapUpDetails details, double width) {
    final double leftPadding = 55.0;
    final double usableWidth = width - leftPadding - 20.0;
    final double dx = details.localPosition.dx;

    // Deselect if tapped completely outside the chart bounds
    if (dx < leftPadding - 15 || dx > width - 5) {
      setState(() => touchedIndex = null);
      return;
    }

    final timeData = aggTimes;
    if (timeData.isEmpty) return;

    final startTime = _startTime;
    final endTime = _endTime;

    final totalMillis = endTime.difference(startTime).inMilliseconds;
    
    int? closestIndex;
    double minDistance = double.infinity;

    // Find the data point closest to where the user tapped
    for (int i = 0; i < timeData.length; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      
      final distance = (x - dx).abs();
      if (distance < 20 && distance < minDistance) { // 20-pixel touch radius
        minDistance = distance;
        closestIndex = i;
      }
    }

    setState(() => touchedIndex = closestIndex);
  }

  void addBpData(int sys, int dia) {
    setState(() {
      systolic = sys;
      diastolic = dia;

      // 1. Add the raw reading to our master data source
      MockBpData.allReadings.add(BpReading(DateTime.now(), sys, dia));

      // 2. Recalculate the buckets so the graph updates immediately!
      _aggregateData(); 
    });
  }

  void showAddDataDialog() {
    final sysController = TextEditingController();
    final diaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Blood Pressure Data"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Systolic (mmHg)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Diastolic (mmHg)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final sys = int.tryParse(sysController.text);
                final dia = int.tryParse(diaController.text);

                if (sys != null && dia != null) {
                  addBpData(sys, dia);
                }

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void openSharePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodPressureSharePage(
          sys: systolic,
          dia: diastolic,
          zone: zoneText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff031447),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xff55607D),
        elevation: 0,
        title: const Text(
          "Blood Pressure",
          style: TextStyle(
            color: Color(0xff35E0FF),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: openSharePage,
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current + Add data
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Current",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      "$systolic / $diastolic",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      zoneText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: showAddDataDialog,
                  child: Row(
                    children: const [
                      Icon(Icons.add_box_outlined, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        "Add data",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "$fullRangeName Overview",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                  onPressed: () {
                    setState(() {
                      dateOffset--; // Move back in time
                      touchedIndex = null;
                      _aggregateData();
                    });
                  },
                ),
                Text(
                  dateRangeLabel, // Shows "March 2026", etc.
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right, 
                    color: dateOffset < 0 ? Colors.white : Colors.white38, // Dim if at current date
                    size: 30
                  ),
                  onPressed: dateOffset < 0 ? () {
                    setState(() {
                      dateOffset++; // Move forward in time
                      touchedIndex = null;
                      _aggregateData();
                    });
                  } : null, // Disables button if we are at the present
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Chart
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff59A2DD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapUp: (details) => _handleChartTap(details, constraints.maxWidth),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: BloodPressureChartPainter(
                        timeData: aggTimes,
                        sysMinData: aggSysMin,
                        sysMaxData: aggSysMax,
                        diaMinData: aggDiaMin,
                        diaMaxData: aggDiaMax,
                        rangeLabel: selectedRange,
                        touchedIndex: touchedIndex,
                        dateOffset: dateOffset,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Time filter
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  filterButton("D"),
                  filterButton("W"),
                  filterButton("M"),
                  filterButton("3M"),
                  filterButton("6M"),
                  filterButton("Y"),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Systolic",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Diastolic",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Metrics
            Row(
              children: [
                Expanded(
                  child: infoCard("Systolic", "$systolic\nmmHg"), // Added a \n so the text fits nicely!
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: infoCard("Diastolic", "$diastolic\nmmHg"),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: zoneCard("Zone", zoneText),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Tips
            InkWell(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const AssistantPage())
                );
              },
              borderRadius: BorderRadius.circular(22), // Matches container radius for the ripple
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff375B86),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "💡 AI Tips",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18), // Little indicator arrow
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      aiTips,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoCard(String title, String value) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: const Color(0xff4DA5E0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget zoneCard(String title, String value) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: zoneColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget filterButton(String label) {
    final selected = selectedRange == label;
    return InkWell(
      onTap: () {
        setState(() {
          selectedRange = label;
          touchedIndex = null;
          dateOffset = 0;
          _aggregateData();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}