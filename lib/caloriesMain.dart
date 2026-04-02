import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/cameraCapture.dart';
import 'package:temanu/caloriesSharePage.dart';
import 'package:temanu/fitbitService.dart';
import 'package:temanu/patientData.dart';
import 'package:temanu/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/api_service.dart';
import 'dart:math';

class CaloriesMain extends StatefulWidget {
  final PatientData patientData;
  final Map<String, dynamic> baseUserData;

  const CaloriesMain({super.key, required this.patientData, required this.baseUserData});

  @override
  State<CaloriesMain> createState() => _CaloriesMainState();
}

class _CaloriesMainState extends State<CaloriesMain> with SingleTickerProviderStateMixin {
  double caloriesConsumed = 0;
  double caloriesIntakeTarget = 2200; 
  double caloriesBurnedTarget = 2200; 

  double proteinConsumed = 0, proteinTarget = 140;
  double carbsConsumed = 0, carbsTarget = 250;
  double fatsConsumed = 0, fatsTarget = 70;

  double caloriesBurned = 0;
  bool _isFitbitLoading = true;

  double _liveWeight = 0;
  double _liveHeight = 0;
  int _liveAge = 0;
  String _liveGender = 'Male';

  String _bodyGoal   = 'maintain'; 
  int    _goalOffset = 500;        

  bool _hasEnoughDataForProjection = false;
  int _validLoggingDays = 0;

  List<Map<String, dynamic>> trackedMealsList = [];

  String _activityLevel = 'sedentary';
  static const Map<String, double> _activityMultipliers = {
    'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725, 'very_active': 1.9,
  };
  static const Map<String, String> _activityLabels = {
    'sedentary': 'Sedentary', 'light': 'Lightly Active', 'moderate': 'Moderately Active',
    'active': 'Very Active', 'very_active': 'Extremely Active',
  };
  static const Map<String, String> _activityDescriptions = {
    'sedentary': 'Desk job, little movement', 'light': 'Light exercise 1–3×/week',
    'moderate': 'Moderate exercise 3–5×/week', 'active': 'Hard exercise 6–7×/week',
    'very_active': 'Physical job + hard training',
  };

  late AnimationController _controller;
  late Animation<double> _animation; 

  String _dynamicAiTip = "Analyzing your nutrition...";
  bool _isLoadingTip = true;

  bool _isLoadingInsights = true;
  double _weeklyNetDeficit = 0;
  int _proteinHits = 0, _carbsHits = 0, _fatsHits = 0;
  List<Map<String, dynamic>> _weeklyBars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation  = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    
    // Load fresh data straight from the DB first!
    _fetchFreshUserData().then((_) {
      _loadGoalSettings();
    });
    
    _loadFitbitCalories();
    _loadWeeklyInsights(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- NEW: Fetch exact data from Database ---
  Future<void> _fetchFreshUserData() async {
    final profile = await ApiService.getFullProfile();
    final metrics = await ApiService.getHealthMetrics();

    if (profile != null) {
      _liveGender = profile['gender'] ?? 'Male';
      _liveHeight = double.tryParse(profile['height']?.toString() ?? '0') ?? 0;
      
      // Load Goal Settings from DB!
      _bodyGoal = profile['body_goal'] ?? 'maintain';
      _activityLevel = profile['activity_level'] ?? 'sedentary';
      _goalOffset = profile['goal_offset'] ?? 500;

      // Calculate exact age from DOB
      final dobStr = profile['dob'] ?? '';
      if (dobStr.isNotEmpty) {
        try {
          DateTime dob;
          if (dobStr.contains('/')) {
            final parts = dobStr.split('/');
            dob = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          } else {
            dob = DateTime.parse(dobStr);
          }
          final now = DateTime.now();
          _liveAge = now.year - dob.year;
          if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
            _liveAge--;
          }
        } catch (_) {}
      }
    }

    // Get the absolute latest weight
    final weightLogs = metrics.where((m) => m['metric_type'] == 'Body Weight' || m['body_weight'] != null).toList();
    if (weightLogs.isNotEmpty) {
      weightLogs.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
      _liveWeight = double.tryParse(weightLogs.first['value']?.toString() ?? weightLogs.first['body_weight']?.toString() ?? '0') ?? 0;
    }
  }

