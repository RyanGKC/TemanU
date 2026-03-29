import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart';
import 'package:temanu/oxygenSaturationChartPainter.dart'; 
import 'package:temanu/oxygenSaturationSharePage.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/button.dart';
import 'package:temanu/textbox.dart';
import 'package:temanu/theme.dart';

class SpO2Reading {
  final DateTime time;
  final int spo2;
  SpO2Reading(this.time, this.spo2);
}

class OxygenSaturationPage extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const OxygenSaturationPage({super.key, required this.baseUserData});

  @override
  State<OxygenSaturationPage> createState() => _OxygenSaturationPageState();
}

class _OxygenSaturationPageState extends State<OxygenSaturationPage> with SingleTickerProviderStateMixin {
  int currentSpO2 = 0;
  int avgSpO2 = 0;
  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  String _dynamicAiTip = "Analyzing your oxygen data...";
  bool _isLoadingTip = true;
  bool _isLoadingChart = true;

  List<SpO2Reading> _liveReadings = []; 

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
  List<int> aggMinSpO2 = [];
  List<int> aggMaxSpO2 = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    
    // --- THE FIX: Chain fetch and force refresh cache ---
    _fetchSpO2Data().then((_) => _generateAITip(forceRefresh: true));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpO2Data() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Oxygen Saturation');

    List<SpO2Reading> fetchedData = [];
    int sumForToday = 0;
    int countForToday = 0;

    for (var m in rawMetrics) {
      String dateStr = m['timestamp'] ?? DateTime.now().toIso8601String();
      if (!dateStr.endsWith('Z')) dateStr += 'Z'; 
      DateTime date = DateTime.parse(dateStr).toLocal();
      int spo2Value = int.tryParse(m['value'].toString()) ?? 0;
      
      fetchedData.add(SpO2Reading(date, spo2Value));

      if (date.year == DateTime.now().year && 
          date.month == DateTime.now().month && 
          date.day == DateTime.now().day) {
        sumForToday += spo2Value;
        countForToday++;
      }
    }

    if (mounted) {
      setState(() {
        _liveReadings = fetchedData;
        
        if (_liveReadings.isNotEmpty) {
          _liveReadings.sort((a, b) => a.time.compareTo(b.time));
          currentSpO2 = _liveReadings.last.spo2;
          avgSpO2 = countForToday > 0 ? (sumForToday / countForToday).round() : currentSpO2;
        } else {
          // --- THE FIX: Use 0 for empty state ---
          currentSpO2 = 0;
          avgSpO2 = 0;
        }

        _isLoadingChart = false;
        _aggregateData(); 
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached_spo2'); 
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
      String prompt;

      // --- THE FIX: Handle empty state gracefully ---
      if (currentSpO2 == 0) {
        prompt = '''
          The user, $userName, just joined the app and hasn't logged any Oxygen Saturation (SpO2) data yet. 
          Write a short, 2-sentence welcoming tip encouraging them to log their first reading 
          and briefly explaining why tracking blood oxygen is helpful. Keep it under 120 characters. 
          Do not use asterisks or markdown formatting.
        ''';
      } else {
        prompt = '''
          You are a concise health AI assistant. The user, $userName, has a current blood oxygen saturation (SpO2) of $currentSpO2% and a daily average of $avgSpO2%.
          
          Write a SHORT, 2-sentence encouraging insight or safety tip based exactly on these numbers. 
          Keep it under 120 characters. Do not use asterisks or markdown formatting.
        ''';
      }

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_spo2', newTip);

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
    final rawData = _liveReadings; 
    Map<DateTime, List<SpO2Reading>> grouped = {};

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
    aggMinSpO2.clear();
    aggMaxSpO2.clear();

    for (var key in sortedKeys) {
      var readings = grouped[key]!;
      aggTimes.add(key); 
      
      int minVal = readings.map((e) => e.spo2).reduce(min);
      int maxVal = readings.map((e) => e.spo2).reduce(max);

      aggMinSpO2.add(minVal);
      aggMaxSpO2.add(maxVal);
    }
  }

  // --- THE FIX: Safe zoneText ---
  String get zoneText {
    if (currentSpO2 == 0) return "No Data"; 
    if (currentSpO2 >= 95) return "Normal";
    if (currentSpO2 >= 90) return "Borderline";
    return "Low"; 
  }

  // --- THE FIX: Safe zoneColor ---
  Color get zoneColor {
    if (currentSpO2 == 0) return AppTheme.textSecondary;
    switch (zoneText) {
      case "Normal": return AppTheme.success;
      case "Borderline": return AppTheme.warning;
      case "Low": return AppTheme.primaryColor;
      default: return AppTheme.success;
    }
  }

  void _handleChartInteraction(Offset localPosition, double width) {
    const double leftPadding = 55.0;
    final double usableWidth = width - leftPadding - 20.0;
    final double dx = localPosition.dx;

    if (dx < leftPadding - 15 || dx > width - 5) {
      if (touchedIndex != null) setState(() => touchedIndex = null);
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
      double timeRatio = totalMillis > 0 ? elapsedMillis / totalMillis : 0;
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      
      final distance = (x - dx).abs();
      if (distance < 20 && distance < minDistance) { 
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (touchedIndex != closestIndex) {
      setState(() => touchedIndex = closestIndex);
    }
  }

  void addSpO2Data(int spo2) async { 
    setState(() => _isLoadingChart = true);
    
    bool success = await ApiService.saveHealthMetric(
      metricType: "Oxygen Saturation", 
      value: spo2.toString(), 
      unit: "%"
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('latest_spo2', spo2);

      await _fetchSpO2Data();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save data. Check your connection.')),
      );
    }
  }

  void showAddDataDialog() {
    final spo2Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground.withValues(alpha: 0.95), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5), 
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Oxygen Data',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter your blood oxygen saturation reading in %.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: spo2Controller,
                hintText: 'SpO2 (%)',
                prefixIcon: Icons.opacity,
              ),
              const SizedBox(height: 25),
              MyRoundedButton(
                text: 'Save Reading',
                backgroundColor: AppTheme.primaryColor,
                textColor: AppTheme.textPrimary,
                onPressed: () {
                  final spo2 = int.tryParse(spo2Controller.text);
                  if (spo2 != null && spo2 <= 100 && spo2 > 0) addSpO2Data(spo2);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openSharePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OxygenSaturationSharePage(
          currentSpO2: currentSpO2,
          avgSpO2: avgSpO2,
          zone: zoneText,
          rangeName: fullRangeName,
          dateRangeLabel: dateRangeLabel,
          userName: widget.baseUserData['preferred_name'] ?? widget.baseUserData['name'] ?? 'User',
        ),
      ),
    );
  }

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
          "Oxygen Saturation",
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: AppTheme.background.withValues(alpha: 0.5)) 
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: openSharePage,
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth > 850;

