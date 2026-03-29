import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/fitbitService.dart'; 
import 'package:temanu/activitySharePage.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/theme.dart';

class Activity extends StatefulWidget {
  final Map<String, dynamic> baseUserData;

  const Activity({super.key, required this.baseUserData});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isLoadingComparisons = true;
  bool _fitbitConnected = false;
  bool _isRefreshing = false;
  late AnimationController _refreshIconController;

  int currentSteps = 0;
  int averageSteps = 0;
  int _latestIntradaySteps = 0; 
  
  int stepGoal = 10000;

  List<String> dailyLabels = ['12AM', '4AM', '8AM', '12PM', '4PM', '8PM', '12AM'];
  List<double> dailyValues = [0, 0, 0, 0, 0, 0, 0];

  List<String> weeklyLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<double> weeklyValues = [0, 0, 0, 0, 0, 0, 0];

  List<String> monthlyLabels = [];
  List<double> monthlyValues = [];

  List<String> threeMonthLabels = [];
  List<double> threeMonthValues = [];
  List<String> threeMonthTooltipLabels = [];

  List<String> sixMonthLabels = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
  List<double> sixMonthValues = [0, 0, 0, 0, 0, 0];
  List<String> sixMonthTooltipLabels = [];

  List<String> yearlyLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  List<double> yearlyValues = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  List<String> monthlyAverageLabels = ['Last', 'This'];
  List<double> monthlyAverageValues = [0, 0];

  List<String> yearlyAverageLabels = ['Last', 'This'];
  List<double> yearlyAverageValues = [0, 0];

  String selectedRange = "D";
  int dateOffset = 0;

  String _dynamicAiTip = "Analyzing your activity data...";
  bool _isLoadingTip = true;

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadGoal(); 
    _fetchLiveFitbitData(forceRefresh: true).then((_) {
      _generateAITip();
    });
    
