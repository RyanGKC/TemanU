import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:temanu/activity.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/bloodGlucose.dart';
import 'package:temanu/bloodpressure.dart';
import 'package:temanu/bodyweight.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/caloriesMain.dart';
import 'package:temanu/heartrate.dart';
import 'package:temanu/medicationlog.dart';
import 'package:temanu/oxygenSaturation.dart';
import 'package:temanu/patientData.dart';
import 'package:temanu/pdfGenerator.dart';
import 'package:temanu/profileInformation.dart';
import 'package:temanu/fitbitService.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  final GlobalKey<HealthDashboardContentState> dashboardKey;
  const HomePage({super.key, required this.dashboardKey});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _firstName = "User"; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstName = prefs.getString('user_name') ?? "User";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Hi, $_firstName', // <-- NEW: Dynamic name!
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF),
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xff040F31),
      // --- NEW: RefreshIndicator for Pull-to-Refresh ---
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.dashboardKey.currentState?.forceSyncFitbit();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Pass the key to the dashboard content
              HealthDashboardContent(key: widget.dashboardKey),
              const Padding(
                padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
                child: MedicationLog(),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthDashboardContent extends StatefulWidget {
  const HealthDashboardContent({super.key});

  @override
  State<HealthDashboardContent> createState() => HealthDashboardContentState();
}

// Made this state public (removed the underscore) so the GlobalKey can access it
class HealthDashboardContentState extends State<HealthDashboardContent> {
  PatientData _patientData = const PatientData(
    name: 'James', dob: '15 May 1990', age: '35', gender: 'Male',
    height: '180', weight: '75', bloodType: 'O+', conditions: 'None',
  );
  bool _isLoading = true;
  List<dynamic> _activeMedications = []; // --- NEW: Holds the med list for the PDF ---

  Timer? _backgroundSyncTimer;
  late List<Map<String, dynamic>> _metricsData;
  String _bodyGoal = 'maintain';
  double _caloriesTarget = 2200;
  double _caloriesBurnTarget = 2200;
  double _proteinTarget = 140, _carbsTarget = 250, _fatsTarget = 70;
  double _proteinConsumed = 0, _carbsConsumed = 0, _fatsConsumed = 0;

  @override
  void initState() {
    super.initState();
    _metricsData = [
      { "icon": Icons.water_drop,          "title": "Blood Glucose Level", "value": "--",    "unit": "mg/dl", "destination": const BloodGlucose(),                         "isVisible": true, "isShareSelected": true },
      { "icon": Icons.directions_run,      "title": "Activity",            "value": "--",     "unit": "steps", "destination": const Activity(),                          "isVisible": true, "isShareSelected": true },
      { "icon": Icons.favorite, "title": "Heart Rate", "value": "--", "unit": "bpm", "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.opacity,             "title": "Oxygen Saturation",   "value": "--",     "unit": "%",     "destination": const SizedBox(),              "isVisible": true, "isShareSelected": true },
      { "icon": Icons.monitor_heart,       "title": "Blood Pressure",      "value": "--", "unit": "mmHg",  "destination": const SizedBox(),                 "isVisible": true, "isShareSelected": true },
      { "icon": Icons.local_fire_department, "title": "Calories",          "value": "--",   "unit": "kcal",  "destination": const SizedBox(),   "isVisible": true, "isShareSelected": true },
      { "icon": Icons.monitor_weight,      "title": "Body Weight",         "value": "--",   "unit": "kg",    "destination": const SizedBox(),                    "isVisible": true, "isShareSelected": true },
    ];
    _loadPreferences();
    _fetchDatabaseMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialFitbitSync();
    });

    // The silent 15-minute background timer
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      String? token = await FitbitService.getSilentToken();
      if (token != null) {
        _autoSyncFitbit(token);
      }
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _fetchDatabaseMetrics() async {
    // 1. Turn on the loading spinner
    setState(() { _isLoading = true; }); 

    // --- FETCH GENERAL METRICS ---
    final allMetrics = await ApiService.getHealthMetrics(); 
    Map<String, String> newestValues = {};

    for (var metric in allMetrics) {
      String type = metric['metric_type'];
      if (!newestValues.containsKey(type)) {
        newestValues[type] = metric['value'].toString();
      }
    }

    // --- FETCH TODAY'S MEALS ---
    final todaysMeals = await ApiService.getTodaysMeals();
    int totalCalories = 0;
    for (var meal in todaysMeals) {
      totalCalories += (meal['calories'] as num).toInt();
    }
    
    // --- THE FIX: Fetch the full medication list instead of just the score! ---
    final meds = await ApiService.getMedications();
    // --------------------------------------------------------------------------

    if (mounted) {
      setState(() {
        if (newestValues.containsKey('Body Weight')) _metricsData.firstWhere((m) => m['title'] == 'Body Weight')['value'] = newestValues['Body Weight'];
        if (newestValues.containsKey('Heart Rate')) _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value'] = newestValues['Heart Rate'];
        if (newestValues.containsKey('Blood Glucose')) _metricsData.firstWhere((m) => m['title'] == 'Blood Glucose Level')['value'] = newestValues['Blood Glucose'];
        if (newestValues.containsKey('Oxygen Saturation')) _metricsData.firstWhere((m) => m['title'] == 'Oxygen Saturation')['value'] = newestValues['Oxygen Saturation'];
        if (newestValues.containsKey('Blood Pressure')) _metricsData.firstWhere((m) => m['title'] == 'Blood Pressure')['value'] = newestValues['Blood Pressure'];
        
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = totalCalories.toString();
        
        // --- Save the meds to pass to the PDF ---
        _activeMedications = meds; 
        
        // 2. Turn off the loading spinner
        _isLoading = false; 
      });
    }
  }

  // Helper method to gather all data for the AI
  Map<String, dynamic> gatherDataForAI() {
    String getMetricValue(String title) {
      return _metricsData.firstWhere((m) => m['title'] == title, orElse: () => {'value': '--'})['value'];
    }

    return {
      'name': _patientData.name,
      'age': _patientData.age,
      'gender': _patientData.gender,
      'height': _patientData.height,
      'weight': _patientData.weight,
      'bloodType': _patientData.bloodType,
      'healthConditions': _patientData.conditions,
      'bloodGlucose': getMetricValue('Blood Glucose Level'),
      'steps': getMetricValue('Activity'),
      'heartRate': getMetricValue('Heart Rate'),
      'oxygenSaturation': getMetricValue('Oxygen Saturation'),
      'bloodPressure': getMetricValue('Blood Pressure'),
      'calories': getMetricValue('Calories'), 
      'bodyGoal': _bodyGoal,
      'caloriesIntakeTarget': _caloriesTarget,
      'caloriesBurnTarget': _caloriesBurnTarget,
      'proteinConsumed': _proteinConsumed,
      'carbsConsumed': _carbsConsumed,
      'fatsConsumed': _fatsConsumed,
      'proteinTarget': _proteinTarget,
      'carbsTarget': _carbsTarget,
      'fatsTarget': _fatsTarget,
    };
  }

  Future<void> _checkInitialFitbitSync() async {
    String? token = await FitbitService.getSilentToken();
    if (token == null) {
      if (mounted) _showFitbitConnectDialog();
    } else {
      _autoSyncFitbit(token);
    }
  }

  // --- SILENT CACHED SYNC ---
  Future<void> _autoSyncFitbit(String token) async {
    String? realSteps = await FitbitService.getTodaysSteps(token);
    String? realHeartRate = await FitbitService.getHeartRate(token);
    
    if (mounted) {
      setState(() {
        if (realSteps != null) {
          _metricsData.firstWhere((m) => m['title'] == 'Activity')['value'] = realSteps;
        }
        if (realHeartRate != null) {
          _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value'] = realHeartRate;
        }
      });
    }
  }

  // --- NEW: CUSTOM TOP TOAST NOTIFICATION ---
  void _showTopToast(BuildContext context, String message, {bool isSuccess = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Places it just below the notch / status bar of the phone
        top: MediaQuery.of(context).padding.top + 10, 
        left: 20,
        right: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack, // Gives it a slick, natural bounce!
          builder: (context, value, child) {
            return Transform.translate(
              // Animates it sliding down from above the screen
              offset: Offset(0, -50 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xff00E5FF) : const Color(0xff1A3F6B).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: isSuccess ? null : Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.sync,
                    color: isSuccess ? const Color(0xff040F31) : const Color(0xff00E5FF),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    message,
                    style: TextStyle(
                      color: isSuccess ? const Color(0xff040F31) : Colors.white,
                      fontSize: 15,
                      fontWeight: isSuccess ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Show the notification
    overlay.insert(overlayEntry);

    // Automatically remove it after a few seconds
    Future.delayed(Duration(seconds: isSuccess ? 3 : 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // --- MANUAL OVERRIDE SYNC (Triggered by button or pull-to-refresh) ---
  Future<void> forceSyncFitbit() async {
    String? token = await FitbitService.getValidToken(); 
    
    if (token != null) {
      if (mounted) {
        // Trigger the dark blue "syncing" toast from the top
        _showTopToast(context, "Syncing latest Fitbit data...", isSuccess: false);
      }

      String? realSteps = await FitbitService.getTodaysSteps(token, forceRefresh: true);
      String? realHeartRate = await FitbitService.getHeartRate(token, forceRefresh: true);
      
      if (mounted) {
        setState(() {
          if (realSteps != null) {
            _metricsData.firstWhere((m) => m['title'] == 'Activity')['value'] = realSteps;
          }
          if (realHeartRate != null) {
            _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value'] = realHeartRate;
          }
        });

        // Trigger the bright cyan "success" toast from the top
        _showTopToast(context, "Dashboard Updated!", isSuccess: true);
      }
    }
  }

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
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.watch, color: Color(0xff00E5FF), size: 40),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Connect Your Health Data",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Link your Fitbit account to automatically track your daily steps, heart rate, and sleep directly on your dashboard.",
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
                                border: Border.all(color: Colors.white38, width: 1.5),
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
                                _autoSyncFitbit(newToken);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xff00E5FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: const Text("Connect", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 1. Dashboard visibility
      for (var metric in _metricsData) {
        metric['isVisible'] = prefs.getBool(metric['title']) ?? true;
      }

      // 2. Calories (Dynamic List Calculation)
      final String? mealsJson = prefs.getString('tracked_meals');
      double dynamicallyCalculatedCalories = 0;
      if (mealsJson != null) {
        final List<dynamic> decoded = jsonDecode(mealsJson);
        for (var meal in decoded) {
          dynamicallyCalculatedCalories += (meal['calories'] as num).toDouble();
        }
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = dynamicallyCalculatedCalories.toInt().toString();
      } else {
        // --- THE FIX: Changed from '--' to '0' ---
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = '0';
      }

      // 3. FETCH THE REST OF THE LIVE DATA (from offline cache)!
      
      // Heart Rate
      int latestHr = prefs.getInt('latest_hr') ?? 0; 
      _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value'] = latestHr > 0 ? latestHr.toString() : '--';

      // Blood Pressure (Changed to default to '--')
      String? latestBp = prefs.getString('latest_bp');
      _metricsData.firstWhere((m) => m['title'] == 'Blood Pressure')['value'] = latestBp ?? '--';

      // Oxygen Saturation (Changed to default to '--')
      int? latestSpo2 = prefs.getInt('latest_spo2');
      _metricsData.firstWhere((m) => m['title'] == 'Oxygen Saturation')['value'] = latestSpo2 != null ? latestSpo2.toString() : '--';

      // Body Weight (Changed to default to '--')
      double? latestWeight = prefs.getDouble('latest_weight');
      _metricsData.firstWhere((m) => m['title'] == 'Body Weight')['value'] = latestWeight != null ? latestWeight.toStringAsFixed(1) : '--';

      // 4. Goals and Targets
      _bodyGoal = prefs.getString('body_goal') ?? 'maintain';
      _caloriesTarget = prefs.getDouble('calories_intake_target') ?? 2200;
      int goalOffset = prefs.getInt('goal_offset') ?? 500;

      int signedOffset = 0;
      if (_bodyGoal == 'deficit') signedOffset = goalOffset;
      if (_bodyGoal == 'surplus') signedOffset = -goalOffset;
      _caloriesBurnTarget = (_caloriesTarget + signedOffset).clamp(500, 9999).toDouble();
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _navigateToProfile() async {
    final result = await Navigator.push<PatientData>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileInformationPage()),
    );
    if (result != null) {
      setState(() {
        _patientData = result;
      });
    }
  }

  List<Map<String, dynamic>> get _selectedMetrics => _metricsData
      .where((m) => m['isShareSelected'] == true)
      .cast<Map<String, dynamic>>()
      .toList();

  void _showEditMetricsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xff1A3F6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Customize Dashboard",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return SwitchListTile(
                          activeThumbColor: const Color(0xff00E5FF),
                          activeTrackColor:
                              const Color(0xff00E5FF).withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.1),
                          secondary:
                              Icon(metric['icon'], color: Colors.white70),
                          title: Text(metric['title'],
                              style: const TextStyle(color: Colors.white)),
                          value: metric['isVisible'],
                          onChanged: (bool value) {
                            setModalState(() => metric['isVisible'] = value);
                            setState(() {});
                            _savePreference(metric['title'], value);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff00E5FF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done",
                            style: TextStyle(
                                color: Color(0xff040F31),
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showShareMetricsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xff1A3F6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Select Data to Export",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return CheckboxListTile(
                          activeColor: const Color(0xff00E5FF),
                          checkColor: const Color(0xff040F31),
                          side: const BorderSide(color: Colors.white70),
                          secondary:
                              Icon(metric['icon'], color: Colors.white70),
                          title: Text(metric['title'],
                              style: const TextStyle(color: Colors.white)),
                          value: metric['isShareSelected'],
                          onChanged: (bool? value) {
                            setModalState(
                                () => metric['isShareSelected'] = value ?? false);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Row(
                      children: [
                        if (!kIsWeb) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xff00E5FF), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                PdfGenerator.generateAndShare(
                                  selectedMetrics: _selectedMetrics,
                                  patientData: _patientData.toMap(),
                                  activeMedications: _activeMedications, // <-- ADD THIS
                                );
                              },
                              child: const Text(
                                "Share PDF",
                                style: TextStyle(
                                    color: Color(0xff00E5FF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              PdfGenerator.generateAndSave(
                                selectedMetrics: _selectedMetrics,
                                patientData: _patientData.toMap(),
                                activeMedications: _activeMedications, // <-- ADD THIS
                                context: context,
                              );
                            },
                            child: const Text(
                              "Save PDF",
                              style: TextStyle(
                                  color: Color(0xff040F31),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMetrics = _metricsData.where((m) => m['isVisible'] == true).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWideScreen = constraints.maxWidth > 800;
              double cardWidth = isWideScreen ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 15,
                runSpacing: 0,
                children: visibleMetrics.map((metric) {
                  return SizedBox(
                    width: cardWidth,
                    child: healthCard(
                      context, metric['icon'], metric['title'], metric['value'], metric['unit'], metric['destination'],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Edit, Sync, & Share Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: _showEditMetricsBottomSheet, 
              ),
              // --- NEW: Dedicated Sync Button on the Home Page! ---
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xff00E5FF), size: 28),
                onPressed: forceSyncFitbit, // Triggers the forced API pull
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 28),
                onPressed: _showShareMetricsBottomSheet, 
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget healthCard(BuildContext context, IconData icon, String title, String value, String unit, Widget destinationPage) {
    return GestureDetector(
      onTap: () async {
        if (title == 'Calories') {
          // Intercept the Calories tap to pass the fresh data map
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => CaloriesMain(
              patientData: _patientData,
              baseUserData: gatherDataForAI(), // Pass the baton!
            )
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Heart Rate') {
          // NEW: Intercept the Heart Rate tap to pass the fresh data map
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => HeartRatePage(
              baseUserData: gatherDataForAI(), // Pass the baton!
            )
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Oxygen Saturation') {
          // NEW: Intercept Oxygen Saturation tap!
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => OxygenSaturationPage(baseUserData: gatherDataForAI())
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Blood Pressure') {
          // NEW INTERCEPT: Hand off the data!
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => BloodPressurePage(baseUserData: gatherDataForAI())
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Body Weight') {
          // NEW INTERCEPT: Hand off the data!
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => BodyWeightPage(baseUserData: gatherDataForAI())
          ));
          _fetchDatabaseMetrics();
        } else if (destinationPage is ProfileInformationPage) {
          await _navigateToProfile();
        } else {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => destinationPage));
          _fetchDatabaseMetrics();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff1A3F6B),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 35),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                _isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        height: 20, 
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00E5FF)), // Matches your cyan theme!
                        ),
                      ),
                    )
                  : Text("$value $unit", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