          if (isWideScreen) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewHeader(),
                        const SizedBox(height: 10),
                        _buildDateNavigator(),
                        const SizedBox(height: 10),
                        _buildChart(), 
                        const SizedBox(height: 16),
                        _buildFilters(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentSpO2AndAddData(),
                        const SizedBox(height: 32),
                        _buildInfoCards(isWide: true), 
                        const SizedBox(height: 24),
                        _buildAiTips(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCurrentSpO2AndAddData(),
                  const SizedBox(height: 18),
                  _buildOverviewHeader(),
                  const SizedBox(height: 10),
                  _buildDateNavigator(),
                  const SizedBox(height: 10),
                  _buildChart(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 24),
                  _buildInfoCards(isWide: false),
                  const SizedBox(height: 16),
                  _buildAiTips(),
                  const SizedBox(height: 80),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // ==========================================
  // UI HELPER METHODS
  // ==========================================

  Widget _buildCurrentSpO2AndAddData() {
    return Row(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      currentSpO2 == 0 ? "--" : "$currentSpO2",
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Text("%", style: TextStyle(color: Colors.white70, fontSize: 20)), // <-- Fixed size & weight
                  ],
                ),
              ],
            ),
            Text(zoneText, style: TextStyle(color: zoneColor, fontSize: 16)),
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
    );
  }

  Widget _buildOverviewHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "$fullRangeName Overview",
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDateNavigator() {
    return Row(
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
    );
  }

  Widget _buildChart() {
    return Container(
      height: 317,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
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
                        painter: OxygenSaturationChartPainter(
                          timeData: aggTimes,
                          minSpO2Data: aggMinSpO2,
                          maxSpO2Data: aggMaxSpO2,
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
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _filterButton("D"),
          _filterButton("W"),
          _filterButton("M"),
          _filterButton("3M"),
          _filterButton("6M"),
          _filterButton("Y"),
        ],
      ),
    );
  }

  Widget _buildInfoCards({required bool isWide}) {
    // --- THE FIX: Hide 0 nicely ---
    final String currStr = currentSpO2 == 0 ? "--%" : "$currentSpO2%";
    final String avgStr = avgSpO2 == 0 ? "--%" : "$avgSpO2%";

    if (isWide) {
      return Column(
        children: [
          _infoCard("Current", currStr, isWide: true),
          const SizedBox(height: 16),
          _infoCard("Daily Avg", avgStr, isWide: true),
          const SizedBox(height: 16),
          _zoneCard("Zone", zoneText, isWide: true),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _infoCard("Current", currStr)), 
          const SizedBox(width: 8),
          Expanded(child: _infoCard("Daily Avg", avgStr)),
          const SizedBox(width: 8),
          Expanded(child: _zoneCard("Zone", zoneText)),
        ],
      );
    }
  }

  Widget _buildAiTips() {
    return InkWell(
      onTap: () {
        final updatedData = Map<String, dynamic>.from(widget.baseUserData);
        updatedData['oxygenSaturation'] = currentSpO2.toString();
        
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
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
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
                        "Analyzing your oxygen data...", 
                        style: const TextStyle(color: Colors.white70, fontSize: 14)
                      ),
                    ),
                  ],
                )
              : Text(_dynamicAiTip, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value, {bool isWide = false}) {
    return Container(
      height: 95,
      width: isWide ? double.infinity : null, 
      decoration: BoxDecoration(
        color: AppTheme.cardBackground, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
      ),
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

  Widget _zoneCard(String title, String value, {bool isWide = false}) {
    return Container(
      height: 95,
      width: isWide ? double.infinity : null, 
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

  Widget _filterButton(String label) {
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
          color: selected ? AppTheme.primaryColor : Colors.transparent, 
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 15, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}