    _fetchComparisonData(forceRefresh: true);
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    super.dispose();
  }

  // ==========================================
  // FITBIT CONNECTION
  // ==========================================

  void _showFitbitConnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.watch, color: AppTheme.primaryColor, size: 40),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Connect Your Health Data",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Link your Fitbit account to automatically track your daily steps directly on your dashboard.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context), 
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.5), width: 1.5), 
                              ),
                              alignment: Alignment.center,
                              child: const Text("Not Now", style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context); 
                              String? newToken = await FitbitService.getValidToken();
                              if (newToken != null) {
                                _fetchLiveFitbitData(forceRefresh: true);
                                _fetchComparisonData(forceRefresh: true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: const Text("Connect", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // FITBIT REFRESH
  // ==========================================

  Future<void> _handleRefreshFitbit() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshIconController.repeat();

    await Future.wait([
      _fetchLiveFitbitData(forceRefresh: true),
      _fetchComparisonData(forceRefresh: true),
    ]);
    _generateAITip(forceRefresh: true);

    _refreshIconController.stop();
    _refreshIconController.reset();
    if (mounted) setState(() => _isRefreshing = false);
  }

  // ==========================================
  // GOAL MANAGEMENT
  // ==========================================
  
  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      stepGoal = prefs.getInt('step_goal') ?? 10000;
    });
  }

  void _showEditGoalDialog() {
    final controller = TextEditingController(text: stepGoal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Set Daily Step Goal", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Steps (e.g., 10000)",
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final newGoal = int.tryParse(controller.text);
              if (newGoal != null && newGoal > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('step_goal', newGoal);
                setState(() => stepGoal = newGoal);
                _generateAITip(forceRefresh: true); 
              }
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // ==========================================
  // PERFECT CALENDAR BOUNDARIES
  // ==========================================

  DateTime get now => DateTime.now();

  DateTime get rangeStart {
    if (selectedRange == "D") return DateTime(now.year, now.month, now.day + dateOffset);
    if (selectedRange == "W") {
      DateTime currentMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return currentMonday.add(Duration(days: dateOffset * 7));
    }
    if (selectedRange == "M") return DateTime(now.year, now.month + dateOffset, 1);
    if (selectedRange == "3M") return DateTime(now.year, now.month - 2 + (dateOffset * 3), 1); 
    if (selectedRange == "6M") return DateTime(now.year, now.month - 5 + (dateOffset * 6), 1);
    if (selectedRange == "Y") return DateTime(now.year + dateOffset, 1, 1);
    return now;
  }

  DateTime get rangeEnd {
    if (selectedRange == "D") return rangeStart;
    if (selectedRange == "W") return rangeStart.add(const Duration(days: 6)); 
    if (selectedRange == "M") return DateTime(rangeStart.year, rangeStart.month + 1, 0); 
    if (selectedRange == "3M") return DateTime(rangeStart.year, rangeStart.month + 3, 0); 
    if (selectedRange == "6M") return DateTime(rangeStart.year, rangeStart.month + 6, 0); 
    if (selectedRange == "Y") return DateTime(rangeStart.year, 12, 31);
    return now;
  }

  String get targetDateString {
    return "${rangeEnd.year}-${rangeEnd.month.toString().padLeft(2, '0')}-${rangeEnd.day.toString().padLeft(2, '0')}";
  }

  String get dateLabel {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    DateTime s = rangeStart;
    DateTime e = rangeEnd;

    if (selectedRange == "D") {
      if (dateOffset == 0) return "Today";
      if (dateOffset == -1) return "Yesterday";
      return "${s.day} ${months[s.month - 1]} ${s.year}";
    }
    if (selectedRange == "W") {
      return "${s.day} ${months[s.month - 1]} - ${e.day} ${months[e.month - 1]} ${e.year}";
    }
    if (selectedRange == "M") {
      return "${months[s.month - 1]} ${s.year}";
    }
    if (selectedRange == "3M" || selectedRange == "6M") { 
      return "${months[s.month - 1]} ${s.year} - ${months[e.month - 1]} ${e.year}";
    }
    if (selectedRange == "Y") {
      return "${s.year}";
    }
    return "";
  }

  String get totalStepsLabel {
    if (dateOffset == 0) {
      switch (selectedRange) {
        case "D": return "Current";
        case "W": return "Total This Week";
        case "M": return "Total This Month";
        case "3M": return "Total (3 Months)"; 
        case "6M": return "Total (6 Months)";
        case "Y": return "Total This Year";
        default: return "Current";
      }
    } else if (dateOffset == -1) {
      switch (selectedRange) {
        case "D": return "Total Yesterday";
        case "W": return "Total Last Week";
        case "M": return "Total Last Month";
        case "3M": return "Previous 3 Months"; 
        case "6M": return "Previous 6 Months";
        case "Y": return "Total Last Year";
        default: return "Total Steps";
      }
    } else {
      return "Total Steps";
    }
  }

  String _getWeekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ==========================================
  // AI TIP GENERATOR
  // ==========================================

  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached_activity'); 
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
        You are a concise health AI assistant. The user, $userName, has taken $_latestIntradaySteps steps so far today against a daily goal of $stepGoal steps.
        
        Write a SHORT, 2-sentence encouraging insight or tip based exactly on this progress toward their goal. 
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        await prefs.setString('ai_tip_cached_activity', newTip);

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

  // ==========================================
  // THE NEW MASTER FETCH FUNCTION
  // ==========================================

  Future<void> _fetchLiveFitbitData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    
    final currentNow = DateTime.now();
    final todayStr = "${currentNow.year}-${currentNow.month.toString().padLeft(2, '0')}-${currentNow.day.toString().padLeft(2, '0')}";
    final dateStr = targetDateString;
    
    // ==========================================
    // THE GROUNDHOG DAY BUG FIX
    // ==========================================
    // If viewing a specific day, fetch that day. Otherwise, fetch today to patch Fitbit's lagging timeseries.
    final String intradayFetchDate = (selectedRange == "D") ? dateStr : todayStr;

    // We ALWAYS fetch Intraday (for the top number) & Weekly (for the Daily Average card)
    DateTime viewedDay = rangeStart; 
    DateTime mondayOfWeek = viewedDay.subtract(Duration(days: viewedDay.weekday - 1));
    DateTime sundayOfWeek = mondayOfWeek.add(const Duration(days: 6));
    String weekEndStr = "${sundayOfWeek.year}-${sundayOfWeek.month.toString().padLeft(2, '0')}-${sundayOfWeek.day.toString().padLeft(2, '0')}";

    List<Future<dynamic>> apiCalls = [
      ApiService.getFitbitIntradaySteps(intradayFetchDate, forceRefresh: forceRefresh), // <-- Changed this line!
      ApiService.getFitbitTimeSeriesSteps("1w", weekEndStr, forceRefresh: forceRefresh),
    ];

    String? chartPeriod;
    if (selectedRange == "M") chartPeriod = "1m";
    if (selectedRange == "3M") chartPeriod = "3m"; 
    if (selectedRange == "6M") chartPeriod = "6m";
    if (selectedRange == "Y") chartPeriod = "1y";

    if (chartPeriod != null) {
      apiCalls.add(ApiService.getFitbitTimeSeriesSteps(chartPeriod, dateStr, forceRefresh: forceRefresh));
    }

    try {
      final results = await Future.wait(apiCalls);
      
      final intradayData = results[0];
      final weeklyData = results[1];
      final chartData = chartPeriod != null ? results[2] : null;

      // 1. Get Absolute Live Steps
      int liveCurrentSteps = 0;
      if (intradayData != null && intradayData['activities-steps-intraday'] != null) {
        liveCurrentSteps = int.tryParse(intradayData['activities-steps'][0]['value'].toString()) ?? 0;
      }
      _latestIntradaySteps = liveCurrentSteps;

      // 2. Calculate Daily Average (locked to Mon-Sun)
      int weekTotal = 0;
      int activeDays = 0;
      if (weeklyData != null && weeklyData['activities-steps'] != null) {
        for (var item in weeklyData['activities-steps']) {
          DateTime dt = DateTime.parse(item['dateTime']);
          if (dt.isBefore(mondayOfWeek) || dt.isAfter(sundayOfWeek)) continue;

          double val = double.tryParse(item['value'].toString()) ?? 0;
          
          // OVERWRITE the lagging Fitbit Timeseries with live data for today
          if (dt.year == currentNow.year && dt.month == currentNow.month && dt.day == currentNow.day) {
            val = liveCurrentSteps.toDouble();
          }

          weekTotal += val.toInt();
          if (val > 0) activeDays++;
        }
      }
      int calcAverage = activeDays > 0 ? (weekTotal ~/ activeDays) : 0;

      // 3. Process Chart Data
      List<String> newLabels = [];
      List<double> newValues = [];
      List<String> newTooltipLabels = []; 
      
      int totalStepsForPeriod = 0; 
      int periodActiveDays = 0; // --- THE FIX: Active days counter for extended periods

      if (selectedRange == "D") {
        totalStepsForPeriod = liveCurrentSteps;
        if (intradayData != null && intradayData['activities-steps-intraday'] != null) {
          final dataset = intradayData['activities-steps-intraday']['dataset'] as List<dynamic>;
          for (var item in dataset) {
            String timeStr = item['time'].toString().substring(0, 5);
            int hour = int.parse(timeStr.substring(0, 2));
            String ampm = hour >= 12 ? 'PM' : 'AM';
            int displayHour = hour % 12 == 0 ? 12 : hour % 12;
            newLabels.add("$displayHour$ampm");
            newValues.add(double.tryParse(item['value'].toString()) ?? 0.0);
          }
        }
      } else {
        final datasetToUse = selectedRange == "W" ? weeklyData : chartData;

        if (datasetToUse != null && datasetToUse['activities-steps'] != null) {
          final dataset = datasetToUse['activities-steps'] as List<dynamic>;
          
          if (selectedRange == "W") {
            for (var item in dataset) {
              DateTime dt = DateTime.parse(item['dateTime']);
              if (dt.isBefore(rangeStart) || dt.isAfter(rangeEnd)) continue;
              
              newLabels.add(_getWeekday(dt.weekday));
              double val = double.tryParse(item['value'].toString()) ?? 0;
              if (dt.year == currentNow.year && dt.month == currentNow.month && dt.day == currentNow.day) {
                val = liveCurrentSteps.toDouble(); // OVERWRITE
              }
              
              newValues.add(val);
              totalStepsForPeriod += val.toInt();
              if (val > 0) periodActiveDays++; // --- THE FIX: Count active days
            }
          } else if (selectedRange == "M") {
            for (var item in dataset) {
              DateTime dt = DateTime.parse(item['dateTime']);
              if (dt.month != rangeStart.month || dt.year != rangeStart.year) continue;
              
              newLabels.add("${dt.day}/${dt.month}");
              double val = double.tryParse(item['value'].toString()) ?? 0;
              if (dt.year == currentNow.year && dt.month == currentNow.month && dt.day == currentNow.day) {
                val = liveCurrentSteps.toDouble(); // OVERWRITE
              }

              newValues.add(val);
              totalStepsForPeriod += val.toInt();
              if (val > 0) periodActiveDays++; // --- THE FIX: Count active days
            }
          } else if (selectedRange == "3M" || selectedRange == "6M") { 
            Map<String, double> weekSums = {};
            Map<String, int> weekActiveDayCounts = {};
            Map<String, int> weekMonthAssignment = {}; 
            Map<String, DateTime> weekMonday = {};     
            Map<String, DateTime> weekSunday = {};     

            for (var item in dataset) {
              DateTime dt = DateTime.parse(item['dateTime']);
              if (dt.isBefore(rangeStart) || dt.isAfter(rangeEnd)) continue;

              double val = double.tryParse(item['value'].toString()) ?? 0;
              if (dt.year == currentNow.year && dt.month == currentNow.month && dt.day == currentNow.day) {
                val = liveCurrentSteps.toDouble(); // OVERWRITE
              }

              totalStepsForPeriod += val.toInt();
              if (val > 0) periodActiveDays++; // --- THE FIX: Count active days

              int weekNum = _isoWeekNumber(dt);
              int weekYear = _isoWeekYear(dt);
              String weekKey = "$weekYear-W${weekNum.toString().padLeft(2, '0')}";

              weekSums[weekKey] = (weekSums[weekKey] ?? 0) + val;
              if (val > 0) weekActiveDayCounts[weekKey] = (weekActiveDayCounts[weekKey] ?? 0) + 1;

              if (!weekMonthAssignment.containsKey(weekKey)) {
                DateTime monday = dt.subtract(Duration(days: dt.weekday - 1));
                DateTime sunday = monday.add(const Duration(days: 6));
                weekMonthAssignment[weekKey] = dt.month; 
                weekMonday[weekKey] = monday;
                weekSunday[weekKey] = sunday;
              }
            }

            var sortedWeekKeys = weekSums.keys.toList()..sort();
            for (var key in sortedWeekKeys) {
              int month = weekMonthAssignment[key] ?? 1;
              newLabels.add(_getMonth(month));
              int activeCount = weekActiveDayCounts[key] ?? 0;
              double weekAvg = activeCount > 0 ? weekSums[key]! / activeCount : 0;
              newValues.add(weekAvg);

              final mon = weekMonday[key];
              final sun = weekSunday[key];
              if (mon != null && sun != null) {
                newTooltipLabels.add("${mon.day}/${mon.month} - ${sun.day}/${sun.month}");
              } else {
                newTooltipLabels.add("");
              }
            }
          } else if (selectedRange == "Y") {
            Map<String, double> monthlySums = {};
            Map<String, int> monthlyActiveCounts = {};
            
            for (var item in dataset) {
              DateTime dt = DateTime.parse(item['dateTime']);
              if (dt.isBefore(rangeStart) || dt.isAfter(rangeEnd)) continue;
              
              double val = double.tryParse(item['value'].toString()) ?? 0;
              if (dt.year == currentNow.year && dt.month == currentNow.month && dt.day == currentNow.day) {
                val = liveCurrentSteps.toDouble(); // OVERWRITE
              }

              totalStepsForPeriod += val.toInt();
              if (val > 0) periodActiveDays++; // --- THE FIX: Count active days

              String monthKey = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
              monthlySums[monthKey] = (monthlySums[monthKey] ?? 0) + val;
              if (val > 0) monthlyActiveCounts[monthKey] = (monthlyActiveCounts[monthKey] ?? 0) + 1;
            }
            
            var sortedKeys = monthlySums.keys.toList()..sort();
            for (var key in sortedKeys) {
              int month = int.parse(key.split("-")[1]);
              newLabels.add(_getMonth(month));
              int activeCount = monthlyActiveCounts[key] ?? 0;
              double monthAvg = activeCount > 0 ? monthlySums[key]! / activeCount : 0;
              newValues.add(monthAvg);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          currentSteps = totalStepsForPeriod; 
          
          // --- THE FIX: Perfectly calculates Daily Average depending on the selected tab ---
          if (selectedRange == "D") {
            averageSteps = calcAverage; // Uses the locked Mon-Sun weekly average
          } else {
            averageSteps = periodActiveDays > 0 ? (totalStepsForPeriod ~/ periodActiveDays) : 0;
          }
          
          if (selectedRange == "D" && newLabels.isNotEmpty) { dailyLabels = newLabels; dailyValues = newValues; }
          if (selectedRange == "W" && newLabels.isNotEmpty) { weeklyLabels = newLabels; weeklyValues = newValues; }
          if (selectedRange == "M" && newLabels.isNotEmpty) { monthlyLabels = newLabels; monthlyValues = newValues; }
          if (selectedRange == "3M" && newLabels.isNotEmpty) { threeMonthLabels = newLabels; threeMonthValues = newValues; threeMonthTooltipLabels = newTooltipLabels; } 
          if (selectedRange == "6M" && newLabels.isNotEmpty) { sixMonthLabels = newLabels; sixMonthValues = newValues; sixMonthTooltipLabels = newTooltipLabels; }
          if (selectedRange == "Y" && newLabels.isNotEmpty) { yearlyLabels = newLabels; yearlyValues = newValues; }
          
          _isLoading = false;
          _fitbitConnected = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _fitbitConnected = false; });
    }
  }

  // ==========================================
  // COMPARISON FETCHING
  // ==========================================
  
  Future<void> _fetchComparisonData({bool forceRefresh = false}) async {
    setState(() => _isLoadingComparisons = true);
    
    final currentNow = DateTime.now();
    final todayStr = "${currentNow.year}-${currentNow.month.toString().padLeft(2, '0')}-${currentNow.day.toString().padLeft(2, '0')}";
    final lastYearEndStr = "${currentNow.year - 1}-12-31";

    try {
      final results = await Future.wait([
        ApiService.getFitbitTimeSeriesSteps("3m", todayStr, forceRefresh: forceRefresh), 
        ApiService.getFitbitTimeSeriesSteps("1y", todayStr, forceRefresh: forceRefresh), 
        ApiService.getFitbitTimeSeriesSteps("1y", lastYearEndStr, forceRefresh: forceRefresh) 
      ]);

      final data3m = results[0];
      final dataThisYear = results[1];
      final dataLastYear = results[2];

      int thisMonth = currentNow.month;
      int thisYearForMonth = currentNow.year;
      int lastMonth = thisMonth == 1 ? 12 : thisMonth - 1;
      int lastYearForMonth = thisMonth == 1 ? currentNow.year - 1 : currentNow.year;

      double thisMonthSum = 0; int thisMonthCount = 0;
      double lastMonthSum = 0; int lastMonthCount = 0;

      if (data3m != null && data3m['activities-steps'] != null) {
        for (var item in data3m['activities-steps']) {
          DateTime dt = DateTime.parse(item['dateTime']);
          double val = double.tryParse(item['value'].toString()) ?? 0;
          if (val > 0) {
            if (dt.year == thisYearForMonth && dt.month == thisMonth) {
              thisMonthSum += val;
              thisMonthCount++;
            } else if (dt.year == lastYearForMonth && dt.month == lastMonth) {
              lastMonthSum += val;
              lastMonthCount++;
            }
          }
        }
      }

      double thisMonthAvg = thisMonthCount > 0 ? thisMonthSum / thisMonthCount : 0;
      double lastMonthAvg = lastMonthCount > 0 ? lastMonthSum / lastMonthCount : 0;

      double thisYearSum = 0; int thisYearCount = 0;
      double lastYearSum = 0; int lastYearCount = 0;

      if (dataThisYear != null && dataThisYear['activities-steps'] != null) {
        for (var item in dataThisYear['activities-steps']) {
          DateTime dt = DateTime.parse(item['dateTime']);
          double val = double.tryParse(item['value'].toString()) ?? 0;
          if (val > 0 && dt.year == currentNow.year) {
            thisYearSum += val;
            thisYearCount++;
          }
        }
      }

      if (dataLastYear != null && dataLastYear['activities-steps'] != null) {
        for (var item in dataLastYear['activities-steps']) {
          DateTime dt = DateTime.parse(item['dateTime']);
          double val = double.tryParse(item['value'].toString()) ?? 0;
          if (val > 0 && dt.year == currentNow.year - 1) {
            lastYearSum += val;
            lastYearCount++;
          }
        }
      }

      double thisYearAvg = thisYearCount > 0 ? thisYearSum / thisYearCount : 0;
      double lastYearAvg = lastYearCount > 0 ? lastYearSum / lastYearCount : 0;

      if (mounted) {
        setState(() {
          monthlyAverageLabels = [_getMonth(lastMonth), _getMonth(thisMonth)];
          monthlyAverageValues = [lastMonthAvg, thisMonthAvg];

          yearlyAverageLabels = [(currentNow.year - 1).toString(), currentNow.year.toString()];
          yearlyAverageValues = [lastYearAvg, thisYearAvg];

          _isLoadingComparisons = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComparisons = false);
    }
  }

  // ==========================================
  // ISO WEEK HELPERS
  // ==========================================

  int _isoWeekNumber(DateTime date) {
    DateTime thursday = date.subtract(Duration(days: date.weekday - 4));
    DateTime firstThursday = DateTime(thursday.year, 1, 1);
    while (firstThursday.weekday != 4) {
      firstThursday = firstThursday.add(const Duration(days: 1));
    }
    int weekNum = ((thursday.difference(firstThursday).inDays) ~/ 7) + 1;
    return weekNum;
  }

  int _isoWeekYear(DateTime date) {
    DateTime thursday = date.subtract(Duration(days: date.weekday - 4));
    return thursday.year;
  }

  // ==========================================
  // UI HELPERS
  // ==========================================

  List<String> getLabelsList() {
    switch (selectedRange) {
      case "D": return dailyLabels;
      case "W": return weeklyLabels;
      case "M": return monthlyLabels;
      case "3M": return threeMonthLabels; 
      case "6M": return sixMonthLabels;
      case "Y": return yearlyLabels;
      default: return [];
    }
  }

  List<double> getValuesList() {
    switch (selectedRange) {
      case "D": return dailyValues;
      case "W": return weeklyValues;
      case "M": return monthlyValues;
      case "3M": return threeMonthValues; 
      case "6M": return sixMonthValues;
      case "Y": return yearlyValues;
      default: return [];
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

  void openSharePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivitySharePage(
          currentSteps: currentSteps,
          averageSteps: averageSteps,
          stepGoal: stepGoal,
          rangeName: fullRangeName,
          dateRangeLabel: dateLabel,
          userName: widget.baseUserData['preferred_name'] ?? widget.baseUserData['name'] ?? 'User',
        ),
      ),
    );
  }

// ==========================================
  // MAIN BUILD
  // ==========================================

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
          "Activity",
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
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.cardBackground,
        onRefresh: () async {
          await Future.wait([
            _fetchLiveFitbitData(forceRefresh: true),
            _fetchComparisonData(forceRefresh: true),
            _generateAITip(forceRefresh: true),
          ]);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // --- THE RESPONSIVE TRIGGER ---
            bool isWideScreen = constraints.maxWidth > 850;

            if (isWideScreen) {
              // ==========================================
              // DESKTOP / TABLET LAYOUT (2 Columns)
              // ==========================================
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: Chart, Navigation & Filters
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
                    // RIGHT COLUMN: Stats, AI Sidebar & Comparisons side-by-side
                    Expanded(
                      flex: 4, // Slightly widened from 3 to 4 to give the side-by-side charts room to breathe
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCurrentStepsAndSync(),
                          const SizedBox(height: 32),
                          _buildInfoCards(isWide: true), 
                          const SizedBox(height: 24),
                          _buildAiTips(),
                          const SizedBox(height: 24),
                          // Comparisons now forcefully side-by-side
                          _buildComparisonWidgets(), 
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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCurrentStepsAndSync(),
                    const SizedBox(height: 18),
                    _buildOverviewHeader(),
                    const SizedBox(height: 10),
                    _buildDateNavigator(),
                    const SizedBox(height: 10),
                    _buildChart(),
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    _buildInfoCards(isWide: false),
                    const SizedBox(height: 16),
                    _buildAiTips(),
                    const SizedBox(height: 16),
                    _buildComparisonWidgets(),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // UI HELPER METHODS
  // ==========================================

  Widget _buildCurrentStepsAndSync() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(totalStepsLabel, style: const TextStyle(color: Colors.white, fontSize: 16)),
            _isLoading 
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3)),
                )
              : Text(
                  "$currentSteps",
                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                ),
            const Text("steps", style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
        _fitbitConnected
          ? InkWell(
              onTap: _isRefreshing ? null : () => _handleRefreshFitbit(),
              child: Row(
                children: [
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
                    child: const Icon(Icons.sync, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isRefreshing ? "Refreshing..." : "Refresh Data",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: _showFitbitConnectDialog,
              child: Row(
                children: const [
                  Icon(Icons.watch, color: Colors.white),
                  SizedBox(width: 6),
                  Text("Connect Fitbit", style: TextStyle(color: Colors.white, fontSize: 18)),
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
            setState(() => dateOffset--); 
            _fetchLiveFitbitData();       
          },
        ),
        Text(
          dateLabel, 
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right, 
            color: dateOffset < 0 ? Colors.white : Colors.white38, 
            size: 30
          ),
          onPressed: dateOffset < 0 ? () {
            setState(() => dateOffset++); 
            _fetchLiveFitbitData();       
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
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : MyBarChart(
            labels: getLabelsList(),
            values: getValuesList(),
            showSideLabels: true,
            selectedRange: selectedRange,
            tooltipLabels: (selectedRange == "3M" || selectedRange == "6M") 
                ? (selectedRange == "3M" ? threeMonthTooltipLabels : sixMonthTooltipLabels) 
                : null,
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
      return Column(
        children: [
          infoCard(selectedRange == "D" ? "Avg (Mon-Sun)" : "Daily Avg", "$averageSteps", isWide: true), 
          const SizedBox(height: 16),
          _buildGoalCard(isWide: true),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: infoCard(selectedRange == "D" ? "Avg (Mon-Sun)" : "Daily Avg", "$averageSteps")), 
          const SizedBox(width: 8),
          Expanded(child: _buildGoalCard(isWide: false)),
        ],
      );
    }
  }

  Widget _buildGoalCard({required bool isWide}) {
    return InkWell(
      onTap: _showEditGoalDialog,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 95,
        width: isWide ? double.infinity : null,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Goal",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatNumber(stepGoal),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Icon(
                Icons.edit,
                size: 15,
                color: Colors.white.withValues(alpha: 0.6), 
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiTips() {
    return InkWell(
      onTap: () {
        final updatedData = Map<String, dynamic>.from(widget.baseUserData);
        updatedData['activity'] = "$_latestIntradaySteps steps";
        updatedData['stepGoal'] = "$stepGoal steps"; 
        
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
                        "Analyzing your activity data...", 
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

  Widget _buildComparisonWidgets() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
            ),
            child: Column(
              children: [
                const Text("Monthly Avg", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingComparisons 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : MyBarChart(
                        values: monthlyAverageValues,
                        labels: monthlyAverageLabels,
                        showSideLabels: false,
                        selectedRange: "COMPARE", 
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
            ),
            child: Column(
              children: [
                const Text("Yearly Avg", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingComparisons 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : MyBarChart(
                        values: yearlyAverageValues,
                        labels: yearlyAverageLabels,
                        showSideLabels: false,
                        selectedRange: "COMPARE", 
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Small reusable widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget infoCard(String title, String value, {bool isWide = false}) {
    return Container(
      height: 95,
      width: isWide ? double.infinity : null,
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1))), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
          dateOffset = 0;
        });
        _fetchLiveFitbitData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

// ==========================================
// CUSTOM CHART WIDGET
// ==========================================

class MyBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final bool showSideLabels;
  final String selectedRange;
  final List<String>? tooltipLabels;

  const MyBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.showSideLabels,
    required this.selectedRange,
    this.tooltipLabels,
  });

  @override
  Widget build(BuildContext context) {
    double maxVal = values.isNotEmpty ? values.reduce(max) : 0;
    double calculatedInterval = (maxVal * 11 / 30).ceilToDouble();
    double safeInterval = calculatedInterval > 0 ? calculatedInterval : 1.0;
    double safeMaxY = maxVal > 0 ? safeInterval * 3 : 10.0;

    return BarChart(
      BarChartData(
        maxY: safeMaxY,
        alignment: BarChartAlignment.spaceAround,
        
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.background.withValues(alpha: 0.95), 
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String timeFrame = "";
              
              if (selectedRange == "D" && labels.length == 24) {
                int startHour = group.x;
                int endHour = (startHour + 1) % 24;
                
                int displayStart = startHour % 12 == 0 ? 12 : startHour % 12;
                String startAmPm = startHour < 12 ? "AM" : "PM";
                
                int displayEnd = endHour % 12 == 0 ? 12 : endHour % 12;
                String endAmPm = endHour < 12 ? "AM" : "PM";
                if (endHour == 0) endAmPm = "AM"; 
                
                timeFrame = "$displayStart$startAmPm - $displayEnd$endAmPm";
              } 
              else if ((selectedRange == "3M" || selectedRange == "6M") && tooltipLabels != null && group.x < tooltipLabels!.length) {
                timeFrame = tooltipLabels![group.x];
              } else {
                timeFrame = labels.length > group.x ? labels[group.x] : "";
              }

              final String stepLabel = (selectedRange == "3M" || selectedRange == "6M" || selectedRange == "COMPARE") ? "daily avg" : "steps";

              return BarTooltipItem(
                '$timeFrame\n',
                const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toInt()} $stepLabel',
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),

        gridData: FlGridData(
          drawHorizontalLine: showSideLabels,
          drawVerticalLine: false,
          horizontalInterval: safeInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color.fromARGB(160, 255, 255, 255),
              strokeWidth: (value >= safeMaxY) ? 0 : 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                int index = value.toInt();
                if (index < 0 || index >= labels.length) return const SizedBox.shrink();

                String labelText = '';

                if (selectedRange == "D" && labels.length == 24) {
                  if (index == 0) labelText = '12AM';
                  else if (index == 6) labelText = '6AM';
                  else if (index == 12) labelText = '12PM';
                  else if (index == 18) labelText = '6PM';
                  else if (index == 23) labelText = '12AM';
                } 
                else if (selectedRange == "M" && labels.length > 20) {
                  if (index % 7 == 0) labelText = labels[index];
                } 
                else if (selectedRange == "3M" || selectedRange == "6M") {
                  if (index == 0 || labels[index] != labels[index - 1]) {
                    labelText = labels[index];
                  }
                }
                else if (selectedRange == "Y" && labels.length > 2) {
                  labelText = labels[index].isNotEmpty ? labels[index][0] : '';
                } 
                else {
                  labelText = labels[index];
                }

                return Text(
                  labelText,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showSideLabels,
              reservedSize: 40,
              interval: safeInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                width: MediaQuery.of(context).size.width / (values.length == 2 ? 5 : values.length) * .5,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                color: (index % 2 == 1
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.6)), 
              ),
            ],
          );
        }),
      ), 
    );
  }
}