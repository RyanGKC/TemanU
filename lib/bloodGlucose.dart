import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/assistantpage.dart';

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

  // ── Thresholds (editable) ──────────────────────────────────────────────────
  double veryHigh           = 250;
  double high               = 180;
  double low                = 70;
  double veryLow            = 54;
  double highFluctuation    = 80;
  double veryHighFluctuation = 120;

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
    if (value > low && value < high)   return Colors.green;
    if (value > veryHigh || value < veryLow) return Colors.red;
    return const Color.fromARGB(255, 200, 200, 0);
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A3F6B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Blood Glucose Reading", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Value (mg/dL)",
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xff00E5FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff00E5FF)),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) _addBgData(val);
              Navigator.pop(context);
            },
            child: const Text("Save",
                style: TextStyle(color: Color(0xff040F31), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Threshold editor
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<double>?> _showThresholdDialog({
    required String title,
    required List<String> fieldLabels,
    required List<double> currentValues,
  }) {
    List<TextEditingController> controllers = List.generate(
      fieldLabels.length,
      (i) => TextEditingController(text: currentValues[i].toStringAsFixed(0)),
    );
    return showDialog<List<double>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A3F6B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(fieldLabels.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: controllers[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: fieldLabels[i],
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xff00E5FF))),
                ),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff00E5FF)),
            onPressed: () {
              try {
                final vals = controllers.map((c) => double.parse(c.text)).toList();
                Navigator.pop(context, vals);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter valid numbers.")),
                );
              }
            },
            child: const Text("Save",
                style: TextStyle(color: Color(0xff040F31), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editBGLThresholds() async {
    final result = await _showThresholdDialog(
      title: "Edit BGL Thresholds",
      fieldLabels: ["Very High (mg/dL)", "High (mg/dL)", "Low (mg/dL)", "Very Low (mg/dL)"],
      currentValues: [veryHigh, high, low, veryLow],
    );
    if (result != null && result.length == 4) {
      setState(() {
        veryHigh = result[0];
        high     = result[1];
        low      = result[2];
        veryLow  = result[3];
      });
      // Redraw chart to reflect new threshold lines
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _editFluctuationThresholds() async {
    final result = await _showThresholdDialog(
      title: "Edit Fluctuation Thresholds",
      fieldLabels: ["High Fluctuation (mg/dL)", "Very High Fluctuation (mg/dL)"],
      currentValues: [highFluctuation, veryHighFluctuation],
    );
    if (result != null && result.length == 2) {
      setState(() {
        highFluctuation     = result[0];
        veryHighFluctuation = result[1];
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chart interaction
  // ─────────────────────────────────────────────────────────────────────────

  void _handleChartTap(TapUpDetails details, double width) {
    const double leftPadding = 55.0;
    final double usableWidth = width - leftPadding - 20.0;
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
      backgroundColor: const Color(0xff031447),
      extendBody: true,

      appBar: AppBar(
        backgroundColor: const Color(0xff55607D),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Blood Glucose",
          style: TextStyle(
            color: Color(0xff35E0FF),
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
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
        actions: [
          IconButton(
            onPressed: () {}, // Add share page logic if needed
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

            // ── Chart Container ──────────────────────────────────────────────
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
                              painter: BloodGlucoseChartPainter(
                                timeData: aggTimes,
                                highData: aggHighs,
                                lowData: aggLows,
                                rangeLabel: selectedRange,
                                touchedIndex: touchedIndex,
                                dateOffset: dateOffset,
                                progress: _animation.value,
                                veryHigh: veryHigh,
                                high: high,
                                low: low,
                                veryLow: veryLow,
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
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["D", "W", "M", "3M", "6M", "Y"]
                    .map((r) => _filterButton(r))
                    .toList(),
              ),
            ),

            const SizedBox(height: 14),

            // ── Chart legend ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.white, "Highs"),
                const SizedBox(width: 20),
                _legendDot(Colors.white54, "Lows"),
              ],
            ),

            const SizedBox(height: 16),

            // ── Info cards ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _editBGLThresholds, // Kept your editable functionality!
                    borderRadius: BorderRadius.circular(24),
                    child: _infoCard("Daily Avg ✏️", "${averageBGlevel.toInt()}\nmg/dL", getBGLColor(averageBGlevel)),
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _editFluctuationThresholds, // Kept your editable functionality!
                    borderRadius: BorderRadius.circular(24),
                    child: _infoCard("Fluctuation ✏️", "${fluctuation.toInt()}\nmg/dL", const Color(0xff4DA5E0)),
                  )
                ),
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
                  color: const Color(0xff375B86),
                  borderRadius: BorderRadius.circular(22),
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
          borderRadius: BorderRadius.circular(24)),
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
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
          width: 12, height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Custom Painter (Matches BloodPressure architecture perfectly)
// ─────────────────────────────────────────────────────────────────────────

class BloodGlucoseChartPainter extends CustomPainter {
  final List<DateTime> timeData;
  final List<double> highData;
  final List<double> lowData;
  final String rangeLabel;
  final int? touchedIndex;
  final int dateOffset;
  final double progress;

  // Thresholds
  final double veryHigh;
  final double high;
  final double low;
  final double veryLow;

  BloodGlucoseChartPainter({
    required this.timeData,
    required this.highData,
    required this.lowData,
    required this.rangeLabel,
    required this.touchedIndex,
    required this.dateOffset,
    required this.progress,
    required this.veryHigh,
    required this.high,
    required this.low,
    required this.veryLow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 55.0;
    const double bottomPadding = 30.0;
    final double usableWidth = size.width - leftPadding - 20.0;
    final double usableHeight = size.height - bottomPadding;

    // Background Grid & Threshold Lines
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    final Paint veryHighPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final Paint highPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final Paint lowPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final Paint veryLowPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Define Y-Axis max dynamically to fit the thresholds or data
    double maxData = highData.isNotEmpty ? highData.reduce(max) : 200;
    double maxY = max(veryHigh + 50, maxData + 50);

    // Draw horizontal grid and labels
    for (int i = 0; i <= 4; i++) {
      double yVal = (maxY / 4) * i;
      double yPos = usableHeight - (yVal / maxY * usableHeight);

      canvas.drawLine(Offset(leftPadding, yPos), Offset(size.width, yPos), gridPaint);

      _drawText(canvas, yVal.toInt().toString(), Offset(10, yPos - 6), fontSize: 10);
    }

    // Draw Threshold Dashed Lines
    _drawDashedLine(canvas, usableHeight - (veryHigh / maxY * usableHeight), leftPadding, size.width, veryHighPaint);
    _drawDashedLine(canvas, usableHeight - (high / maxY * usableHeight), leftPadding, size.width, highPaint);
    _drawDashedLine(canvas, usableHeight - (low / maxY * usableHeight), leftPadding, size.width, lowPaint);
    _drawDashedLine(canvas, usableHeight - (veryLow / maxY * usableHeight), leftPadding, size.width, veryLowPaint);

    if (timeData.isEmpty) return;

    DateTime startTime;
    DateTime endTime;
    final now = DateTime.now();

    switch (rangeLabel) {
      case "D":
        startTime = DateTime(now.year, now.month, now.day + dateOffset);
        endTime = startTime.add(const Duration(days: 1));
        break;
      case "W":
        int dToMonday = now.weekday - 1;
        startTime = DateTime(now.year, now.month, now.day - dToMonday + (dateOffset * 7));
        endTime = startTime.add(const Duration(days: 7));
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

    final int totalMillis = endTime.difference(startTime).inMilliseconds;
    List<Offset> highPoints = [];
    List<Offset> lowPoints = [];

    // Calculate Coordinates
    for (int i = 0; i < timeData.length; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = elapsedMillis / (totalMillis > 0 ? totalMillis : 1);
      timeRatio = timeRatio.clamp(0.0, 1.0);

      double x = leftPadding + (usableWidth * timeRatio);
      
      // Animate the Y values sweeping upward
      double yHigh = usableHeight - ((highData[i] * progress) / maxY * usableHeight);
      highPoints.add(Offset(x, yHigh));

      if (rangeLabel != "D") {
        double yLow = usableHeight - ((lowData[i] * progress) / maxY * usableHeight);
        lowPoints.add(Offset(x, yLow));
      }
    }

    // ── Draw Data Lines ──
    final Paint linePaintHigh = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint linePaintLow = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (highPoints.isNotEmpty) {
      Path highPath = Path()..moveTo(highPoints.first.dx, highPoints.first.dy);
      for (int i = 1; i < highPoints.length; i++) {
        highPath.lineTo(highPoints[i].dx, highPoints[i].dy);
      }
      canvas.drawPath(highPath, linePaintHigh);
    }

    if (lowPoints.isNotEmpty && rangeLabel != "D") {
      for (int i = 0; i < lowPoints.length - 1; i++) {
        _drawDashedLineFromTo(canvas, lowPoints[i], lowPoints[i+1], linePaintLow);
      }
    }

    // ── Draw Data Dots ──
    final Paint dotPaint = Paint()..color = Colors.white;

    for (int i = 0; i < highPoints.length; i++) {
      canvas.drawCircle(highPoints[i], 3, dotPaint);
      if (lowPoints.isNotEmpty && rangeLabel != "D") {
        canvas.drawCircle(lowPoints[i], 3, dotPaint);
      }
    }

    // ── Draw X-Axis Labels ──
    List<double> labelRatios = [];
    List<String> labels = [];

    if (rangeLabel == "D") {
      labelRatios = [0.0, 0.25, 0.5, 0.75, 1.0];
      labels = ["12AM", "6AM", "12PM", "6PM", "12AM"];
    } else if (rangeLabel == "W") {
      labelRatios = [0.0, 0.285, 0.571, 0.857];
      labels = ["Mon", "Wed", "Fri", "Sun"];
    } else if (rangeLabel == "M") {
      labelRatios = [0.0, 0.33, 0.66, 1.0];
      labels = ["1st", "10th", "20th", "30th"];
    } else if (rangeLabel == "3M" || rangeLabel == "6M") {
      labelRatios = [0.0, 0.5, 1.0];
      labels = ["Start", "Mid", "End"];
    } else if (rangeLabel == "Y") {
      labelRatios = [0.0, 0.25, 0.5, 0.75, 1.0];
      labels = ["Jan", "Apr", "Jul", "Oct", "Dec"];
    }

    for (int i = 0; i < labelRatios.length; i++) {
      double xPos = leftPadding + (usableWidth * labelRatios[i]);
      _drawText(canvas, labels[i], Offset(xPos - 12, size.height - 20), fontSize: 10);
    }

    // ── Tooltip ──
    if (touchedIndex != null && touchedIndex! < timeData.length) {
      double tx = highPoints[touchedIndex!].dx;
      
      canvas.drawLine(
        Offset(tx, 0),
        Offset(tx, usableHeight),
        Paint()..color = Colors.white24..strokeWidth = 2,
      );

      final String dateStr = _formatTooltipDate(timeData[touchedIndex!]);
      final String highStr = "High: ${highData[touchedIndex!].toInt()} mg/dL";
      
      String labelText = "$dateStr\n$highStr";
      if (rangeLabel != "D") {
        labelText += "\nLow: ${lowData[touchedIndex!].toInt()} mg/dL";
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      double boxWidth = textPainter.width + 20;
      double boxHeight = textPainter.height + 15;
      
      double boxX = tx - (boxWidth / 2);
      if (boxX < leftPadding) boxX = leftPadding;
      if (boxX + boxWidth > size.width) boxX = size.width - boxWidth;
      
      double boxY = highPoints[touchedIndex!].dy - boxHeight - 15;
      if (boxY < 0) boxY = highPoints[touchedIndex!].dy + 15;

      final RRect tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(8),
      );

      canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xff1A3F6B));
      textPainter.paint(canvas, Offset(boxX + 10, boxY + 7.5));
    }
  }

  void _drawDashedLine(Canvas canvas, double y, double startX, double endX, Paint paint) {
    const double dashWidth = 6;
    const double dashSpace = 4;
    double currentX = startX;
    while (currentX < endX) {
      canvas.drawLine(Offset(currentX, y), Offset(currentX + dashWidth, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawDashedLineFromTo(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 6;
    const double dashSpace = 4;
    final double distance = (end - start).distance;
    final Offset vector = (end - start) / distance;
    
    double currentDistance = 0;
    while (currentDistance < distance) {
      canvas.drawLine(
        start + vector * currentDistance,
        start + vector * min(currentDistance + dashWidth, distance),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, {double fontSize = 12}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  String _formatTooltipDate(DateTime dt) {
    if (rangeLabel == "D") return "${dt.hour}:00";
    return "${dt.day}/${dt.month}";
  }

  @override
  bool shouldRepaint(covariant BloodGlucoseChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.touchedIndex != touchedIndex;
  }
}