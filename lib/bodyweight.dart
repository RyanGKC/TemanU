import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart'; 
import 'package:temanu/assistantpage.dart';
import 'package:temanu/shareWeightHighlightPage.dart';
import 'package:temanu/button.dart';
import 'package:temanu/textbox.dart';
import 'package:temanu/theme.dart';

class WeightReading {
  final DateTime time;
  final double weight;
  WeightReading(this.time, this.weight);
}

class BodyWeightPage extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const BodyWeightPage({super.key, required this.baseUserData});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> with SingleTickerProviderStateMixin {
  double currentWeight = 0.0; 
  double goalWeight = 80.0;
  double heightCm = 186.0;
  String selectedRange = "W";
  int dateOffset = 0;

  int? touchedIndex; 

  late AnimationController _animationController;
  late Animation<double> _animation;

  String _dynamicAiTip = "Analyzing your body weight data...";
  bool _isLoadingTip = true;
  bool _isLoadingChart = true; 

  List<WeightReading> _liveReadings = []; 
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
    
    final heightParsed = double.tryParse(widget.baseUserData['height'] ?? '');
    if (heightParsed != null) heightCm = heightParsed;
    
    _fetchWeightData().then((_) {
      _generateAITip();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeightData() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Body Weight');

    List<WeightReading> fetchedData = [];
    for (var m in rawMetrics) {
      String dateStr = m['timestamp'] ?? DateTime.now().toIso8601String();
      
      if (!dateStr.endsWith('Z')) dateStr += 'Z'; 
      DateTime date = DateTime.parse(dateStr).toLocal();
      double weight = double.tryParse(m['value'].toString()) ?? 0.0;
      
      fetchedData.add(WeightReading(date, weight));
    }

    if (mounted) {
      setState(() {
        _liveReadings = fetchedData;
        
        if (_liveReadings.isNotEmpty) {
          _liveReadings.sort((a, b) => a.time.compareTo(b.time));
          currentWeight = _liveReadings.last.weight;
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
      final cachedTip = prefs.getString('ai_tip_cached_bw'); 
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
      final bodyGoal = widget.baseUserData['bodyGoal'] ?? 'maintain';

      final prompt = '''
        You are a concise health AI assistant. The user, $userName, has a current weight of ${currentWeight.toStringAsFixed(1)} kg and a BMI of ${bmi.toStringAsFixed(1)}. 
        Their overall goal is to $bodyGoal their weight.
        In the selected time period, their weight has changed by ${changeWeight > 0 ? '+' : ''}${changeWeight.toStringAsFixed(1)} kg.
        
        Write a SHORT, 2-sentence encouraging insight or tip based exactly on these numbers and their goal. 
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_bw', newTip);

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
    Map<DateTime, List<WeightReading>> grouped = {};
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
    aggWeights.clear();

    for (var key in sortedKeys) {
      var readings = grouped[key]!;
      aggTimes.add(key); 
      double sum = readings.map((e) => e.weight).reduce((a, b) => a + b);
      aggWeights.add(sum / readings.length);
    }
  }

  void _handleChartInteraction(Offset localPosition, double width) {
    const double leftPadding = 58.0;
    final double usableWidth = width - leftPadding - 20.0;
    final double dx = localPosition.dx;

    if (dx < leftPadding - 15 || dx > width - 5) {
      if (touchedIndex != null) setState(() => touchedIndex = null);
      return;
    }

    if (aggTimes.isEmpty) return;

    DateTime effectiveStartTime = _startTime;
    DateTime effectiveEndTime = _endTime;

    switch (selectedRange) {
      case "D": effectiveEndTime = _startTime.add(const Duration(hours: 24)); break;
      case "W": effectiveEndTime = _startTime.add(const Duration(days: 6)); break;
      case "M": effectiveEndTime = DateTime(_startTime.year, _startTime.month + 1, 0); break; 
      case "3M": effectiveEndTime = DateTime(_startTime.year, _startTime.month + 2, 1); break;
      case "6M": effectiveEndTime = DateTime(_startTime.year, _startTime.month + 5, 1); break;
      case "Y": effectiveEndTime = DateTime(_startTime.year, 12, 1); break;
    }

    final totalMillis = effectiveEndTime.difference(effectiveStartTime).inMilliseconds;
    
    int? closestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < aggTimes.length; i++) {
      final elapsedMillis = aggTimes[i].difference(effectiveStartTime).inMilliseconds;
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

  double get bmi {
    final h = heightCm / 100;
    if (h == 0) return 0;
    return currentWeight / (h * h);
  }

  double get changeWeight {
    if (aggWeights.length < 2) return 0;
    return aggWeights.last - aggWeights.first;
  }

  void addWeightData(double value) async { 
    setState(() => _isLoadingChart = true); 
    
    bool success = await ApiService.saveHealthMetric(
      metricType: "Body Weight", 
      value: value.toString(), 
      unit: "kg"
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latest_weight', value);

      await _fetchWeightData();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save weight data. Check your connection.')),
      );
    }
  }

  // --- UPDATED: Glossy Dialog for Adding Weight Data ---
   void showAddDataDialog() {
    final weightController = TextEditingController();
 
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
                'Add Weight Data',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter your latest body weight reading in kg.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: weightController,
                hintText: 'Value (kg)',
                prefixIcon: Icons.monitor_weight_outlined,
              ),
              const SizedBox(height: 25),
              MyRoundedButton(
                text: 'Save Reading',
                backgroundColor: AppTheme.primaryColor,
                textColor: AppTheme.textPrimary,
                onPressed: () {
                  final val = double.tryParse(weightController.text);
                  if (val != null && val > 0) addWeightData(val);
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
        builder: (context) => ShareWeightHighlightPage( // Updated to pass more data
          currentWeight: currentWeight,
          changeValue: changeWeight,
          bmi: bmi,
          goalWeight: goalWeight,
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
          "Body Weight",
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
            onPressed: openSharePage,
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // --- THE RESPONSIVE TRIGGER ---
          bool isWideScreen = constraints.maxWidth > 850;

          if (isWideScreen) {
            // ==========================================
            // DESKTOP / TABLET LAYOUT (2 Columns)
            // ==========================================
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Chart & Filters
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildDateNavigator(),
                        const SizedBox(height: 16),
                        _buildChart(),
                        const SizedBox(height: 16),
                        _buildFilters(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // RIGHT COLUMN: Stats & AI Sidebar
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentWeightAndAddData(),
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
            // ==========================================
            // MOBILE LAYOUT (Single Column)
            // ==========================================
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCurrentWeightAndAddData(),
                  const SizedBox(height: 18),
                  _buildDateNavigator(),
                  const SizedBox(height: 10),
                  _buildChart(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  _buildInfoCards(isWide: false),
                  const SizedBox(height: 16),
                  _buildAiTips(),
                  const SizedBox(height: 24),
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

  Widget _buildCurrentWeightAndAddData() {
    return Row(
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
                          painter: WeightLineChartPainter(aggTimes, aggWeights, selectedRange, touchedIndex, _animation.value, dateOffset),
                        ),
                      ),
                    );
                  },
                );
              }),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withOpacity(0.1),
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
    );
  }

  Widget _buildInfoCards({required bool isWide}) {
    if (isWide) {
      // Stack vertically in the desktop sidebar
      return Column(
        children: [
          infoCard("Goal", goalWeight.toStringAsFixed(0), isWide: true),
          const SizedBox(height: 16),
          infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg", isWide: true),
          const SizedBox(height: 16),
          infoCard("BMI", bmi.toStringAsFixed(1), isWide: true),
        ],
      );
    } else {
      // Row layout for mobile
      return Row(
        children: [
          Expanded(child: infoCard("Goal", goalWeight.toStringAsFixed(0))),
          const SizedBox(width: 8),
          Expanded(child: infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg")),
          const SizedBox(width: 8),
          Expanded(child: infoCard("BMI", bmi.toStringAsFixed(1))),
        ],
      );
    }
  }

  Widget _buildAiTips() {
    return InkWell(
      onTap: () {
        final updatedData = Map<String, dynamic>.from(widget.baseUserData);
        updatedData['weight'] = currentWeight.toString();

        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AssistantPage(userData: updatedData)));
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
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                        child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("Analyzing your body weight trends...",
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  )
                : Text(_dynamicAiTip,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget infoCard(String title, String value, {bool isWide = false}) {
    return Container(
      height: 95,
      width: isWide ? double.infinity : null, // Stretch to fill column on wide screens
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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

        _generateAITip(forceRefresh: true);

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
            style: TextStyle(
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER 
// ─────────────────────────────────────────────────────────────────────────
class ChartLabel {
  final String text;
  final DateTime time;
  ChartLabel(this.text, this.time);
}

class WeightLineChartPainter extends CustomPainter {
  final List<DateTime> timeData; 
  final List<double> weightData; 
  final String selectedRange;
  final int? touchedIndex;
  final double progress;
  final int dateOffset;

  WeightLineChartPainter(this.timeData, this.weightData, this.selectedRange, this.touchedIndex, this.progress, this.dateOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = AppTheme.textPrimary..strokeWidth = 2..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = AppTheme.primaryColor..style = PaintingStyle.fill;
    final gridPaint = Paint()..color = AppTheme.textSecondary.withOpacity(0.5)..strokeWidth = 1;
    const textStyle = TextStyle(color: AppTheme.textPrimary, fontSize: 12);

    final axis = _buildDynamicAxis(weightData);
    final minAxis = axis.$1;
    final maxAxis = axis.$2;
    final range = maxAxis - minAxis == 0 ? 1 : maxAxis - minAxis;

    const leftPadding = 58.0;
    const bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;
    final usableWidth = size.width - leftPadding - 20;

    // Grid
    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * i / 5;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final value = maxAxis - (range * i / 5);
      final tp = TextPainter(text: TextSpan(text: "${value.toStringAsFixed(1)}kg", style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, y - 8));
    }

    // --- GAP FIX: Time Bounds Calculation ---
    final now = DateTime.now();
    DateTime startTime;
    DateTime endTime; 
    DateTime effectiveEndTime; 

    switch (selectedRange) {
      case "D": 
        startTime = DateTime(now.year, now.month, now.day + dateOffset); 
        endTime = startTime.add(const Duration(days: 1)); 
        effectiveEndTime = startTime.add(const Duration(hours: 24));
        break;
      case "W": 
        int dToM = now.weekday - 1; 
        startTime = DateTime(now.year, now.month, now.day - dToM + (dateOffset * 7)); 
        endTime = startTime.add(const Duration(days: 7)); 
        effectiveEndTime = startTime.add(const Duration(days: 6));
        break;
      case "M": 
        startTime = DateTime(now.year, now.month + dateOffset, 1); 
        endTime = DateTime(now.year, now.month + dateOffset + 1, 1); 
        effectiveEndTime = DateTime(startTime.year, startTime.month + 1, 0); 
        break;
      case "3M": 
        startTime = DateTime(now.year, now.month - 2 + (dateOffset * 3), 1); 
        endTime = DateTime(now.year, now.month + 1 + (dateOffset * 3), 1); 
        effectiveEndTime = DateTime(startTime.year, startTime.month + 2, 1);
        break;
      case "6M": 
        startTime = DateTime(now.year, now.month - 5 + (dateOffset * 6), 1); 
        endTime = DateTime(now.year, now.month + 1 + (dateOffset * 6), 1); 
        effectiveEndTime = DateTime(startTime.year, startTime.month + 5, 1);
        break;
      case "Y": 
        startTime = DateTime(now.year + dateOffset, 1, 1); 
        endTime = DateTime(now.year + dateOffset + 1, 1, 1); 
        effectiveEndTime = DateTime(startTime.year, 12, 1);
        break;
      default: 
        startTime = DateTime(now.year, now.month, now.day); 
        endTime = startTime.add(const Duration(days: 1));
        effectiveEndTime = startTime.add(const Duration(hours: 24));
    }

    final totalMillis = effectiveEndTime.difference(startTime).inMilliseconds;

    // Draw Line & Dots
    final path = Path();
    for (int i = 0; i < timeData.length; i++) {
      final elapsedMillis = timeData[i].difference(startTime).inMilliseconds;
      double timeRatio = totalMillis > 0 ? elapsedMillis / totalMillis : 0;
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      
      final targetY = chartHeight - ((weightData[i] - minAxis) / range) * chartHeight;
      final y = chartHeight - ((chartHeight - targetY) * progress);

      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
    if (timeData.isNotEmpty) canvas.drawPath(path, linePaint);

    // Dynamic Labels
    final labels = _getDynamicLabels(selectedRange, startTime, endTime);
    for (var label in labels) {
      final elapsedMillis = label.time.difference(startTime).inMilliseconds;
      double timeRatio = totalMillis > 0 ? elapsedMillis / totalMillis : 0;
      timeRatio = timeRatio.clamp(0.0, 1.0); 
      final x = leftPadding + (usableWidth * timeRatio);
      final tp = TextPainter(text: TextSpan(text: label.text, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // Tooltip Highlight
    if (touchedIndex != null && touchedIndex! < timeData.length) {
      final elapsedMillis = timeData[touchedIndex!].difference(startTime).inMilliseconds;
      double timeRatio = totalMillis > 0 ? elapsedMillis / totalMillis : 0;
      timeRatio = timeRatio.clamp(0.0, 1.0);
      final x = leftPadding + (usableWidth * timeRatio);
      final y = chartHeight - ((weightData[touchedIndex!] - minAxis) / range) * chartHeight;
      
      canvas.drawCircle(Offset(x, y), 8, Paint()..color = AppTheme.textPrimary);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = AppTheme.background);
      _drawTooltip(canvas, size, x, y, weightData[touchedIndex!], timeData[touchedIndex!]);
    }
  }

  (double, double) _buildDynamicAxis(List<double> values) {
    if (values.isEmpty) return (0.0, 10.0); 
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);
    double minAxis = (minVal - 1).roundToDouble();
    double maxAxis = (maxVal + 1).roundToDouble();
    if (minAxis >= maxAxis) { minAxis -= 1; maxAxis += 1; }
    return (minAxis, maxAxis);
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
      case "W": return List.generate(7, (i) { DateTime t = start.add(Duration(days: i)); return ChartLabel(weekdays[t.weekday - 1], t); });
      case "M": 
        int daysInMonth = DateTime(start.year, start.month + 1, 0).day; 
        return List.generate(5, (i) { 
          DateTime t = start.add(Duration(days: (i * (daysInMonth - 1) / 4).round())); 
          return ChartLabel("${t.day}/${t.month}", t); 
        });
      case "3M": return List.generate(3, (i) { DateTime t = DateTime(start.year, start.month + i, 1); return ChartLabel(months[t.month - 1], t); });
      case "6M": return List.generate(6, (i) { DateTime t = DateTime(start.year, start.month + i, 1); return ChartLabel(months[t.month - 1], t); });
      case "Y": return List.generate(12, (i) { 
        DateTime t = DateTime(start.year, start.month + i, 1); 
        return ChartLabel(singleLetterMonths[t.month - 1], t); 
      });
      default: return [];
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double y, double value, DateTime date) {
    const List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    String dateStr;
    if (selectedRange == "D") {
      String period = date.hour >= 12 ? "PM" : "AM";
      int h = date.hour % 12; if (h == 0) h = 12;
      dateStr = "${date.day} ${months[date.month - 1]}, $h:00 $period"; 
    } else if (selectedRange == "W" || selectedRange == "M") {
      dateStr = "${date.day} ${months[date.month - 1]}"; 
    } else if (selectedRange == "3M" || selectedRange == "6M") {
      final weekEnd = date.add(const Duration(days: 6));
      dateStr = "${date.day} ${months[date.month - 1]} - ${weekEnd.day} ${months[weekEnd.month - 1]}";
    } else {
      dateStr = "${months[date.month - 1]} ${date.year}"; 
    }

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: "$dateStr\n", 
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)
        ),
        TextSpan(
          text: "${value.toStringAsFixed(1)} kg", 
          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.bold)
        ),
      ]
    );

    final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();

    final boxWidth = textPainter.width + 24;
    final boxHeight = textPainter.height + 16;
    
    double rectLeft = (x - boxWidth / 2).clamp(58.0, size.width - boxWidth);
    double rectTop = y - boxHeight - 15;
    if (rectTop < 0) rectTop = y + 15; 

    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(rectLeft, rectTop, boxWidth, boxHeight), const Radius.circular(8));
    
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = Colors.black26); 
    canvas.drawRRect(rrect, Paint()..color = AppTheme.background); 
    textPainter.paint(canvas, Offset(rectLeft + 12, rectTop + 8)); 
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}