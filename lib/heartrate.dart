import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/heartRateChartPainter.dart';
import 'package:temanu/heartRateSharePage.dart'; 
import 'package:temanu/assistantpage.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/button.dart';
import 'package:temanu/textbox.dart';
import 'package:temanu/theme.dart';

class HrReading {
  final DateTime time;
  final int bpm;
  HrReading(this.time, this.bpm);
}

class HeartRatePage extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const HeartRatePage({super.key, required this.baseUserData});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> with SingleTickerProviderStateMixin {
  int currentHr  = 0;
  int restingHr  = 0;
  bool _isLoadingChart = true;

  String selectedRange = "D";
  int? touchedIndex;
  int dateOffset = 0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  List<HrReading> _liveReadings = [];

  List<DateTime> aggTimes  = [];
  List<int>      aggMinBpm = [];
  List<int>      aggMaxBpm = [];

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
    
    // --- THE FIX: Chain fetch and force refresh cache ---
    _fetchHrData().then((_) => _generateAITip(forceRefresh: true));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── Fetch data ───────────────────────────────────────────────────────────

  Future<void> _fetchHrData() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Heart Rate');

    List<HrReading> fetchedData = [];
    for (var m in rawMetrics) {
      String dateStr = m['timestamp'] ?? DateTime.now().toIso8601String();
      if (!dateStr.endsWith('Z')) dateStr += 'Z'; 
      DateTime date = DateTime.parse(dateStr).toLocal();
      int hrValue = int.tryParse(m['value'].toString()) ?? 0;
      
      fetchedData.add(HrReading(date, hrValue));
    }

