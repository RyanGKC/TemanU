import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:temanu/heartRateChartPainter.dart'; // Make sure this matches your file name!
import 'package:temanu/assistantpage.dart';

// --- MOCK DATA GENERATOR ---
class HrReading {
  final DateTime time;
  final int bpm;
  HrReading(this.time, this.bpm);
}

class MockHrData {
  static List<HrReading> allReadings = List.generate(
    150, 
    (i) => HrReading(DateTime.now().subtract(Duration(hours: i * 2)), 60 + Random().nextInt(45))
  );
}
// ----------------------------

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> with SingleTickerProviderStateMixin {
  int currentHr = 72;
  int restingHr = 64;
  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  DateTime get _startTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D": return DateTime(now.year, now.month, now.day + dateOffset);
      case "W": 
        int daysToMonday = now.weekday - 1; 
        return DateTime(now.year, now.month, now.day - daysToMonday + (dateOffset * 7));
      case "M": return DateTime(now.year, now.month + dateOffset, 1);
      case "3M": return DateTime(now.year, now.month - 2 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
      case "Y": return DateTime(now.year + dateOffset, 1, 1);
      default: return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _endTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D": return DateTime(now.year, now.month, now.day + dateOffset + 1);
      case "W": 
        int daysToMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysToMonday + 7 + (dateOffset * 7));
      case "M": return DateTime(now.year, now.month + dateOffset + 1, 1);
      case "3M": return DateTime(now.year, now.month + 1 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month + 1 + (dateOffset * 6), 1);
      case "Y": return DateTime(now.year + dateOffset + 1, 1, 1);
      default: return DateTime(now.year, now.month, now.day + 1);
    }
  }

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

  List<DateTime> aggTimes = [];
  List<int> aggMinBpm = [];
  List<int> aggMaxBpm = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    _aggregateData(); 
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _aggregateData() {
    final rawData = MockHrData.allReadings; 
    Map<DateTime, List<HrReading>> grouped = {};

    final startTime = _startTime;
    final endTime = _endTime;

    for (var reading in rawData) {
      if (reading.time.isBefore(startTime) || reading.time.isAfter(endTime)) continue; 

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

    var sortedKeys = grouped.keys.toList()..sort();

    aggTimes.clear();
    aggMinBpm.clear();
    aggMaxBpm.clear();

    for (var key in sortedKeys) {
      var readings = grouped[key]!;
      aggTimes.add(key); 
      
      int minBpm = readings.map((e) => e.bpm).reduce(min);
      int maxBpm = readings.map((e) => e.bpm).reduce(max);

      aggMinBpm.add(minBpm);
      aggMaxBpm.add(maxBpm);
    }
  }

  String get zoneText {
    if (currentHr < 60) return "Low"; // Bradycardia
    if (currentHr <= 100) return "Normal";
    if (currentHr <= 120) return "Elevated";
    return "High"; // Tachycardia
  }

  Color get zoneColor {
    switch (zoneText) {
      case "Normal": return const Color(0xff4DA5E0);
      case "Low": return Colors.deepPurple;
      case "Elevated": return Colors.orange;
      case "High": return Colors.red;
      default: return const Color(0xff4DA5E0);
    }
  }

  String get aiTips {
    switch (zoneText) {
      case "Normal": return "Your heart rate is in a healthy resting range (60-100 bpm). Keep maintaining your healthy lifestyle!";
      case "Low": return "Your heart rate is below average. This is completely normal if you are athletic, but monitor for dizziness or fatigue.";
      case "Elevated": return "Your heart rate is slightly elevated. Try taking a few deep breaths and relaxing for a few minutes.";
      case "High": return "Your heart rate is high for a resting state. Avoid strenuous activities right now and consult a doctor if it doesn't lower.";
      default: return "Monitor your heart rate regularly.";
    }
  }

  void _handleChartTap(TapUpDetails details, double width) {
    const double leftPadding = 55.0;
    final double usableWidth = width - leftPadding - 20.0;
    final double dx = details.localPosition.dx;

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

    for (int i = 0; i < timeData.length; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      
      final distance = (x - dx).abs();
      if (distance < 20 && distance < minDistance) { 
        minDistance = distance;
        closestIndex = i;
      }
    }

    setState(() => touchedIndex = closestIndex);
  }

  void addHrData(int bpm) {
    setState(() {
      currentHr = bpm;
      MockHrData.allReadings.add(HrReading(DateTime.now(), bpm));
      _aggregateData(); 
    });
    _animationController.reset();
    _animationController.forward();
  }

  void showAddDataDialog() {
    final bpmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Heart Rate Data"),
          content: TextField(
            controller: bpmController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Heart Rate (BPM)"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final bpm = int.tryParse(bpmController.text);
                if (bpm != null) {
                  addHrData(bpm);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff031447),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xff55607D),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Heart Rate",
          style: TextStyle(
            color: Color(0xff35E0FF),
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.25))
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current", style: TextStyle(color: Colors.white, fontSize: 16)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$currentHr",
                          style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "bpm",
                          style: TextStyle(color: Colors.white70, fontSize: 20),
                        ),
                      ],
                    ),
                    Text(zoneText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                InkWell(
                  onTap: showAddDataDialog,
                  child: Row(
                    children: const [
                      Icon(Icons.add_box_outlined, color: Colors.white),
                      SizedBox(width: 6),
                      Text("Add data", style: TextStyle(color: Colors.white, fontSize: 18)),
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
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                      dateOffset--; 
                      touchedIndex = null;
                      _aggregateData();
                    });
                    _animationController.reset();
                    _animationController.forward();
                  },
                ),
                Text(
                  dateRangeLabel, 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right, 
                    color: dateOffset < 0 ? Colors.white : Colors.white38, 
                    size: 30
                  ),
                  onPressed: dateOffset < 0 ? () {
                    setState(() {
                      dateOffset++; 
                      touchedIndex = null;
                      _aggregateData();
                    });
                    _animationController.reset();
                    _animationController.forward();
                  } : null, 
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
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) => _handleChartTap(details, constraints.maxWidth),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: HeartRateChartPainter(
                            timeData: aggTimes,
                            minBpmData: aggMinBpm,
                            maxBpmData: aggMaxBpm,
                            rangeLabel: selectedRange,
                            touchedIndex: touchedIndex,
                            dateOffset: dateOffset,
                            progress: _animation.value, 
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ),

            const SizedBox(height: 14),

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
            
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: infoCard("Current HR", "$currentHr\nbpm")), 
                const SizedBox(width: 8),
                Expanded(child: infoCard("Resting HR", "$restingHr\nbpm")),
                const SizedBox(width: 8),
                Expanded(child: zoneCard("Zone", zoneText)),
              ],
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantPage()));
              },
              borderRadius: BorderRadius.circular(22), 
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
                        Text("💡 AI Tips", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18), 
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(aiTips, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
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
      decoration: BoxDecoration(color: const Color(0xff4DA5E0), borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget zoneCard(String title, String value) {
    return Container(
      height: 95,
      decoration: BoxDecoration(color: zoneColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent, // Highlight matches graph color
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15),
        ),
      ),
    );
  }
}