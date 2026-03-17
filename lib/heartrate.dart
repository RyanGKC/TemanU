import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // NEW
import 'package:google_generative_ai/google_generative_ai.dart'; // NEW
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'package:temanu/heartRateChartPainter.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/fitbitService.dart';
import 'package:temanu/mockHrData.dart';

// HrReading is defined here so both heartrate.dart and mockHrData.dart can use it
class HrReading {
  final DateTime time;
  final int bpm;
  HrReading(this.time, this.bpm);
}

class HeartRatePage extends StatefulWidget {
  // NEW: Catch the data map from the homepage
  final Map<String, dynamic> baseUserData;

  const HeartRatePage({super.key, required this.baseUserData});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> with SingleTickerProviderStateMixin {
  int currentHr  = 0;
  int restingHr  = 0;
  bool _isLoadingFitbit = true;

  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // The active dataset — either Fitbit-sourced or mock
  List<HrReading> _activeReadings = [];

  List<DateTime> aggTimes  = [];
  List<int>      aggMinBpm = [];
  List<int>      aggMaxBpm = [];

  // NEW: State variables for the dynamic tip
  String _dynamicAiTip = "Analyzing your heart rate data...";
  bool _isLoadingTip = true;

  // ─── Date range helpers ───────────────────────────────────────────────────

  DateTime get _startTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D":  return DateTime(now.year, now.month, now.day + dateOffset);
      case "W":
        int daysToMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysToMonday + (dateOffset * 7));
      case "M":  return DateTime(now.year, now.month + dateOffset, 1);
      case "3M": return DateTime(now.year, now.month - 2 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
      case "Y":  return DateTime(now.year + dateOffset, 1, 1);
      default:   return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _endTime {
    final now = DateTime.now();
    switch (selectedRange) {
      case "D":  return DateTime(now.year, now.month, now.day + dateOffset + 1);
      case "W":
        int daysToMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysToMonday + 7 + (dateOffset * 7));
      case "M":  return DateTime(now.year, now.month + dateOffset + 1, 1);
      case "3M": return DateTime(now.year, now.month + 1 + (dateOffset * 3), 1);
      case "6M": return DateTime(now.year, now.month + 1 + (dateOffset * 6), 1);
      case "Y":  return DateTime(now.year + dateOffset + 1, 1, 1);
      default:   return DateTime(now.year, now.month, now.day + 1);
    }
  }

  String get dateRangeLabel {
    final start    = _startTime;
    final visualEnd = _endTime.subtract(const Duration(days: 1));
    const months   = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    switch (selectedRange) {
      case "D":  return "${start.day} ${months[start.month - 1]} ${start.year}";
      case "W":  return "${start.day} ${months[start.month - 1]} – ${visualEnd.day} ${months[visualEnd.month - 1]}";
      case "M":  return "${months[start.month - 1]} ${start.year}";
      case "3M":
      case "6M": return "${months[start.month - 1]} – ${months[visualEnd.month - 1]} ${visualEnd.year}";
      case "Y":  return "${start.year}";
      default:   return "";
    }
  }

  String get fullRangeName {
    switch (selectedRange) {
      case "D":  return "Day";
      case "W":  return "Week";
      case "M":  return "Month";
      case "3M": return "3 Months";
      case "6M": return "6 Months";
      case "Y":  return "Year";
      default:   return "Day";
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoadingFitbit = true);

    bool fitbitSuccess = false;

    final token = await FitbitService.getSilentToken();
    if (token != null) {
      final restingResult = await FitbitService.getHeartRate(token);

      if (restingResult != null && restingResult != '--') {
        final parsed = int.tryParse(restingResult);
        if (parsed != null) {
          fitbitSuccess = true;
          if (mounted) {
            setState(() {
              restingHr  = parsed;
              currentHr  = parsed; 
              _activeReadings = List.from(MockHrData.allReadings);
              _activeReadings.add(HrReading(DateTime.now(), parsed));
            });
          }
        }
      }
    }

    if (!fitbitSuccess && mounted) {
      setState(() {
        _activeReadings = MockHrData.allReadings;
        final todayReadings = _activeReadings.where((r) {
          final now = DateTime.now();
          return r.time.year == now.year &&
                 r.time.month == now.month &&
                 r.time.day   == now.day;
        }).toList();

        if (todayReadings.isNotEmpty) {
          currentHr = todayReadings.last.bpm;
          restingHr = todayReadings.map((r) => r.bpm).reduce(min);
        } else if (_activeReadings.isNotEmpty) {
          currentHr = _activeReadings.last.bpm;
          restingHr = _activeReadings.map((r) => r.bpm).reduce(min);
        }
      });
    }

    if (mounted) {
      setState(() => _isLoadingFitbit = false);
      _aggregateData();
      _animationController.forward();
      
      // NEW: Save the currentHr to storage, regardless of whether it 
      // came from Fitbit or the mock fallback!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('latest_hr', currentHr);
      
      // Generate the tip once the data is loaded!
      _generateAITip();
    }
  }

  // ─── AI Tip Generator ─────────────────────────────────────────────────────
  
  // NEW: The dynamic AI tip generator
  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached_hr'); // Unique key for HR!
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
        You are a concise health AI assistant. The user, $userName, has a current heart rate of $currentHr bpm and a resting heart rate of $restingHr bpm.
        
        Write a SHORT, 2-sentence encouraging insight or safety tip based exactly on these numbers. 
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_hr', newTip);

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

  // ─── Aggregation ──────────────────────────────────────────────────────────