    if (mounted) {
      setState(() {
        _liveReadings = fetchedData;
        
        if (_liveReadings.isNotEmpty) {
          _liveReadings.sort((a, b) => a.time.compareTo(b.time));
          currentHr = _liveReadings.last.bpm;

          final todayReadings = _liveReadings.where((r) {
            final now = DateTime.now();
            return r.time.year == now.year &&
                   r.time.month == now.month &&
                   r.time.day   == now.day;
          }).toList();

          if (todayReadings.isNotEmpty) {
            restingHr = todayReadings.map((r) => r.bpm).reduce(min);
          } else {
            restingHr = _liveReadings.map((r) => r.bpm).reduce(min);
          }
        } else {
          currentHr = 0;
          restingHr = 0;
        }

        _isLoadingChart = false;
        _aggregateData(); 
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('latest_hr', currentHr);

      _animationController.reset();
      _animationController.forward();
    }
  }

  // ─── AI Tip ───────────────────────────────────────────────────────────────
  
  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached_hr'); 
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
      final userName = widget.baseUserData['preferred_name'] ?? widget.baseUserData['name'] ?? 'User';
      String prompt;

      if (currentHr == 0) {
        // --- THE ONBOARDING PROMPT (NO DATA) ---
        prompt = '''
          The user, $userName, just joined the app and hasn't logged any Heart Rate data yet. 
          Write a short, 2-sentence welcoming tip encouraging them to log their first reading 
          and briefly explaining why tracking heart rate is helpful.
        ''';
      } else {
        // --- THE CLINICAL PROMPT (HAS DATA) ---
        prompt = '''
          The user, $userName, has a current heart rate of $currentHr bpm and a resting heart rate of $restingHr bpm.
          Write a SHORT, 2-sentence encouraging insight or safety tip based exactly on these numbers.
        ''';
      }

      // --- NEW: Calls your secure FastAPI backend! ---
      final newTip = await ApiService.getAITip(prompt);
      
      if (mounted && newTip != null) {
        await prefs.setString('ai_tip_cached_hr', newTip);

        setState(() {
          _dynamicAiTip = newTip;
          _isLoadingTip = false;
        });
      } else {
        throw Exception("Backend returned null");
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
    final rawData  = _liveReadings;
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

  // --- THE FIX: Safe zoneText ---
  String get zoneText {
    if (currentHr == 0)    return "No Data";
    if (currentHr < 60)    return "Low";
    if (currentHr <= 100)  return "Normal";
    if (currentHr <= 120)  return "Elevated";
    return "High";
  }

  // --- THE FIX: Safe zoneColor ---
  Color get zoneColor {
    if (currentHr == 0) return AppTheme.textSecondary;
    switch (zoneText) {
      case "Normal":   return const Color(0xff4DA5E0);
      case "Low":      return Colors.deepPurple;
      case "Elevated": return Colors.orange;
      case "High":     return Colors.red;
      default:         return AppTheme.textSecondary;
    }
  }

  // ─── Interaction ──────────────────────────────────────────────────────────

  void _handleChartInteraction(Offset localPosition, double width) {
    const double leftPadding  = 55.0;
    final double usableWidth  = width - leftPadding - 20.0;
    final double dx           = localPosition.dx;

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

  // ─── Data entry ───────────────────────────────────────────────────────────

  void _addHrReading(int bpm) async {
    setState(() => _isLoadingChart = true);

    bool success = await ApiService.saveHealthMetric(
      metricType: "Heart Rate",
      value: bpm.toString(),
      unit: "bpm",
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('latest_hr', bpm);

      await _fetchHrData();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save data. Check your connection.')),
      );
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
            color: AppTheme.cardBackground.withValues(alpha: 0.95), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5), 
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Heart Rate Data',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter your heart rate reading in BPM.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: controller,
                hintText: 'Heart Rate (BPM)',
                prefixIcon: Icons.favorite_outline,
              ),
              const SizedBox(height: 25),
              MyRoundedButton(
                text: 'Save Reading',
                backgroundColor: AppTheme.primaryColor,
                textColor: AppTheme.textPrimary,
                onPressed: () {
                  final bpm = int.tryParse(controller.text);
                  if (bpm != null) _addHrReading(bpm);
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
        builder: (context) => HeartRateSharePage(
          currentHr: currentHr,
          restingHr: restingHr,
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
          "Heart Rate",
          style: TextStyle(color: AppTheme.primaryColor, fontSize: 25, fontWeight: FontWeight.w600),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: AppTheme.background.withValues(alpha: 0.5)),
          ),
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
                        _buildCurrentHrAndAddData(),
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
                  _buildCurrentHrAndAddData(),
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

  Widget _buildCurrentHrAndAddData() {
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
                // --- THE FIX: Double dashes when empty ---
                Text(
                  currentHr > 0 ? "$currentHr" : "--",
                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Text("bpm", style: TextStyle(color: Colors.white70, fontSize: 20)),
              ],
            ),
            Text(zoneText, style: TextStyle(color: zoneColor, fontSize: 16)),
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
            setState(() { dateOffset--; touchedIndex = null; _aggregateData(); });
            _animationController.reset();
            _animationController.forward();
          },
        ),
        Text(dateRangeLabel, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(
          icon: Icon(Icons.chevron_right, color: dateOffset < 0 ? Colors.white : Colors.white38, size: 30),
          onPressed: dateOffset < 0 ? () {
            setState(() { dateOffset++; touchedIndex = null; _aggregateData(); });
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
                    ),
                  );
                },
              );
            },
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
        children: ["D","W","M","3M","6M","Y"].map(_filterButton).toList(),
      ),
    );
  }

  Widget _buildInfoCards({required bool isWide}) {
    // --- THE FIX: Format empty states safely ---
    final String currStr = currentHr > 0 ? "$currentHr\nbpm" : "--\nbpm";
    final String restStr = restingHr > 0 ? "$restingHr\nbpm" : "--\nbpm";

    if (isWide) {
      return Column(
        children: [
          _infoCard("Current HR", currStr, isWide: true),
          const SizedBox(height: 16),
          _infoCard("Resting HR", restStr, isWide: true),
          const SizedBox(height: 16),
          _zoneCard("Zone", zoneText, isWide: true),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _infoCard("Current HR", currStr)),
          const SizedBox(width: 8),
          Expanded(child: _infoCard("Resting HR", restStr)),
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
        updatedData['heartRate'] = currentHr.toString();
        
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
          Text(value, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: TextStyle(color: selected ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 15, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}