  // --- UPDATED: Uses DB variables instead of widget.patientData ---
  double _calculateBMR() {
    if (_liveWeight == 0 || _liveHeight == 0 || _liveAge == 0) return 0;

    final isMale = _liveGender.toLowerCase() == 'male';
    if (isMale) return (10 * _liveWeight) + (6.25 * _liveHeight) - (5 * _liveAge) + 5;
    return (10 * _liveWeight) + (6.25 * _liveHeight) - (5 * _liveAge) - 161;
  }

  double _calculateTDEE() {
    final bmr = _calculateBMR();
    final multiplier = _activityMultipliers[_activityLevel] ?? 1.2;
    return bmr * multiplier;
  }

  void _recalculateTargets() {
    final tdee = _calculateTDEE();
    if (tdee == 0) return; 

    caloriesBurnedTarget = tdee.clamp(500, 9999);

    switch (_bodyGoal) {
      case 'deficit':
        caloriesIntakeTarget = (tdee - _goalOffset).clamp(500, 9999);
        proteinTarget = (caloriesIntakeTarget * 0.35) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.35) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.30) / 9;
        break;
      case 'surplus':
        caloriesIntakeTarget = (tdee + _goalOffset).clamp(500, 9999);
        proteinTarget = (caloriesIntakeTarget * 0.30) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.50) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.20) / 9;
        break;
      default: 
        caloriesIntakeTarget = tdee.clamp(500, 9999);
        proteinTarget = (caloriesIntakeTarget * 0.30) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.40) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.30) / 9;
    }
  }

  Future<void> _loadGoalSettings() async {
    final liveMeals = await ApiService.getTodaysMeals();

    if (mounted) {
      setState(() {
        trackedMealsList = liveMeals.map((e) => Map<String, dynamic>.from(e)).toList();

        caloriesConsumed = 0; proteinConsumed = 0; carbsConsumed = 0; fatsConsumed = 0;
        for (var meal in trackedMealsList) {
          caloriesConsumed += (meal['calories'] as num).toDouble();
          proteinConsumed  += (meal['protein']  as num).toDouble();
          carbsConsumed    += (meal['carbs']    as num).toDouble();
          fatsConsumed     += (meal['fats']     as num).toDouble();
        }
        _recalculateTargets(); 
      });

      _controller.forward(from: 0.0);
      _generateAITip();
    }
  }

  // --- UPDATED: Save directly to Backend ---
  Future<void> _saveGoalSettings() async {
    // Save to Database!
    await ApiService.updateProfile(
      bodyGoal: _bodyGoal,
      activityLevel: _activityLevel,
      goalOffset: _goalOffset,
    );

    // Keep local cache for offline scenarios
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('body_goal',      _bodyGoal);
    await prefs.setInt('goal_offset',       _goalOffset);
    await prefs.setString('activity_level', _activityLevel);
    await prefs.setDouble('protein_target', proteinTarget);
    await prefs.setDouble('carbs_target', carbsTarget);
    await prefs.setDouble('fats_target', fatsTarget);
  }

  Future<void> _loadFitbitCalories({bool forceRefresh = false}) async {
    setState(() => _isFitbitLoading = true);
    
    final result = await FitbitService.getCaloriesBurned(forceRefresh: forceRefresh);
    
    if (mounted && result != null && result != '--') {
      setState(() {
        caloriesBurned = double.tryParse(result) ?? 0;
      });
      
      _controller.forward(from: 0.0); 
    }
    
    if (mounted) setState(() => _isFitbitLoading = false);
  }

  // 1. Add the parameter here
  Future<void> _loadWeeklyInsights({bool forceRefresh = false}) async {
    setState(() => _isLoadingInsights = true);

    // 2. Pass it down to the ApiService!
    final weeklyData = await ApiService.getWeeklyInsights(forceRefresh: forceRefresh);
    
    double accumulatedDeficit = 0;
    int validLoggingDays = 0; // Track how many days they actually used the app
    
    int pHits = 0, cHits = 0, fHits = 0;
    List<Map<String, dynamic>> bars = [];

    for (var day in weeklyData) {
      double consumed = (day['consumed'] as num).toDouble();
      double burned = (day['burned'] as num).toDouble();
      double p = (day['protein'] as num).toDouble();
      double c = (day['carbs'] as num).toDouble();
      double f = (day['fats'] as num).toDouble();

      double actualBurned = burned > 0 ? burned : caloriesBurnedTarget;

      if (consumed > 0) {
        accumulatedDeficit += (actualBurned - consumed);
        validLoggingDays++;
      }

      if (p >= (proteinTarget * 0.9)) pHits++;
      if (c >= (carbsTarget * 0.9)) cHits++;
      if (f >= (fatsTarget * 0.9)) fHits++;

      bars.add({
        "day": day['day_name'],
        "consumed": consumed,
        "burned": actualBurned,
      });
    }

    if (mounted) {
      setState(() {
        // If they have at least 1 day of data, calculate their average daily deficit 
        // and multiply by 7 for a full-week projection!
        if (validLoggingDays > 0) {
          _weeklyNetDeficit = (accumulatedDeficit / validLoggingDays) * 7;
          _hasEnoughDataForProjection = true;
        } else {
          _weeklyNetDeficit = 0;
          _hasEnoughDataForProjection = false; // Flag that they are brand new
        }

        _validLoggingDays = validLoggingDays;
        
        _proteinHits = pHits;
        _carbsHits = cHits;
        _fatsHits = fHits;
        _weeklyBars = bars;
        _isLoadingInsights = false;
      });
    }
  }

  void _showGoalSettingsSheet() {
    String tempGoal          = _bodyGoal;
    int    tempOffset        = _goalOffset;
    String tempActivityLevel = _activityLevel;
    final  offsetController  = TextEditingController(text: _goalOffset.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {

            final double bmr  = _calculateBMR();
            final double tdee = bmr * (_activityMultipliers[tempActivityLevel] ?? 1.2);

            int signedOffset = 0;
            if (tempGoal == 'deficit') signedOffset = -tempOffset;
            if (tempGoal == 'surplus') signedOffset =  tempOffset;

            final int liveIntakeTarget = (tdee + signedOffset).clamp(500, 9999).toInt();
            final int liveBurnTarget   = tdee.clamp(500, 9999).toInt();
            final int liveNet          = liveIntakeTarget - liveBurnTarget;

            final bool patientDataMissing = bmr == 0;

            Color goalColor() {
              if (tempGoal == 'deficit') return Colors.orangeAccent;
              if (tempGoal == 'surplus') return Colors.greenAccent;
              return AppTheme.primaryColor;
            }

            String goalDescription() {
              if (patientDataMissing) return "Complete your profile to enable automatic calculation.";
              if (tempGoal == 'deficit') return "Eat $tempOffset kcal less than you burn to lose weight.";
              if (tempGoal == 'surplus') return "Eat $tempOffset kcal more than you burn to gain muscle.";
              return "Eat exactly what you burn to maintain your current weight.";
            }

            InputDecoration fieldDecoration() => InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: goalColor(), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            );

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Center(
                        child: Container(
                          height: 5, width: 50,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text("Calorie Goal Settings",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text("Your goals are calculated from your BMR and activity level.",
                        style: TextStyle(color: Colors.white54, fontSize: 13)),

                      const SizedBox(height: 28),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: patientDataMissing
                          ? const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Profile incomplete. Add your height, weight, age and gender on the Profile page to enable BMR calculation.",
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _bmrStat("Height", "${_liveHeight.toStringAsFixed(0)} cm", Colors.white70),
                                _dividerLine(),
                                _bmrStat("Weight", "${_liveWeight.toStringAsFixed(1)} kg", Colors.white70),
                                _dividerLine(),
                                _bmrStat("Age",    "$_liveAge yrs",   Colors.white70),
                                _dividerLine(),
                                _bmrStat("BMR",    "${bmr.toInt()} kcal",             AppTheme.primaryColor),
                              ],
                            ),
                      ),

                      const SizedBox(height: 28),

                      const Text("Activity Level",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        "TDEE: ${tdee.toInt()} kcal/day  ·  BMR × ${(_activityMultipliers[tempActivityLevel] ?? 1.2).toStringAsFixed(3)}",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      ..._activityMultipliers.keys.map((level) {
                        final isSelected = tempActivityLevel == level;
                        return GestureDetector(
                          onTap: () => setSheetState(() => tempActivityLevel = level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.12) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.white12,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_activityLabels[level]!,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.primaryColor : Colors.white,
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        )),
                                      const SizedBox(height: 2),
                                      Text(_activityDescriptions[level]!,
                                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 28),

                      const Text("Body Goal",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _goalChip(setSheetState, "deficit",  "Deficit",  tempGoal, (v) => tempGoal = v, Colors.orangeAccent),
                          const SizedBox(width: 10),
                          _goalChip(setSheetState, "maintain", "Maintain", tempGoal, (v) => tempGoal = v, const Color(0xff00E5FF)),
                          const SizedBox(width: 10),
                          _goalChip(setSheetState, "surplus",  "Surplus",  tempGoal, (v) => tempGoal = v, Colors.greenAccent),
                        ],
                      ),

                      if (tempGoal != 'maintain') ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tempGoal == 'deficit' ? "Deficit Amount" : "Surplus Amount",
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [200, 300, 500].map((preset) {
                                final isActive = tempOffset == preset;
                                return GestureDetector(
                                  onTap: () => setSheetState(() {
                                    tempOffset = preset;
                                    offsetController.text = preset.toString();
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isActive ? goalColor().withValues(alpha: 0.15) : Colors.transparent, 
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isActive ? goalColor() : Colors.white24,
                                        width: isActive ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Text("$preset",
                                      style: TextStyle(
                                        color: isActive ? goalColor() : Colors.white54,
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      )),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: goalColor(),
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: goalColor(),
                                  overlayColor: goalColor().withValues(alpha: 0.15), 
                                  trackHeight: 5,
                                ),
                                child: Slider(
                                  value: tempOffset.toDouble().clamp(50, 1000),
                                  min: 50, max: 1000, divisions: 19,
                                  onChanged: (val) => setSheetState(() {
                                    tempOffset = val.toInt();
                                    offsetController.text = tempOffset.toString();
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: offsetController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                style: TextStyle(color: goalColor(), fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: fieldDecoration().copyWith(
                                  hintText: "kcal",
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                                  suffixText: "kcal",
                                  suffixStyle: TextStyle(color: goalColor(), fontSize: 11),
                                ),
                                onChanged: (val) => setSheetState(() {
                                  final parsed = int.tryParse(val);
                                  if (parsed != null) tempOffset = parsed.clamp(50, 1000);
                                }),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 108),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("50",   style: TextStyle(color: Colors.white24, fontSize: 11)),
                              Text("1000", style: TextStyle(color: Colors.white24, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: goalColor().withValues(alpha: 0.07), 
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: goalColor().withValues(alpha: 0.4)), 
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goalDescription(),
                              style: TextStyle(color: goalColor(), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _previewStat("Burn Goal",   "$liveBurnTarget kcal",   const Color(0xff00E676)),
                                Container(width: 1, height: 38, color: Colors.white12),
                                _previewStat("Intake Goal", "$liveIntakeTarget kcal", const Color(0xff00E5FF)),
                                Container(width: 1, height: 38, color: Colors.white12),
                                _previewStat(
                                  "Net",
                                  "${liveNet >= 0 ? '+' : ''}$liveNet kcal",
                                  liveNet <= 0 ? Colors.greenAccent : Colors.orangeAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      GestureDetector(
                        onTap: patientDataMissing ? null : () async {
                          setState(() {
                            _bodyGoal      = tempGoal;
                            _goalOffset    = tempOffset;
                            _activityLevel = tempActivityLevel;
                            _recalculateTargets();
                          });
                          
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving goals..."), duration: Duration(seconds: 1)));
                          
                          await _saveGoalSettings(); // Saves to database!
                          
                          _generateAITip(forceRefresh: true);
                          _loadWeeklyInsights(); 

                          if(mounted) Navigator.pop(context);
                          _controller.forward(from: 0.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: patientDataMissing
                                ? Colors.white.withValues(alpha: 0.05) 
                                : AppTheme.primaryColor.withValues(alpha: 0.1), 
                            border: Border.all(
                              color: patientDataMissing ? Colors.white12 : AppTheme.primaryColor,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              patientDataMissing ? "Complete your profile first" : "Save Goals",
                              style: TextStyle(
                                color: patientDataMissing ? Colors.white24 : AppTheme.primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _bmrStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _dividerLine() => Container(width: 1, height: 32, color: Colors.white12);

  Widget _goalChip(
    StateSetter setSheetState, String value, String label, String current,
    ValueSetter<String> onSelect, Color activeColor,
  ) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setSheetState(() => onSelect(value)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent, 
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.white70,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            )),
        ),
      ),
    );
  }

  Widget _previewStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _generateAITip({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached');
      if (cachedTip != null && cachedTip.isNotEmpty) {
        if (mounted) setState(() { _dynamicAiTip = cachedTip; _isLoadingTip = false; });
        return; 
      }
    }

    if (mounted) setState(() => _isLoadingTip = true);

    // --- NEW CLEAN LOGIC ---
    final prompt = '''
      The user, ${widget.patientData.name}, is aiming to $_bodyGoal their weight.
      Today's Progress:
      - Calories: ${caloriesConsumed.toInt()} / ${caloriesIntakeTarget.toInt()} kcal
      - Protein: ${proteinConsumed.toInt()}g / ${proteinTarget.toInt()}g
      - Carbs: ${carbsConsumed.toInt()}g / ${carbsTarget.toInt()}g
      - Fats: ${fatsConsumed.toInt()}g / ${fatsTarget.toInt()}g
      Write a SHORT, 2-sentence encouraging insight or tip based exactly on these numbers.
    ''';

    final newTip = await ApiService.getAITip(prompt);

    if (mounted) {
      if (newTip != null) {
        await prefs.setString('ai_tip_cached', newTip);
        setState(() { _dynamicAiTip = newTip; _isLoadingTip = false; });
      } else {
        setState(() {
          _dynamicAiTip = "Keep up the great work today! Tap here to chat for more insights.";
          _isLoadingTip = false;
        });
      }
    }
  }

  void openSharePage() {
    final now = DateTime.now();
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final dateStr = "${now.day} ${months[now.month - 1]} ${now.year}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaloriesSharePage(
          caloriesConsumed: caloriesConsumed,
          caloriesIntakeTarget: caloriesIntakeTarget,
          caloriesBurned: caloriesBurned,
          caloriesBurnedTarget: caloriesBurnedTarget,
          bodyGoal: _bodyGoal,
          dateRangeLabel: dateStr,
          userName: widget.patientData.name.isNotEmpty ? widget.patientData.name : 'User',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: const Text("Calories",
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 25, fontWeight: FontWeight.w600)),
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
              icon: _isFitbitLoading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2))
                  : const Icon(Icons.sync, color: AppTheme.primaryColor),
              onPressed: _isFitbitLoading ? null : () {
                _loadFitbitCalories(forceRefresh: true);
                _loadWeeklyInsights(forceRefresh: true);
              },
            ),
            IconButton(
              onPressed: openSharePage,
              icon: const Icon(Icons.ios_share, color: Colors.white),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Today"),
              Tab(text: "Insights & Trends"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTodayTab(),
            _buildInsightsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 850;
        final double bottomSafeArea = MediaQuery.paddingOf(context).bottom;

        if (isWideScreen) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildSideBySideCalorieRings(),
                      const SizedBox(height: 16),
                      _buildCombinedMacrosCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAiTipCard(),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Meals Today",
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          _buildAddMealButton(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...trackedMealsList.map((meal) => _buildMealListItem(meal)),
                      SizedBox(height: 40 + bottomSafeArea),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSideBySideCalorieRings(),
                const SizedBox(height: 16),
                _buildCombinedMacrosCard(),
                const SizedBox(height: 16),
                _buildAiTipCard(),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Meals Today",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    _buildAddMealButton(),
                  ],
                ),
                const SizedBox(height: 16),
                ...trackedMealsList.map((meal) => _buildMealListItem(meal)),
                SizedBox(height: 40 + bottomSafeArea),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildInsightsTab() {
    if (_isLoadingInsights) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    double projectedKg = (_weeklyNetDeficit / 7700).abs();
    
    // --- DEFAULT "EMPTY STATE" FOR NEW USERS ---
    String projectionTitle = "Start Tracking!";
    String projectionText = "Log your meals for the day to unlock your weekly weight projection based on your energy balance.";
    Color projectionColor = const Color(0xff00E5FF);
    IconData projectionIcon = Icons.restaurant_menu;

    // --- OVERWRITE WITH REAL DATA IF AVAILABLE ---
    if (_hasEnoughDataForProjection) {
      if (_weeklyNetDeficit > 300) { 
        projectionTitle = "Projected Fat Loss";
        projectionText = "Great job! Based on your active days, you are on track to lose ~${projectedKg.toStringAsFixed(2)} kg of fat this week.";
        projectionColor = Colors.orangeAccent;
        projectionIcon = Icons.trending_down;
      } else if (_weeklyNetDeficit < -300) { 
        projectionTitle = "Projected Weight Gain";
        projectionText = "Based on your active days, you are on track to gain ~${projectedKg.toStringAsFixed(2)} kg this week.";
        projectionColor = Colors.greenAccent;
        projectionIcon = Icons.trending_up;
      } else {
        projectionTitle = "Maintaining Weight";
        projectionText = "Your energy balance is perfectly level. You are projected to maintain your current weight.";
        projectionColor = const Color(0xff00E5FF);
        projectionIcon = Icons.balance;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 850;
        final double bottomSafeArea = MediaQuery.paddingOf(context).bottom;

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
                      _buildWeeklyEnergyBalanceHeader(),
                      const SizedBox(height: 16),
                      _buildWeeklyEnergyBalanceChart(),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProjectedImpactCard(projectedKg, projectionTitle, projectionText, projectionColor, projectionIcon),
                      const SizedBox(height: 32),
                      _buildMacroConsistencyHeader(),
                      const SizedBox(height: 16),
                      _buildMacroConsistencyCard(),
                      SizedBox(height: 40 + bottomSafeArea),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProjectedImpactCard(projectedKg, projectionTitle, projectionText, projectionColor, projectionIcon),
                const SizedBox(height: 24),
                _buildWeeklyEnergyBalanceHeader(),
                const SizedBox(height: 16),
                _buildWeeklyEnergyBalanceChart(),
                const SizedBox(height: 24),
                _buildMacroConsistencyHeader(),
                const SizedBox(height: 16),
                _buildMacroConsistencyCard(),
                SizedBox(height: 40 + bottomSafeArea),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildAiTipCard() {
    return InkWell(
      onTap: () {
        final updatedData = Map<String, dynamic>.from(widget.baseUserData);
        updatedData['caloriesEaten'] = caloriesConsumed;
        updatedData['proteinConsumed'] = proteinConsumed;
        updatedData['carbsConsumed'] = carbsConsumed;
        updatedData['fatsConsumed'] = fatsConsumed;
        updatedData['caloriesIntakeTarget'] = caloriesIntakeTarget;
        updatedData['proteinTarget'] = proteinTarget;
        updatedData['carbsTarget'] = carbsTarget;
        updatedData['fatsTarget'] = fatsTarget;

        Navigator.push(context, MaterialPageRoute(builder: (_) => AssistantPage(userData: updatedData)));
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
                    const Padding(padding: EdgeInsets.only(top: 2.0), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2))),
                    const SizedBox(width: 12),
                    const Expanded(child: Text("Analyzing your latest data...", style: TextStyle(color: Colors.white70, fontSize: 14))),
                  ],
                )
              : Text(_dynamicAiTip, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySideCalorieRings() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final consumedProgress = (caloriesConsumed / caloriesIntakeTarget).clamp(0.0, 1.0) * _animation.value;
        final burnedProgress   = (caloriesBurned   / caloriesBurnedTarget).clamp(0.0, 1.0) * _animation.value;

        Color goalColor() {
          if (_bodyGoal == 'deficit') return Colors.orangeAccent;
          if (_bodyGoal == 'surplus') return Colors.greenAccent;
          return const Color(0xff00E5FF);
        }
        String goalTypeLabel() {
          if (_bodyGoal == 'deficit') return 'Deficit';
          if (_bodyGoal == 'surplus') return 'Surplus';
          return 'Maintain';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground, 
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _showGoalSettingsSheet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Goal: ", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                    Text(goalTypeLabel(), style: TextStyle(color: goalColor(), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Icon(Icons.edit, color: goalColor(), size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRing(label: "Consumed", currentValue: (caloriesConsumed * _animation.value).toInt(), target: caloriesIntakeTarget.toInt(), progress: consumedProgress, ringColor: AppTheme.primaryColor, isLoading: false),
                  Container(height: 120, width: 1, color: Colors.white12),
                  _buildRing(label: "Burned", currentValue: (caloriesBurned * _animation.value).toInt(), target: caloriesBurnedTarget.toInt(), progress: burnedProgress, ringColor: const Color(0xff00E676), isLoading: _isFitbitLoading),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRing({required String label, required int currentValue, required int target, required double progress, required Color ringColor, required bool isLoading}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(height: 120, width: 120, child: CircularProgressIndicator(value: 1.0, strokeWidth: 10, color: Colors.white.withValues(alpha: 0.08))), 
            SizedBox(height: 120, width: 120, child: CircularProgressIndicator(value: progress, strokeWidth: 10, color: ringColor, backgroundColor: Colors.transparent, strokeCap: StrokeCap.round)),
            isLoading
              ? SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: ringColor, strokeWidth: 2.5))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("$currentValue", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text("kcal", style: TextStyle(color: Colors.white54, fontSize: 13)),
                ]),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text("Goal: $target kcal", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildCombinedMacrosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground, 
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSingleMacroColumn("Protein", proteinConsumed, proteinTarget, Colors.redAccent),
          _buildSingleMacroColumn("Carbs", carbsConsumed, carbsTarget, Colors.orangeAccent),
          _buildSingleMacroColumn("Fats", fatsConsumed, fatsTarget, Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildSingleMacroColumn(String title, double consumed, double target, Color progressColor) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = (consumed / target).clamp(0.0, 1.0) * _animation.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(height: 75, width: 75, child: CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: Colors.white.withValues(alpha: 0.1))), 
                SizedBox(height: 75, width: 75, child: CircularProgressIndicator(value: progress, strokeWidth: 8, color: progressColor, backgroundColor: Colors.transparent, strokeCap: StrokeCap.round)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("${(consumed * _animation.value).toInt()}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("g", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Target: ${target.toInt()}g", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildMealListItem(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(meal["name"], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Text("${meal["calories"]} kcal", style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallMacroText("Protein", (meal["protein"] as num).toInt(), Colors.redAccent),
              _buildSmallMacroText("Carbs", (meal["carbs"] as num).toInt(), Colors.orangeAccent),
              _buildSmallMacroText("Fats", (meal["fats"] as num).toInt(), Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMacroText(String title, int amount, Color dotColor) {
    return Row(
      children: [
        Icon(Icons.circle, color: dotColor, size: 10),
        const SizedBox(width: 6),
        Text("$title: ", style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text("${amount}g", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAddMealButton() {
    return GestureDetector(
      onTap: () async {
        final newMeal = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackMealCameraPage()));
        if (newMeal != null && newMeal is Map<String, dynamic>) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving meal to cloud..."), duration: Duration(seconds: 1)));
          bool success = await ApiService.saveMeal(
            name: newMeal["name"], calories: (newMeal["calories"] as num).toInt(),
            protein: (newMeal["protein"] as num).toDouble(), carbs: (newMeal["carbs"] as num).toDouble(), fats: (newMeal["fats"] as num).toDouble(),
          );
          if (success) {
            await _loadGoalSettings();
            _generateAITip(forceRefresh: true);
            _controller.forward(from: 0.0);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal tracked successfully!"), backgroundColor: Color(0xff00E676)));
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save meal. Please try again."), backgroundColor: Colors.redAccent));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xff00E676), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Color(0xff040F31), size: 18),
            SizedBox(width: 4),
            Text("Track", style: TextStyle(color: Color(0xff040F31), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectedImpactCard(double projectedKg, String projectionTitle, String projectionText, Color projectionColor, IconData projectionIcon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: projectionColor.withValues(alpha: 0.5), width: 1.5), 
      ),
      child: Column(
        children: [
          Icon(projectionIcon, color: projectionColor, size: 40),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(projectionTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showInfoDialog(
                  "Projected Impact", 
                  "This projection is based on the scientific rule that a net deficit of ~7,700 kcal equates to roughly 1 kg of fat loss. It averages your 7-day energy balance to predict future results."
                ),
                child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(projectionText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildWeeklyEnergyBalanceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Weekly Energy Balance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.info_outline, color: Colors.white54, size: 22),
          onPressed: () => _showInfoDialog(
            "Energy Balance", 
            "This chart compares the calories you consumed (food) against the calories you burned (BMR + activity)."
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyEnergyBalanceChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.circle, color: AppTheme.primaryColor, size: 10),
              const SizedBox(width: 5),
              const Text("Consumed", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 20),
              const Icon(Icons.circle, color: Color(0xff00E676), size: 10),
              const SizedBox(width: 5),
              const Text("Burned", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyBars.map((dayData) {
                double maxVal = max(dayData['consumed'], dayData['burned']);
                if (maxVal < 1) maxVal = 1; 
                
                double consumedHeight = (dayData['consumed'] / maxVal) * 120;
                double burnedHeight = (dayData['burned'] / maxVal) * 120;

                return Tooltip(
                  triggerMode: TooltipTriggerMode.tap, 
                  showDuration: const Duration(seconds: 3), 
                  preferBelow: false, 
                  verticalOffset: 20, 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: 0.95), 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)), 
                  ),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                  richMessage: TextSpan(
                    children: [
                      TextSpan(text: "${dayData['day']}\n", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      TextSpan(text: "Consumed: ", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))), 
                      TextSpan(text: "${dayData['consumed'].toInt()} kcal\n", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      TextSpan(text: "Burned: ", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))), 
                      TextSpan(text: "${dayData['burned'].toInt()} kcal", style: const TextStyle(color: Color(0xff00E676), fontWeight: FontWeight.bold)),
                    ]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(width: 10, height: consumedHeight, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(5))),
                          const SizedBox(width: 4),
                          Container(width: 10, height: burnedHeight, decoration: BoxDecoration(color: const Color(0xff00E676), borderRadius: BorderRadius.circular(5))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(dayData['day'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroConsistencyHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Macro Consistency", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.info_outline, color: Colors.white54, size: 22),
          onPressed: () => _showInfoDialog(
            "Macro Consistency", 
            // --- UPDATED TEXT HERE ---
            "This score shows how many days over the last week you successfully met your goals. It only grades you on the days you actually logged meals!"
          ),
        ),
      ],
    );
  }

  Widget _buildMacroConsistencyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Pass the dynamic _validLoggingDays instead of letting it default to 7!
          _buildMiniMacroCircle("Protein", _proteinHits, _validLoggingDays, Colors.redAccent),
          _buildMiniMacroCircle("Carbs",   _carbsHits,   _validLoggingDays, Colors.orangeAccent),
          _buildMiniMacroCircle("Fats",    _fatsHits,    _validLoggingDays, Colors.purpleAccent),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(content, style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it", style: TextStyle(color: Color(0xff00E5FF), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacroCircle(String label, int hits, int totalDays, Color color) {
    // Prevent "divide by zero" crashes for brand new users
    final double progress = totalDays > 0 ? (hits / totalDays) : 0.0;
    
    // Show a friendly "-/-" if they have 0 days, otherwise show "2/3", "5/5", etc.
    final String displayFraction = totalDays > 0 ? "$hits/$totalDays" : "-/-";

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(height: 60, width: 60, child: CircularProgressIndicator(value: 1.0, strokeWidth: 6, color: Colors.white.withValues(alpha: 0.1))), 
            SizedBox(height: 60, width: 60, child: CircularProgressIndicator(value: progress, strokeWidth: 6, color: color, strokeCap: StrokeCap.round, backgroundColor: Colors.transparent)),
            Text(displayFraction, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}