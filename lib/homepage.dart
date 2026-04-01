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
import 'package:temanu/theme.dart';

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
          'Hi, $_firstName',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: AppTheme.background.withValues(alpha: 0.5), 
            ),
          ),
        ),
      ),
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.dashboardKey.currentState?.forceSyncFitbit();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
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

class HealthDashboardContentState extends State<HealthDashboardContent> {
  PatientData _patientData = const PatientData(
    name: 'James', dob: '15 May 1990', age: '35', gender: 'Male',
    height: '180', weight: '75', bloodType: 'O+', conditions: 'None',
  );
  bool _isLoading = true;
  List<dynamic> _activeMedications = [];
  
  // --- NEW: Tracking variable for PDF Medication Export ---
  bool _includeMedicationsInExport = true; 

  Timer? _backgroundSyncTimer;
  late List<Map<String, dynamic>> _metricsData;
  String _bodyGoal = 'maintain';
  double _caloriesTarget = 2200;
  double _caloriesBurnTarget = 2200;
  double _proteinTarget = 140, _carbsTarget = 250, _fatsTarget = 70;
  double _proteinConsumed = 0, _carbsConsumed = 0, _fatsConsumed = 0;
  int _globalStepGoal = 10000;

  @override
  void initState() {
    super.initState();
    _metricsData = [
      { "icon": Icons.water_drop,            "title": "Blood Glucose Level", "value": "--",  "unit": "mg/dl", "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.directions_run,        "title": "Activity",            "value": "--",  "unit": "steps", "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.favorite,              "title": "Heart Rate",          "value": "--",  "unit": "bpm",   "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.opacity,               "title": "Oxygen Saturation",   "value": "--",  "unit": "%",     "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.monitor_heart,         "title": "Blood Pressure",      "value": "--",  "unit": "mmHg",  "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.local_fire_department, "title": "Calories",            "value": "--",  "unit": "kcal",  "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
      { "icon": Icons.monitor_weight,        "title": "Body Weight",         "value": "--",  "unit": "kg",    "destination": const SizedBox(), "isVisible": true, "isShareSelected": true },
    ];
    _loadPreferences();
    _fetchDatabaseMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialFitbitSync();
    });

    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      String? isLinked = await FitbitService.getSilentToken();
      if (isLinked != null) {
        _autoSyncFitbit();
      }
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _fetchDatabaseMetrics() async {
    setState(() { _isLoading = true; }); 

    final allMetrics = await ApiService.getHealthMetrics(); 
    Map<String, String> newestValues = {};

    allMetrics.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

    for (var metric in allMetrics) {
      newestValues[metric['metric_type']] = metric['value'].toString();
    }

    final todaysMeals = await ApiService.getTodaysMeals();
    int totalCalories = 0;
    for (var meal in todaysMeals) {
      totalCalories += (meal['calories'] as num).toInt();
    }
    
    final meds = await ApiService.getMedications();

    if (mounted) {
      setState(() {
        if (newestValues.containsKey('Body Weight')) {
          String latestWeightFromDB = newestValues['Body Weight']!;
          
          _metricsData.firstWhere((m) => m['title'] == 'Body Weight')['value'] = latestWeightFromDB;
          
          _patientData = PatientData(
            name: _patientData.name,
            dob: _patientData.dob,
            age: _patientData.age,
            gender: _patientData.gender,
            height: _patientData.height,
            weight: latestWeightFromDB, 
            bloodType: _patientData.bloodType,
            conditions: _patientData.conditions,
          );
        }

        if (newestValues.containsKey('Heart Rate'))        _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value']          = newestValues['Heart Rate']!;
        if (newestValues.containsKey('Blood Glucose'))     _metricsData.firstWhere((m) => m['title'] == 'Blood Glucose Level')['value'] = newestValues['Blood Glucose']!;
        if (newestValues.containsKey('Oxygen Saturation')) _metricsData.firstWhere((m) => m['title'] == 'Oxygen Saturation')['value']   = newestValues['Oxygen Saturation']!;
        if (newestValues.containsKey('Blood Pressure'))    _metricsData.firstWhere((m) => m['title'] == 'Blood Pressure')['value']      = newestValues['Blood Pressure']!;
        
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = totalCalories.toString();
        _activeMedications = meds; 
        _isLoading = false; 
      });
    }
  }

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
      'stepGoal': _globalStepGoal,
      'proteinConsumed': _proteinConsumed,
      'carbsConsumed': _carbsConsumed,
      'fatsConsumed': _fatsConsumed,
      'proteinTarget': _proteinTarget,
      'carbsTarget': _carbsTarget,
      'fatsTarget': _fatsTarget,
    };
  }

  Future<void> _checkInitialFitbitSync() async {
    String? isLinked = await FitbitService.getSilentToken();
    if (isLinked == null) {
      if (mounted) _showFitbitConnectDialog();
    } else {
      _autoSyncFitbit();
    }
  }

  Future<void> _autoSyncFitbit() async {
    // --- CHANGED: No longer passing a token or fetching heart rate ---
    String? realSteps = await FitbitService.getTodaysSteps(forceRefresh: true);
    
    if (mounted) {
      setState(() {
        if (realSteps != null) _metricsData.firstWhere((m) => m['title'] == 'Activity')['value'] = realSteps;
      });
    }
  }

  void _showTopToast(BuildContext context, String message, {bool isSuccess = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, 
        left: 20,
        right: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, -50 * (1 - value)),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isSuccess ? AppTheme.primaryColor : AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: isSuccess ? null : Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5), 
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)) 
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.sync,
                    color: isSuccess ? AppTheme.textPrimary : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 15),
                  Text(
                    message,
                    style: TextStyle(
                      color: isSuccess ? AppTheme.textPrimary : AppTheme.textPrimary,
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

    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: isSuccess ? 3 : 2), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  Future<void> forceSyncFitbit() async {
    String? isLinked = await FitbitService.getValidToken(); 
    
    if (isLinked != null) {
      if (mounted) _showTopToast(context, "Syncing latest Fitbit data...", isSuccess: false);

      // --- CHANGED: No longer passing a token or fetching heart rate ---
      String? realSteps = await FitbitService.getTodaysSteps(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          if (realSteps != null) _metricsData.firstWhere((m) => m['title'] == 'Activity')['value'] = realSteps;
        });
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
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha:0.8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5), 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: .1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.watch, color: AppTheme.primaryColor, size: 40),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Connect Your Health Data",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      // --- CHANGED: Removed mention of heart rate and sleep to match the updated scope ---
                      "Link your Fitbit account to automatically track your daily steps directly on your dashboard.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                                border: Border.all(color: AppTheme.textSecondary, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: const Text("Not Now", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context); 
                              String? isLinked = await FitbitService.getValidToken();
                              if (isLinked != null) _autoSyncFitbit();
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String savedName = prefs.getString('user_name') ?? 'User';
      
      _patientData = PatientData(
        name: savedName, 
        dob: _patientData.dob,
        age: _patientData.age,
        gender: _patientData.gender,
        height: _patientData.height,
        weight: _patientData.weight,
        bloodType: _patientData.bloodType,
        conditions: _patientData.conditions,
      );

      for (var metric in _metricsData) {
        metric['isVisible'] = prefs.getBool(metric['title']) ?? true;
      }

      final String? mealsJson = prefs.getString('tracked_meals');
      double dynamicallyCalculatedCalories = 0;
      if (mealsJson != null) {
        final List<dynamic> decoded = jsonDecode(mealsJson);
        for (var meal in decoded) {
          dynamicallyCalculatedCalories += (meal['calories'] as num).toDouble();
        }
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = dynamicallyCalculatedCalories.toInt().toString();
      } else {
        _metricsData.firstWhere((m) => m['title'] == 'Calories')['value'] = '0';
      }

      int latestHr = prefs.getInt('latest_hr') ?? 0; 
      _metricsData.firstWhere((m) => m['title'] == 'Heart Rate')['value'] = latestHr > 0 ? latestHr.toString() : '--';

      String? latestBp = prefs.getString('latest_bp');
      _metricsData.firstWhere((m) => m['title'] == 'Blood Pressure')['value'] = latestBp ?? '--';

      int? latestSpo2 = prefs.getInt('latest_spo2');
      _metricsData.firstWhere((m) => m['title'] == 'Oxygen Saturation')['value'] = latestSpo2 != null ? latestSpo2.toString() : '--';

      double? latestWeight = prefs.getDouble('latest_weight');
      _metricsData.firstWhere((m) => m['title'] == 'Body Weight')['value'] = latestWeight != null ? latestWeight.toStringAsFixed(1) : '--';

      _bodyGoal        = prefs.getString('body_goal') ?? 'maintain';
      _caloriesTarget  = prefs.getDouble('calories_intake_target') ?? 2200;
      _globalStepGoal  = prefs.getInt('step_goal') ?? 10000;
      int goalOffset   = prefs.getInt('goal_offset') ?? 500;

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
    if (result != null) setState(() { _patientData = result; });
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
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)), 
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Customize Dashboard",
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.1), height: 1), 
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return SwitchListTile(
                          activeThumbColor: AppTheme.primaryColor,
                          activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3), 
                          inactiveThumbColor: AppTheme.textSecondary,
                          inactiveTrackColor: AppTheme.textSecondary.withValues(alpha: 0.1), 
                          secondary: Icon(metric['icon'], color: AppTheme.textSecondary),
                          title: Text(metric['title'], style: const TextStyle(color: AppTheme.textPrimary)),
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
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done",
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Select Data to Export",
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.1), height: 1), 
                  
                  Expanded(
                    child: ListView(
                      children: [
                        ..._metricsData.map((metric) {
                          return CheckboxListTile(
                            activeColor: AppTheme.primaryColor,
                            checkColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.textSecondary),
                            secondary: Icon(metric['icon'], color: AppTheme.textSecondary),
                            title: Text(metric['title'], style: const TextStyle(color: AppTheme.textPrimary)),
                            value: metric['isShareSelected'],
                            onChanged: (bool? value) {
                              setModalState(() => metric['isShareSelected'] = value ?? false);
                            },
                          );
                        }).toList(),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(color: AppTheme.textSecondary.withValues(alpha: 0.1), height: 20),
                        ),
                        
                        CheckboxListTile(
                          activeColor: AppTheme.primaryColor,
                          checkColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.textSecondary),
                          secondary: const Icon(Icons.medication, color: AppTheme.textSecondary),
                          title: const Text("Active Medications", style: TextStyle(color: AppTheme.textPrimary)),
                          value: _includeMedicationsInExport,
                          onChanged: (bool? value) {
                            setModalState(() => _includeMedicationsInExport = value ?? false);
                          },
                        ),
                      ],
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
                                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                PdfGenerator.generateAndShare(
                                  selectedMetrics: _selectedMetrics,
                                  patientData: _patientData.toMap(),
                                  activeMedications: _includeMedicationsInExport ? _activeMedications : [],
                                );
                              },
                              child: const Text("Share PDF",
                                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              PdfGenerator.generateAndSave(
                                selectedMetrics: _selectedMetrics,
                                patientData: _patientData.toMap(),
                                activeMedications: _includeMedicationsInExport ? _activeMedications : [],
                                context: context,
                              );
                            },
                            child: const Text("Save PDF",
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
              bool isWideScreen = MediaQuery.of(context).size.width > 800;
              double cardWidth = isWideScreen
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 15,
                runSpacing: 0,
                children: visibleMetrics.map((metric) {
                  return SizedBox(
                    width: cardWidth,
                    child: healthCard(
                      context,
                      metric['icon'],
                      metric['title'],
                      metric['value'],
                      metric['unit'],
                      metric['destination'],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: AppTheme.textPrimary, size: 30),
                onPressed: _showEditMetricsBottomSheet,
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: AppTheme.primaryColor, size: 28),
                onPressed: forceSyncFitbit,
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: AppTheme.textPrimary, size: 28),
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
        if (title == 'Blood Glucose Level') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => BloodGlucose(baseUserData: gatherDataForAI()),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Calories') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => CaloriesMain(
              patientData: _patientData,
              baseUserData: gatherDataForAI(),
            ),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Activity') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => Activity(baseUserData: gatherDataForAI()),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Heart Rate') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => HeartRatePage(baseUserData: gatherDataForAI()),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Oxygen Saturation') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => OxygenSaturationPage(baseUserData: gatherDataForAI()),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Blood Pressure') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => BloodPressurePage(baseUserData: gatherDataForAI()),
          ));
          _fetchDatabaseMetrics();
        } else if (title == 'Body Weight') {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => BodyWeightPage(baseUserData: gatherDataForAI()),
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
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 35),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(unit, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      )
              ],
            ),
          ],
        ),
      ),
    );
  }
}