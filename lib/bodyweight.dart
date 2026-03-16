import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/MockBwData.dart'; // Make sure this file name matches exactly
import 'package:temanu/assistantpage.dart';
import 'package:temanu/shareWeightHighlightPage.dart';
import 'package:temanu/weightLineChartPainter.dart';

class BodyWeightPage extends StatefulWidget {
  const BodyWeightPage({super.key});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> with SingleTickerProviderStateMixin {
  double currentWeight = 80.5;
  double goalWeight = 80.0;
  double heightCm = 186.0;
  String selectedRange = "W";
  int dateOffset = 0;

  int? touchedIndex; 

  late AnimationController _animationController;
  late Animation<double> _animation;

  // Master lists for the graph
  List<DateTime> aggTimes = [];
  List<double> aggWeights = [];

  String get fullRangeName {
    switch (selectedRange) {
      case "D": return "Day";
      case "W": return "Week";
      case "M": return "Month";
      case "3M": return "3 Months";
      case "6M": return "6 Months";
      case "Y": return "Year";
      default: return "Week";
    }
  }

  // Beautiful UI Label for the time travel arrows
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

  // Time Boundary Math
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    _aggregateData(); 
    _animationController.forward();
  }

  void _aggregateData() {
    final rawData = MockWeightData.allReadings; 
    Map<DateTime, List<WeightReading>> grouped = {};
    final startTime = _startTime;
    final endTime = _endTime;

    // 1. Group the data 
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
    aggWeights.clear();

    // 2. Calculate the Average Weight for each bucket
    for (var key in sortedKeys) {
      var readings = grouped[key]!;
      aggTimes.add(key); 
      double sum = readings.map((e) => e.weight).reduce((a, b) => a + b);
      aggWeights.add(sum / readings.length);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleChartTap(TapUpDetails details, double width) {
    final double leftPadding = 58;
    final double rightPadding = 20;
    final double usableWidth = width - leftPadding - rightPadding;
    final double dx = details.localPosition.dx;

    if (dx < leftPadding - 15 || dx > width - 5) {
      setState(() => touchedIndex = null);
      return;
    }

    if (aggTimes.isEmpty) return;

    final startTime = _startTime;
    final endTime = _endTime;
    final totalMillis = endTime.difference(startTime).inMilliseconds;
    
    int? closestIndex;
    double minDistance = double.infinity;

    // Find proportional tap zones just like BP chart
    for (int i = 0; i < aggTimes.length; i++) {
      final elapsedMillis = aggTimes[i].difference(startTime).inMilliseconds;
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

  double get bmi {
    final h = heightCm / 100;
    return currentWeight / (h * h);
  }

  double get changeWeight {
    if (aggWeights.length < 2) return 0;
    return aggWeights.last - aggWeights.first;
  }

  String get aiTips {
    if (changeWeight < 0) {
      return "You've done well, losing ${changeWeight.abs().toStringAsFixed(1)} kg and getting close to your goal. "
          "Now is the time to focus on steady, lasting progress. Keep your meals balanced, stay hydrated, and prioritize good rest.";
    } else if (changeWeight > 0) {
      return "Your weight has increased slightly. Try improving your diet, increase activity, and stay consistent with healthy habits.";
    } else {
      return "Your weight is stable. Keep maintaining your current healthy routine.";
    }
  }

  void addWeightData(double value) {
    setState(() {
      currentWeight = value;
      // Add dynamic data to master list!
      MockWeightData.allReadings.add(WeightReading(DateTime.now(), value));
      _aggregateData();
    });
    _animationController.reset();
    _animationController.forward();
  }

  void showAddDataDialog() {
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Weight Data"),
          content: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Enter new weight (kg)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newWeight = double.tryParse(weightController.text);
                if (newWeight != null) {
                  addWeightData(newWeight);
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
        builder: (context) => ShareWeightHighlightPage(
          changeValue: changeWeight,
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
        centerTitle: false,
        title: const Text(
          "Body Weight",
          style: TextStyle(
            color: Color(0xff35E0FF),
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.white.withValues(alpha: 0.25)
            )
          )
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentWeight.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0, left: 2),
                          child: Text(
                            "kg",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ],
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                  onPressed: () {
                    setState(() {
                      dateOffset--;
                      touchedIndex = null;
                      _aggregateData(); // Calculate the new dates
                    });
                    _animationController.reset();
                    _animationController.forward();
                  },
                ),
                Text(
                  dateRangeLabel, // Now it shows the beautiful date range!
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
                      _aggregateData(); // Calculate the new dates
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
                          // Updated with the correct variables!
                          painter: WeightLineChartPainter(aggTimes, aggWeights, selectedRange, touchedIndex, _animation.value, dateOffset)
                        ),
                      );
                    },
                  );
                }
              ),
            ),

            const SizedBox(height: 16),

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
                  filterButton("D"), // Added Day filter back!
                  filterButton("W"),
                  filterButton("M"),
                  filterButton("3M"),
                  filterButton("6M"),
                  filterButton("Y"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Goal / Change / BMI
            Row(
              children: [
                Expanded(
                  child: infoCard("Goal", goalWeight.toStringAsFixed(0)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg"),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: infoCard("BMI", bmi.toStringAsFixed(1)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Tips (Clickable to Assistant just like BP Page)
            InkWell(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const AssistantPage())
                );
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
                        Text(
                          "💡 AI Tips",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18), 
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
            const SizedBox(height: 24),
          ],
        ),
      ),
      // Left the Bottom Nav Bar here as requested, though you can delete it if you prefer!
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left:20, right: 20, bottom: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1), 
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const AssistantPage())
                          );
                        },
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome,
                            size: 28,
                            color: Colors.white70
                          ),
                        )
                      )
                    )
                  )
                )
              ),
            ]
          )
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
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
          dateOffset = 0; // Reset offset when switching tabs!
          _aggregateData(); 
        });
        _animationController.reset();
        _animationController.forward();
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