  void _aggregateData() {
    final rawData  = _activeReadings;
    final startTime = _startTime;
    final endTime   = _endTime;

    Map<DateTime, List<HrReading>> grouped = {};

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

    final sortedKeys = grouped.keys.toList()..sort();

    aggTimes.clear();
    aggMinBpm.clear();
    aggMaxBpm.clear();

    for (var key in sortedKeys) {
      final readings = grouped[key]!;
      aggTimes.add(key);
      aggMinBpm.add(readings.map((e) => e.bpm).reduce(min));
      aggMaxBpm.add(readings.map((e) => e.bpm).reduce(max));
    }
  }

  // ─── Zone helpers ─────────────────────────────────────────────────────────

  String get zoneText {
    if (currentHr == 0)    return "–";
    if (currentHr < 60)    return "Low";
    if (currentHr <= 100)  return "Normal";
    if (currentHr <= 120)  return "Elevated";
    return "High";
  }

  Color get zoneColor {
    switch (zoneText) {
      case "Normal":   return const Color(0xff4DA5E0);
      case "Low":      return Colors.deepPurple;
      case "Elevated": return Colors.orange;
      case "High":     return Colors.red;
      default:         return Colors.grey;
    }
  }

  // ─── Chart interaction ────────────────────────────────────────────────────

  void _handleChartTap(TapUpDetails details, double width) {
    const double leftPadding  = 55.0;
    final double usableWidth  = width - leftPadding - 20.0;
    final double dx           = details.localPosition.dx;

    if (dx < leftPadding - 15 || dx > width - 5) {
      setState(() => touchedIndex = null);
      return;
    }

    if (aggTimes.isEmpty) return;

    final startTime   = _startTime;
    final endTime     = _endTime;
    final totalMillis = endTime.difference(startTime).inMilliseconds;

    int?   closestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < aggTimes.length; i++) {
      final elapsedMillis = aggTimes[i].difference(startTime).inMilliseconds;
      double timeRatio    = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio           = timeRatio.clamp(0.0, 1.0);
      final x             = leftPadding + (usableWidth * timeRatio);
      final distance      = (x - dx).abs();
      if (distance < 20 && distance < minDistance) {
        minDistance  = distance;
        closestIndex = i;
      }
    }

    setState(() => touchedIndex = closestIndex);
  }

  // ─── Manual data entry ────────────────────────────────────────────────────

  void _addHrReading(int bpm) async { // <-- Make it async
    setState(() {
      currentHr = bpm;
      _activeReadings = List.from(_activeReadings)..add(HrReading(DateTime.now(), bpm));
      _aggregateData();
    });
    
    // NEW: Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('latest_hr', currentHr);

    _generateAITip(forceRefresh: true);
    _animationController.reset();
    _animationController.forward();
  }

  void _showAddDataDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Heart Rate Data"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Heart Rate (BPM)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final bpm = int.tryParse(controller.text);
              if (bpm != null) _addHrReading(bpm);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
          style: TextStyle(color: Color(0xff35E0FF), fontSize: 25, fontWeight: FontWeight.w600),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingFitbit
          ? const Center(child: CircularProgressIndicator(color: Color(0xff35E0FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Header row ──
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
                                currentHr > 0 ? "$currentHr" : "–",
                                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Text("bpm", style: TextStyle(color: Colors.white70, fontSize: 20)),
                            ],
                          ),
                          Text(zoneText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                      InkWell(
                        onTap: _showAddDataDialog,
                        child: const Row(
                          children: [
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

                  // ── Date navigator ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                        onPressed: () {
                          setState(() { dateOffset--; touchedIndex = null; _aggregateData(); });
                          _animationController.reset();
                          _animationController.forward();
                        },
                      ),
                      Text(dateRangeLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                          color: dateOffset < 0 ? Colors.white : Colors.white38, size: 30),
                        onPressed: dateOffset < 0 ? () {
                          setState(() { dateOffset++; touchedIndex = null; _aggregateData(); });
                          _animationController.reset();
                          _animationController.forward();
                        } : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Chart ──
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
                                  timeData:     aggTimes,
                                  minBpmData:   aggMinBpm,
                                  maxBpmData:   aggMaxBpm,
                                  rangeLabel:   selectedRange,
                                  touchedIndex: touchedIndex,
                                  dateOffset:   dateOffset,
                                  progress:     _animation.value,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Range filter ──
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ["D","W","M","3M","6M","Y"].map(_filterButton).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Info cards ──
                  Row(
                    children: [
                      Expanded(child: _infoCard("Current HR",  currentHr > 0 ? "$currentHr\nbpm" : "–")),
                      const SizedBox(width: 8),
                      Expanded(child: _infoCard("Resting HR",  restingHr > 0 ? "$restingHr\nbpm" : "–")),
                      const SizedBox(width: 8),
                      Expanded(child: _zoneCard("Zone", zoneText)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── AI Tips (Updated with the Relay Race and Expanded text) ──
                  InkWell(
                    onTap: () {
                      // 1. Copy the base data
                      final updatedData = Map<String, dynamic>.from(widget.baseUserData);
                      
                      // 2. Overwrite with fresh, live HR data
                      updatedData['heartRate'] = currentHr.toString();
                      
                      // 3. Hand the baton to the Assistant!
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => AssistantPage(userData: updatedData)
                        )
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
                          
                          // Show loader or dynamic tip with overflow protection
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
                                      "Analyzing your heart rate data...", 
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

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ─── Small widgets ────────────────────────────────────────────────────────

  Widget _infoCard(String title, String value) {
    return Container(
      height: 95,
      decoration: BoxDecoration(color: const Color(0xff4DA5E0), borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _zoneCard(String title, String value) {
    return Container(
      height: 95,
      decoration: BoxDecoration(color: zoneColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _filterButton(String label) {
    final selected = selectedRange == label;
    return InkWell(
      onTap: () {
        setState(() { selectedRange = label; touchedIndex = null; dateOffset = 0; _aggregateData(); });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15)),
      ),
    );
  }
}