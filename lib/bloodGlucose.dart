import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/button.dart'; 
import 'package:temanu/textbox.dart';
import 'package:temanu/theme.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class BgReading {
  final DateTime time;
  final double value;
  BgReading(this.time, this.value);
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class BloodGlucose extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const BloodGlucose({super.key, required this.baseUserData});

  @override
  State<BloodGlucose> createState() => _BloodGlucoseState();
}

class _BloodGlucoseState extends State<BloodGlucose> with SingleTickerProviderStateMixin {
  
  // ── Live state ──────────────────────────────────────────────────────────────
  bool _isLoadingChart = true;
  bool _isLoadingTip   = true;

  List<BgReading> _liveReadings = [];

  double currentBGlevel = 0;
  double averageBGlevel = 0;
  double fluctuation    = 0;

  // ── Hardcoded Thresholds (Average Person) ──────────────────────────────────
  final double veryHigh = 200;
  final double high = 140;
  final double low = 70;
  final double veryLow = 54;
  final double highFluctuation = 50;
  final double veryHighFluctuation = 100;

  // ── Chart aggregation ──────────────────────────────────────────────────────
  List<DateTime> aggTimes = [];
  List<double>   aggHighs = [];
  List<double>   aggLows  = [];

  // ── Range / navigation ────────────────────────────────────────────────────
  String selectedRange = "D";
  int?   touchedIndex;
  int    dateOffset    = 0;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _animation;

  // ── AI tip ────────────────────────────────────────────────────────────────
  String _dynamicAiTip = "Analyzing your blood glucose data...";

  // ─────────────────────────────────────────────────────────────────────────
  // Date helpers 
  // ─────────────────────────────────────────────────────────────────────────

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
    final start     = _startTime;
    final visualEnd = _endTime.subtract(const Duration(days: 1));
    const months    = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    switch (selectedRange) {
      case "D":  return "${start.day} ${months[start.month - 1]} ${start.year}";
      case "W":  return "${start.day} ${months[start.month - 1]} - ${visualEnd.day} ${months[visualEnd.month - 1]}";
      case "M":  return "${months[start.month - 1]} ${start.year}";
      case "3M":
      case "6M": return "${months[start.month - 1]} - ${months[visualEnd.month - 1]} ${visualEnd.year}";
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

  // ─────────────────────────────────────────────────────────────────────────
  // Colour / zone helpers
  // ─────────────────────────────────────────────────────────────────────────

  Color getBGLColor(double value) {
    if (value > low && value < high)         return AppTheme.success;
    if (value > veryHigh || value < veryLow) return AppTheme.primaryColor;
    return AppTheme.warning;
  }

  String get zoneText {
    if (currentBGlevel > veryHigh) return "Very High";
    if (currentBGlevel > high)     return "High";
    if (currentBGlevel < veryLow)  return "Very Low";
    if (currentBGlevel < low)      return "Low";
    return "In Range";
  }

  Color get zoneColor => getBGLColor(currentBGlevel);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);

    _fetchBgData().then((_) => _generateAITip());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data fetching
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchBgData() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Blood Glucose');

    List<BgReading> fetched = [];
    for (var m in rawMetrics) {
      String dateStr = m['timestamp'] ?? DateTime.now().toIso8601String();
      if (!dateStr.endsWith('Z')) dateStr += 'Z';
      DateTime date = DateTime.parse(dateStr).toLocal();
      double val = double.tryParse(m['value'].toString()) ?? 0;
      if (val > 0) fetched.add(BgReading(date, val));
    }

