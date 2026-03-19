import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart'; // <-- NEW: Import API Service
import 'package:temanu/bloodPressureSharePage.dart';
import 'package:temanu/bloodPresureChartPainter.dart';
import 'package:temanu/assistantpage.dart';

// <-- Removed the MockBpData import!

class BpReading {
  final DateTime time;
  final int sys;
  final int dia;
  BpReading(this.time, this.sys, this.dia);
}

class BloodPressurePage extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const BloodPressurePage({super.key, required this.baseUserData});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> with SingleTickerProviderStateMixin {
  int systolic = 0; // Will be populated by DB
  int diastolic = 0; // Will be populated by DB
  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  String _dynamicAiTip = "Analyzing your blood pressure data...";
  bool _isLoadingTip = true;
  bool _isLoadingChart = true; // <-- NEW: Track loading state for the chart

  late AnimationController _animationController;
  late Animation<double> _animation;

  // <-- NEW: Holds the live data from your Railway backend
  List<BpReading> _liveReadings = []; 

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
  List<int> aggSysMin = [];
  List<int> aggSysMax = [];
  List<int> aggDiaMin = [];
  List<int> aggDiaMax = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    
    // <-- NEW: Fetch live data on load
    _fetchBpData();
    _generateAITip();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── NEW: Fetch data from Railway ─────────────────────────────────────────
  Future<void> _fetchBpData() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Blood Pressure');

    List<BpReading> fetchedData = [];
    for (var m in rawMetrics) {
      String dateStr = m['timestamp'] ?? DateTime.now().toIso8601String();
      if (!dateStr.endsWith('Z')) dateStr += 'Z'; 
      DateTime date = DateTime.parse(dateStr).toLocal();
      
      // 🎯 THE SPLIT MAGIC: "120/80" becomes ["120", "80"]
      String combinedValue = m['value'].toString();
      List<String> parts = combinedValue.split('/');
      
      if (parts.length == 2) {
        int sys = int.tryParse(parts[0]) ?? 120;
        int dia = int.tryParse(parts[1]) ?? 80;
        fetchedData.add(BpReading(date, sys, dia));
      }
    }

    if (mounted) {
      setState(() {
        _liveReadings = fetchedData;
        
        if (_liveReadings.isNotEmpty) {
          _liveReadings.sort((a, b) => a.time.compareTo(b.time));
          systolic = _liveReadings.last.sys;
          diastolic = _liveReadings.last.dia;
        } else {
          // Fallback if the user has no data yet
          systolic = 118;
          diastolic = 76;
        }

        _isLoadingChart = false;
        _aggregateData(); 
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  // ─── AI Tip Generator ─────────────────────────────────────────────────────

  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached_bp'); 
      if (cachedTip != null && cachedTip.isNotEmpty) {
        if (mounted) {
          setState(() {
            _dynamicAiTip = cachedTip;
            _isLoadingTip = false;
          });
        }
        return; 
      }
    }

    if (mounted) setState(() => _isLoadingTip = true);

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) return;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.4),
      );

      final userName = widget.baseUserData['name'] ?? 'the user';

      final prompt = '''
        You are a concise health AI assistant. The user, $userName, has a current blood pressure of $systolic/$diastolic mmHg.
        This reading falls into the "$zoneText" category.
        
        Write a SHORT, 2-sentence encouraging insight or safety tip based exactly on these numbers. 
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_bp', newTip);

        setState(() {
          _dynamicAiTip = newTip;
          _isLoadingTip = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dynamicAiTip = "Keep up the great work today! Tap here to chat for more insights.";
          _isLoadingTip = false;
        });
      }
    }
  }

  void _aggregateData() {
    // <-- NEW: Use live readings instead of Mock data
    final rawData = _liveReadings; 
    Map<DateTime, List<BpReading>> grouped = {};

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
    if (systolic > 180 || diastolic > 120) return "Crisis";
    if (systolic >= 140 || diastolic >= 90) return "High";
    if (systolic >= 130 || diastolic >= 80) return "Stage 1";
    if (systolic >= 120 && diastolic < 80) return "Elevated";
    return "Healthy";
  }

  Color get zoneColor {
    switch (zoneText) {
      case "Healthy": return const Color(0xff4DA5E0);
      case "Elevated": return Colors.orange;
      case "Stage 1": return Colors.deepOrange;
      case "High": return Colors.red;
      case "Crisis": return Colors.purple;
      default: return const Color(0xff4DA5E0);
    }
  }

  void _handleChartTap(TapUpDetails details, double width) {
    final double leftPadding = 55.0;
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

  // ─── NEW: Send data to Railway ──────────────────────────────────────────
  void addBpData(int sys, int dia) async { 
    setState(() => _isLoadingChart = true);
    
    // 1. Combine them into the single string your backend expects
    String combinedValue = "$sys/$dia";

    bool success = await ApiService.saveHealthMetric(
      metricType: "Blood Pressure", 
      value: combinedValue, 
      unit: "mmHg"
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('latest_bp', combinedValue);

      await _fetchBpData();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save data. Check your connection.')),
      );
    }
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
                decoration: const InputDecoration(labelText: "Systolic (mmHg)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Diastolic (mmHg)"),
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
        centerTitle: false,
        title: const Text(
          "Blood Pressure",
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current", style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text(
                      "$systolic / $diastolic",
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
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

            // Chart Container
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff59A2DD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: _isLoadingChart 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return LayoutBuilder(
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange)),
                    const SizedBox(width: 6),
                    const Text("Systolic", style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text("Diastolic", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: infoCard("Systolic", "$systolic\nmmHg")), 
                const SizedBox(width: 8),
                Expanded(child: infoCard("Diastolic", "$diastolic\nmmHg")),
                const SizedBox(width: 8),
                Expanded(child: zoneCard("Zone", zoneText)),
              ],
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: () {
                final updatedData = Map<String, dynamic>.from(widget.baseUserData);
                updatedData['bloodPressure'] = "$systolic/$diastolic";
                
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => AssistantPage(userData: updatedData))
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
                        Text("💡 AI Tips", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18), 
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _isLoadingTip 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Analyzing your blood pressure data...", 
                                style: const TextStyle(color: Colors.white70, fontSize: 14)
                              ),
                            ),
                          ],
                        )
                      : Text(_dynamicAiTip, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
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
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
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
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
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