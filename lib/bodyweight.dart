import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart'; // <-- NEW: Import your API service
import 'package:temanu/assistantpage.dart';
import 'package:temanu/shareWeightHighlightPage.dart';
import 'package:temanu/weightLineChartPainter.dart';

// <-- NEW: We define WeightReading here so we don't need the Mock file anymore!
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
  double currentWeight = 0.0; // Will be overwritten by DB
  double goalWeight = 80.0;
  double heightCm = 186.0;
  String selectedRange = "W";
  int dateOffset = 0;

  int? touchedIndex; 

  late AnimationController _animationController;
  late Animation<double> _animation;

  String _dynamicAiTip = "Analyzing your body weight data...";
  bool _isLoadingTip = true;
  bool _isLoadingChart = true; // <-- NEW: Track when the chart is fetching data

  // Master lists for the graph
  List<WeightReading> _liveReadings = []; // <-- NEW: Holds data from Railway
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
    
    final weightParsed = double.tryParse(widget.baseUserData['weight'] ?? '');
    if (weightParsed != null) currentWeight = weightParsed;

    // <-- NEW: Fetch live data when the page opens
    _fetchWeightData(); 
    _generateAITip();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── NEW: Fetch data from Railway ─────────────────────────────────────────
  Future<void> _fetchWeightData() async {
    setState(() => _isLoadingChart = true);

    final rawMetrics = await ApiService.getHealthMetrics(metricType: 'Body Weight');

    List<WeightReading> fetchedData = [];
    for (var m in rawMetrics) {
      // 🎯 CHANGED THIS LINE to match your database exactly:
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

  // ─── AI Tip Generator ─────────────────────────────────────────────────────
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
    // <-- NEW: Use the live readings instead of the Mock file
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
    if (h == 0) return 0;
    return currentWeight / (h * h);
  }

  double get changeWeight {
    if (aggWeights.length < 2) return 0;
    return aggWeights.last - aggWeights.first;
  }

  // ─── NEW: Send data to Railway ──────────────────────────────────────────
  void addWeightData(double value) async { 
    setState(() => _isLoadingChart = true); // Show loading spinner
    
    // 1. Send it to the backend
    bool success = await ApiService.saveHealthMetric(
      metricType: "Body Weight", 
      value: value.toString(), 
      unit: "kg"
    );

    if (success) {
      // 2. Save it locally so the AI Assistant knows immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latest_weight', value);

      // 3. Re-fetch the data to rebuild the graph and generate a new tip
      await _fetchWeightData();
      _generateAITip(forceRefresh: true);
    } else {
      setState(() => _isLoadingChart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save weight data. Check your connection.')),
      );
    }
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
              // <-- NEW: Show a spinner while the graph data is loading
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
                              painter: WeightLineChartPainter(aggTimes, aggWeights, selectedRange, touchedIndex, _animation.value, dateOffset)
                            ),
                          );
                        },
                      );
                    }
                  ),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: infoCard("Goal", goalWeight.toStringAsFixed(0))),
                const SizedBox(width: 8),
                Expanded(child: infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg")),
                const SizedBox(width: 8),
                Expanded(child: infoCard("BMI", bmi.toStringAsFixed(1))),
              ],
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: () {
                final updatedData = Map<String, dynamic>.from(widget.baseUserData);
                updatedData['weight'] = currentWeight.toString();
                
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
                                "Analyzing your body weight trends...", 
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
            const SizedBox(height: 24),
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15)),
      ),
    );
  }
}