    if (mounted) {
      setState(() {
        _liveReadings = fetched..sort((a, b) => a.time.compareTo(b.time));

        if (_liveReadings.isNotEmpty) {
          currentBGlevel = _liveReadings.last.value;

          final todayReadings = _liveReadings.where((r) {
            final now = DateTime.now();
            return r.time.year == now.year &&
                   r.time.month == now.month &&
                   r.time.day   == now.day;
          }).toList();

          if (todayReadings.isNotEmpty) {
            averageBGlevel = todayReadings.map((r) => r.value).reduce((a, b) => a + b) / todayReadings.length;
            double todayMax = todayReadings.map((r) => r.value).reduce(max);
            double todayMin = todayReadings.map((r) => r.value).reduce(min);
            fluctuation = todayMax - todayMin;
          } else {
            averageBGlevel = currentBGlevel;
            fluctuation    = 0;
          }
        } else {
          currentBGlevel = 110;
          averageBGlevel = 110;
          fluctuation    = 0;
        }

        _isLoadingChart = false;
        _aggregateData();
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aggregation
  // ─────────────────────────────────────────────────────────────────────────

  void _aggregateData() {
    Map<DateTime, List<double>> grouped = {};

    for (var reading in _liveReadings) {
      if (reading.time.isBefore(_startTime) || reading.time.isAfter(_endTime)) continue;

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

      grouped.putIfAbsent(bucket, () => []).add(reading.value);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    aggTimes.clear();
    aggHighs.clear();
    aggLows.clear();

    for (var key in sortedKeys) {
      final vals = grouped[key]!;
      aggTimes.add(key);
      aggHighs.add(vals.reduce(max));
      aggLows.add(vals.reduce(min));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save new reading
  // ─────────────────────────────────────────────────────────────────────────

  void _addBgData(double value) async {
    setState(() => _isLoadingChart = true);

    bool success = await ApiService.saveHealthMetric(
      metricType: "Blood Glucose",
      value: value.toString(),
      unit: "mg/dL",
    );

    if (success) {
      await _fetchBgData();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save data. Check your connection.')),
        );
      }
    }
  }

  void _showAddDataDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Glucose Data',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter your latest blood glucose reading in mg/dL.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: controller,
                hintText: 'Value (mg/dL)',
                prefixIcon: Icons.water_drop_outlined,
              ),
              const SizedBox(height: 25),
              MyRoundedButton(
                text: 'Save Reading',
                backgroundColor: AppTheme.primaryColor,
                textColor: AppTheme.textPrimary,
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  if (val != null && val > 0) _addBgData(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chart interaction — full hover + tap + drag matching body weight pattern
  // ─────────────────────────────────────────────────────────────────────────

  void _handleChartInteraction(Offset localPosition, double width) {
    const double leftPadding = 55.0;
    final double usableWidth = width - leftPadding - 20.0;
    final double dx = localPosition.dx;

    if (dx < leftPadding - 15 || dx > width - 5) {
      if (touchedIndex != null) setState(() => touchedIndex = null);
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
      double timeRatio    = totalMillis > 0 ? elapsedMillis / totalMillis : 0;
      timeRatio           = timeRatio.clamp(0.0, 1.0);
      final x             = leftPadding + (usableWidth * timeRatio);
      final distance      = (x - dx).abs();
      if (distance < 20 && distance < minDistance) {
        minDistance  = distance;
        closestIndex = i;
      }
    }

    if (touchedIndex != closestIndex) {
      setState(() => touchedIndex = closestIndex);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Tip
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = prefs.getString('ai_tip_cached_bg');
      if (cached != null && cached.isNotEmpty) {
        if (mounted) setState(() { _dynamicAiTip = cached; _isLoadingTip = false; });
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
        You are a concise health AI assistant. The user, $userName, has a current blood glucose level of ${currentBGlevel.toInt()} mg/dL.
        Their daily average is ${averageBGlevel.toInt()} mg/dL and today's fluctuation is ${fluctuation.toInt()} mg/dL.
        Their status is "$zoneText".

        Write a SHORT, 2-sentence encouraging insight or safety tip based exactly on these numbers.
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);

      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_bg', newTip);
        setState(() { _dynamicAiTip = newTip; _isLoadingTip = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dynamicAiTip = "Keep monitoring your levels! Tap here for personalised insights.";
          _isLoadingTip = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Blood Glucose",
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: AppTheme.background.withOpacity(0.5)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // ── Header row ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current", style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text(
                      "${currentBGlevel.toInt()} mg/dL",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                    ),
                    Text(zoneText, style: TextStyle(color: zoneColor, fontSize: 16)),
                  ],
                ),
                InkWell(
                  onTap: _showAddDataDialog,
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

            // ── Range title ──────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "$fullRangeName Overview",
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // ── Date navigation ──────────────────────────────────────────────
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: dateOffset < 0 ? Colors.white : Colors.white38,
                    size: 30,
                  ),
                  onPressed: dateOffset < 0
                      ? () {
                          setState(() {
                            dateOffset++;
                            touchedIndex = null;
                            _aggregateData();
                          });
                          _animationController.reset();
                          _animationController.forward();
                        }
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Chart Container — now with MouseRegion + full gesture support ──
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
              ),
              child: _isLoadingChart 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return MouseRegion(
                            onHover: (event) => _handleChartInteraction(event.localPosition, constraints.maxWidth),
                            onExit: (_) {
                              if (touchedIndex != null) setState(() => touchedIndex = null);
                            },
                            child: GestureDetector(
                              onTapUp: (details) => _handleChartInteraction(details.localPosition, constraints.maxWidth),
                              onHorizontalDragUpdate: (details) => _handleChartInteraction(details.localPosition, constraints.maxWidth),
                              onHorizontalDragEnd: (_) {
                                if (touchedIndex != null) setState(() => touchedIndex = null);
                              },
                              child: CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: BloodGlucoseChartPainter(
                                  timeData: aggTimes,
                                  minBgData: aggLows,
                                  maxBgData: aggHighs,
                                  rangeLabel: selectedRange,
                                  touchedIndex: touchedIndex,
                                  dateOffset: dateOffset,
                                  progress: _animation.value,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
            ),

            const SizedBox(height: 14),

            // ── Range filter pills ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["D", "W", "M", "3M", "6M", "Y"]
                    .map((r) => _filterButton(r))
                    .toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Info cards ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _infoCard("Daily Avg", "${averageBGlevel.toInt()}\nmg/dL", AppTheme.cardBackground)),
                const SizedBox(width: 8),
                Expanded(child: _infoCard("Fluctuation", "${fluctuation.toInt()}\nmg/dL", AppTheme.cardBackground)),
                const SizedBox(width: 8),
                Expanded(child: _infoCard("Status", zoneText, zoneColor)),
              ],
            ),

            const SizedBox(height: 16),

            // ── AI tips card ─────────────────────────────────────────────────
            InkWell(
              onTap: () {
                final updatedData = Map<String, dynamic>.from(widget.baseUserData);
                updatedData['bloodGlucose'] = "${currentBGlevel.toInt()} mg/dL";
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AssistantPage(userData: updatedData)),
                );
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("💡 AI Tips",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoadingTip
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: SizedBox(
                                  height: 16, width: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white70, strokeWidth: 2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Analyzing your blood glucose data...",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          )
                        : Text(_dynamicAiTip,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, height: 1.5)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Small reusable widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _infoCard(String title, String value, Color bgColor) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 6),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _filterButton(String label) {
    final selected = selectedRange == label;
    return InkWell(
      onTap: () {
        setState(() {
          selectedRange = label;
          touchedIndex  = null;
          dateOffset    = 0;
          _aggregateData();
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Custom Painter
// ─────────────────────────────────────────────────────────────────────────

class BloodGlucoseChartPainter extends CustomPainter {
  final List<DateTime> timeData;
  final List<double> minBgData;
  final List<double> maxBgData;
  final String rangeLabel;
  final int? touchedIndex;
  final int dateOffset;
  final double progress;

  BloodGlucoseChartPainter({
    required this.timeData,
    required this.minBgData,
    required this.maxBgData,
    required this.rangeLabel,
    this.touchedIndex,
    required this.dateOffset,
    required this.progress
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint       = Paint()..color = AppTheme.primaryColor..style = PaintingStyle.fill;
    final bgColumnPaint = Paint()..color = AppTheme.primaryColor.withOpacity(0.4)..strokeWidth = 5..strokeCap = StrokeCap.round;
    final gridPaint     = Paint()..color = AppTheme.textSecondary.withOpacity(0.5)..strokeWidth = 1;
    const textStyle     = TextStyle(color: AppTheme.textPrimary, fontSize: 11);

    // --- Y-AXIS ---
    final allValues = [...minBgData, ...maxBgData];
    final minVal = allValues.isEmpty ? 50.0  : max(0.0, ((allValues.reduce(min) - 20) ~/ 10) * 10.0);
    final maxVal = allValues.isEmpty ? 200.0 : (((allValues.reduce(max) + 20) ~/ 10) * 10).toDouble();
    final range  = maxVal - minVal == 0 ? 10 : maxVal - minVal;

    const leftPadding   = 55.0;
    const bottomPadding = 24.0;
    final chartHeight   = size.height - bottomPadding;
    final usableWidth   = size.width - leftPadding - 20;

    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final value = maxVal - (range * i / 5);
      final tp = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, y - 8));
    }

    // --- TIME BOUNDS ---
    final now = DateTime.now();
    DateTime startTime;
    DateTime endTime;

    switch (rangeLabel) {
      case "D":
        startTime = DateTime(now.year, now.month, now.day + dateOffset);
        endTime   = DateTime(now.year, now.month, now.day + dateOffset + 1);
        break;
      case "W":
        int dToM  = now.weekday - 1;
        startTime = DateTime(now.year, now.month, now.day - dToM + (dateOffset * 7));
        endTime   = DateTime(now.year, now.month, now.day - dToM + 7 + (dateOffset * 7));
        break;
      case "M":
        startTime = DateTime(now.year, now.month + dateOffset, 1);
        endTime   = DateTime(now.year, now.month + dateOffset + 1, 1);
        break;
      case "3M":
        startTime = DateTime(now.year, now.month - 2 + (dateOffset * 3), 1);
        endTime   = DateTime(now.year, now.month + 1 + (dateOffset * 3), 1);
        break;
      case "6M":
        startTime = DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
        endTime   = DateTime(now.year, now.month + 1 + (dateOffset * 6), 1);
        break;
      case "Y":
        startTime = DateTime(now.year + dateOffset, 1, 1);
        endTime   = DateTime(now.year + dateOffset + 1, 1, 1);
        break;
      default:
        startTime = DateTime(now.year, now.month, now.day);
        endTime   = startTime.add(const Duration(days: 1));
    }

    final totalMillis = endTime.difference(startTime).inMilliseconds;

    // --- X-AXIS LABELS ---
    for (var label in _getDynamicLabels(rangeLabel, startTime, endTime)) {
      final elapsed   = label.time.difference(startTime).inMilliseconds;
      num ratio    = (totalMillis > 0 ? elapsed / totalMillis : 0).clamp(0.0, 1.0);
      final x         = leftPadding + usableWidth * ratio;
      final tp        = TextPainter(
        text: TextSpan(text: label.text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // --- DATA POINTS (columns + dots) ---
    final pointCount = min(timeData.length, minBgData.length);
    const dotRadius  = 3.5;

    for (int i = 0; i < pointCount; i++) {
      final elapsed  = timeData[i].difference(startTime).inMilliseconds;
      num ratio   = (totalMillis > 0 ? elapsed / totalMillis : 0).clamp(0.0, 1.0);
      final x        = leftPadding + usableWidth * ratio;

      final tMinY    = chartHeight - ((minBgData[i] - minVal) / range) * chartHeight;
      final tMaxY    = chartHeight - ((maxBgData[i] - minVal) / range) * chartHeight;
      final minY     = chartHeight - ((chartHeight - tMinY) * progress);
      final maxY     = chartHeight - ((chartHeight - tMaxY) * progress);

      if (minBgData[i] != maxBgData[i]) {
        canvas.drawLine(Offset(x, minY), Offset(x, maxY), bgColumnPaint);
        canvas.drawCircle(Offset(x, minY), dotRadius, bgPaint);
        canvas.drawCircle(Offset(x, maxY), dotRadius, bgPaint);
      } else {
        canvas.drawCircle(Offset(x, minY), dotRadius, bgPaint);
      }

      // Highlight rings drawn on top of the dot(s) for the touched point
      if (touchedIndex == i) {
        canvas.drawCircle(Offset(x, maxY), 8, Paint()..color = AppTheme.textPrimary);
        canvas.drawCircle(Offset(x, maxY), 5, Paint()..color = AppTheme.background);
        if (minBgData[i] != maxBgData[i]) {
          canvas.drawCircle(Offset(x, minY), 8, Paint()..color = AppTheme.textPrimary);
          canvas.drawCircle(Offset(x, minY), 5, Paint()..color = AppTheme.background);
        }
      }
    }

    // --- TOOLTIP drawn last so it layers above everything ---
    if (touchedIndex != null && touchedIndex! < pointCount) {
      final elapsed  = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      num ratio   = (totalMillis > 0 ? elapsed / totalMillis : 0).clamp(0.0, 1.0);
      final x        = leftPadding + usableWidth * ratio;
      final bMin     = minBgData[touchedIndex!];
      final bMax     = maxBgData[touchedIndex!];
      final highestY = chartHeight - ((bMax - minVal) / range) * chartHeight;

      _drawTooltip(canvas, size, x, highestY, bMin, bMax, timeData[touchedIndex!]);
    }
  }

  // --- UPDATED: Dark box tooltip matching body weight style ---
  // Row 1: date/timeframe in white70
  // Row 2: value in cyan (0xff00E5FF)
  void _drawTooltip(Canvas canvas, Size size, double x, double highestY, double bMin, double bMax, DateTime date) {
    const List<String> months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

    // Row 1 — timeframe label
    String dateStr;
    if (rangeLabel == "D") {
      final period = date.hour >= 12 ? "PM" : "AM";
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

    // Row 2 — value (single or range)
    final valueStr = bMin == bMax
        ? "${bMax.toInt()} mg/dL"
        : "${bMin.toInt()}–${bMax.toInt()} mg/dL";

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

    final boxWidth  = textPainter.width + 24;
    final boxHeight = textPainter.height + 16;

    double rectLeft = (x - boxWidth / 2).clamp(55.0, size.width - boxWidth);
    double rectTop  = highestY - boxHeight - 15;
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
    const weekdays         = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
    const months           = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    const singleLetterMonths = ["J","F","M","A","M","J","J","A","S","O","N","D"];
    
    switch (range) {
      case "D": 
        return [
          ChartLabel("12 AM", start),
          ChartLabel("6 AM",  start.add(const Duration(hours: 6))),
          ChartLabel("12 PM", start.add(const Duration(hours: 12))),
          ChartLabel("6 PM",  start.add(const Duration(hours: 18))),
          ChartLabel("12 AM", start.add(const Duration(hours: 24))),
        ];
      case "W":
        return List.generate(7, (i) {
          final t = start.add(Duration(days: i));
          return ChartLabel(weekdays[t.weekday - 1], t);
        });
      case "M":
        final days = end.difference(start).inDays;
        return List.generate(5, (i) {
          final t = start.add(Duration(days: (i * (days - 1) / 4).round()));
          return ChartLabel("${t.day} ${months[t.month - 1]}", t);
        });
      case "3M":
      case "6M":
        final count = range == "3M" ? 3 : 6;
        return List.generate(count, (i) {
          final t = DateTime(start.year, start.month + i, 1);
          return ChartLabel(months[t.month - 1], t);
        });
      case "Y":
        return List.generate(12, (i) {
          final t = DateTime(start.year, start.month + i, 1);
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