import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/cameraCapture.dart';
import 'package:temanu/fitbitService.dart';
import 'package:temanu/patientData.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaloriesMain extends StatefulWidget {
  // PatientData is passed in from HomePage so we can read height, weight, age, gender
  final PatientData patientData;
  final Map<String, dynamic> baseUserData;

  const CaloriesMain({super.key, required this.patientData, required this.baseUserData,});

  @override
  State<CaloriesMain> createState() => _CaloriesMainState();
}

class _CaloriesMainState extends State<CaloriesMain> with SingleTickerProviderStateMixin {
  double caloriesConsumed = 0;

  // Both targets are DERIVED from BMR/TDEE — never set directly by the user
  double caloriesIntakeTarget = 2200; // What they should EAT
  double caloriesBurnedTarget = 2200; // What they should BURN (= TDEE)

  double proteinConsumed = 0;
  double proteinTarget = 140;

  double carbsConsumed = 0;
  double carbsTarget = 250;

  double fatsConsumed = 0;
  double fatsTarget = 70;

  // Fitbit calories burned
  double caloriesBurned = 0;
  bool _isFitbitLoading = true;

  // Goal settings
  String _bodyGoal   = 'maintain'; // 'deficit' | 'maintain' | 'surplus'
  int    _goalOffset = 500;        // Always positive; applied as ± against TDEE

  List<Map<String, dynamic>> trackedMealsList = [];

  // Activity level multipliers (Mifflin-St Jeor standard)
  String _activityLevel = 'sedentary';
  static const Map<String, double> _activityMultipliers = {
    'sedentary':   1.2,
    'light':       1.375,
    'moderate':    1.55,
    'active':      1.725,
    'very_active': 1.9,
  };
  static const Map<String, String> _activityLabels = {
    'sedentary':   'Sedentary',
    'light':       'Lightly Active',
    'moderate':    'Moderately Active',
    'active':      'Very Active',
    'very_active': 'Extremely Active',
  };
  static const Map<String, String> _activityDescriptions = {
    'sedentary':   'Desk job, little movement',
    'light':       'Light exercise 1–3×/week',
    'moderate':    'Moderate exercise 3–5×/week',
    'active':      'Hard exercise 6–7×/week',
    'very_active': 'Physical job + hard training',
  };

  late AnimationController _controller;
  late Animation<double> _animation; 

  String _dynamicAiTip = "Analyzing your nutrition...";
  bool _isLoadingTip = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation  = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
    _loadGoalSettings();
    _loadFitbitCalories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── BMR / TDEE Calculations ──────────────────────────────────────────────

  /// Mifflin-St Jeor BMR using PatientData fields.
  /// Returns 0 if any required field is missing or unparseable.
  double _calculateBMR() {
    final weight = double.tryParse(widget.patientData.weight) ?? 0;
    final height = double.tryParse(widget.patientData.height) ?? 0;
    final age    = int.tryParse(widget.patientData.age)       ?? 0;

    if (weight == 0 || height == 0 || age == 0) return 0;

    final isMale = widget.patientData.gender.toLowerCase() == 'male';
    if (isMale) {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  /// TDEE = BMR × activity multiplier.
  double _calculateTDEE() {
    final bmr        = _calculateBMR();
    final multiplier = _activityMultipliers[_activityLevel] ?? 1.2;
    return bmr * multiplier;
  }

  /// Recalculates both targets from TDEE:
  ///   Burn target   = TDEE  (realistic daily burn)
  ///   Intake target = TDEE - offset (deficit) | TDEE (maintain) | TDEE + offset (surplus)
  void _recalculateTargets() {
    final tdee = _calculateTDEE();
    if (tdee == 0) return; // PatientData incomplete — leave existing values

    caloriesBurnedTarget = tdee.clamp(500, 9999);

    switch (_bodyGoal) {
      case 'deficit':
        caloriesIntakeTarget = (tdee - _goalOffset).clamp(500, 9999);
        // Deficit Split: 35% Protein, 35% Carbs, 30% Fats
        proteinTarget = (caloriesIntakeTarget * 0.35) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.35) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.30) / 9;
        break;
        
      case 'surplus':
        caloriesIntakeTarget = (tdee + _goalOffset).clamp(500, 9999);
        // Surplus Split: 30% Protein, 50% Carbs, 20% Fats
        proteinTarget = (caloriesIntakeTarget * 0.30) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.50) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.20) / 9;
        break;
        
      default: // maintain
        caloriesIntakeTarget = tdee.clamp(500, 9999);
        // Maintain Split: 30% Protein, 40% Carbs, 30% Fats
        proteinTarget = (caloriesIntakeTarget * 0.30) / 4;
        carbsTarget   = (caloriesIntakeTarget * 0.40) / 4;
        fatsTarget    = (caloriesIntakeTarget * 0.30) / 9;
    }
  }

  // ─── Persistence ──────────────────────────────────────────────────────────
  Future<void> _loadGoalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bodyGoal      = prefs.getString('body_goal') ?? 'maintain';
      _goalOffset    = prefs.getInt('goal_offset') ?? 500;
      _activityLevel = prefs.getString('activity_level') ?? 'sedentary';
    });

    // 1. Fetch LIVE meals from the Python backend!
    final liveMeals = await ApiService.getTodaysMeals();

    setState(() {
      // Map the backend JSON safely into our Dart list
      trackedMealsList = liveMeals.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2. Dynamically calculate ALL totals by looping through the live meals
      caloriesConsumed = 0;
      proteinConsumed = 0;
      carbsConsumed = 0;
      fatsConsumed = 0;

      for (var meal in trackedMealsList) {
        caloriesConsumed += (meal['calories'] as num).toDouble();
        proteinConsumed  += (meal['protein']  as num).toDouble();
        carbsConsumed    += (meal['carbs']    as num).toDouble();
        fatsConsumed     += (meal['fats']     as num).toDouble();
      }

      _recalculateTargets(); 
    });
    
    // Now that we have live data, ask Gemini for a fresh tip
    _generateAITip();
  }

  Future<void> _saveGoalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('body_goal',      _bodyGoal);
    await prefs.setInt('goal_offset',       _goalOffset);
    await prefs.setString('activity_level', _activityLevel);
    
    // NEW: Save the calculated macro targets!
    await prefs.setDouble('protein_target', proteinTarget);
    await prefs.setDouble('carbs_target', carbsTarget);
    await prefs.setDouble('fats_target', fatsTarget);
  }

  // ─── Fitbit ───────────────────────────────────────────────────────────────

  Future<void> _loadFitbitCalories({bool forceRefresh = false}) async {
    setState(() => _isFitbitLoading = true);
    final token = await FitbitService.getSilentToken();
    if (token != null) {
      final result = await FitbitService.getCaloriesBurned(token, forceRefresh: forceRefresh);
      if (mounted && result != null && result != '--') {
        setState(() => caloriesBurned = double.tryParse(result) ?? 0);
      }
    }
    if (mounted) setState(() => _isFitbitLoading = false);
  }

  // ─── Goal Settings Bottom Sheet ───────────────────────────────────────────

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
              return const Color(0xff00E5FF);
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
                  color: Color(0xff1A3F6B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Handle bar
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

                      // ── BMR Info Card ──────────────────────────────────────
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
                                    "Profile incomplete. Add your height, weight, age and gender to enable BMR calculation.",
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _bmrStat("Height", "${widget.patientData.height} cm", Colors.white70),
                                _dividerLine(),
                                _bmrStat("Weight", "${widget.patientData.weight} kg", Colors.white70),
                                _dividerLine(),
                                _bmrStat("Age",    "${widget.patientData.age} yrs",   Colors.white70),
                                _dividerLine(),
                                _bmrStat("BMR",    "${bmr.toInt()} kcal",             const Color(0xff00E5FF)),
                              ],
                            ),
                      ),

                      const SizedBox(height: 28),

                      // ── Activity Level ────────────────────────────────────
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
                                  ? const Color(0xff00E5FF).withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xff00E5FF) : Colors.white12,
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
                                          color: isSelected ? const Color(0xff00E5FF) : Colors.white,
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
                                  const Icon(Icons.check_circle, color: Color(0xff00E5FF), size: 18),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 28),

                      // ── Body Goal Chips ───────────────────────────────────
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

                      // ── Offset adjuster (hidden for Maintain) ─────────────
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

                      // ── Live Preview ──────────────────────────────────────
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

                      // ── Save Button ───────────────────────────────────────
                      GestureDetector(
                        onTap: patientDataMissing ? null : () {
                          setState(() {
                            _bodyGoal      = tempGoal;
                            _goalOffset    = tempOffset;
                            _activityLevel = tempActivityLevel;
                            _recalculateTargets();
                          });
                          _saveGoalSettings();

                          // FORCE A FRESH TIP because the targets changed!
                          _generateAITip(forceRefresh: true);

                          Navigator.pop(context);
                          _controller.forward(from: 0.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: patientDataMissing
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xff00E5FF).withValues(alpha: 0.1),
                            border: Border.all(
                              color: patientDataMissing ? Colors.white12 : const Color(0xff00E5FF),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              patientDataMissing ? "Complete your profile first" : "Save Goals",
                              style: TextStyle(
                                color: patientDataMissing ? Colors.white24 : const Color(0xff00E5FF),
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

  // ─── Small helper widgets ─────────────────────────────────────────────────

  Widget _bmrStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _dividerLine() =>
      Container(width: 1, height: 32, color: Colors.white12);

  Widget _goalChip(
    StateSetter setSheetState,
    String value,
    String label,
    String current,
    ValueSetter<String> onSelect,
    Color activeColor,
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

    // 1. Check the cache first if we aren't forcing a refresh
    if (!forceRefresh) {
      final cachedTip = prefs.getString('ai_tip_cached');
      if (cachedTip != null && cachedTip.isNotEmpty) {
        if (mounted) {
          setState(() {
            _dynamicAiTip = cachedTip;
            _isLoadingTip = false;
          });
        }
        return; // Exit early! No API call needed.
      }
    }

    // 2. If we need a new tip, show the loader and call Gemini
    if (mounted) setState(() => _isLoadingTip = true);

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) return;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.4),
      );

      final prompt = '''
        You are a concise health AI assistant. The user, ${widget.patientData.name}, is aiming to $_bodyGoal their weight.
        Today's Progress:
        - Calories: ${caloriesConsumed.toInt()} / ${caloriesIntakeTarget.toInt()} kcal
        - Protein: ${proteinConsumed.toInt()}g / ${proteinTarget.toInt()}g
        - Carbs: ${carbsConsumed.toInt()}g / ${carbsTarget.toInt()}g
        - Fats: ${fatsConsumed.toInt()}g / ${fatsTarget.toInt()}g
        
        Write a SHORT, 2-sentence encouraging insight or tip based exactly on these numbers. 
        Keep it under 120 characters. Do not use asterisks or markdown formatting.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted && response.text != null) {
        final newTip = response.text!.trim();
        
        // 3. Save the brand new tip to the cache!
        await prefs.setString('ai_tip_cached', newTip);

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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      extendBodyBehindAppBar: false,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xff55607D),
        elevation: 0,
        centerTitle: false,
        title: const Text("Calories",
          style: TextStyle(color: Color(0xff35E0FF), fontSize: 25, fontWeight: FontWeight.w600)),
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
            icon: _isFitbitLoading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Color(0xff35E0FF), strokeWidth: 2))
                : const Icon(Icons.sync, color: Color(0xff35E0FF)),
            onPressed: _isFitbitLoading ? null : () => _loadFitbitCalories(forceRefresh: true),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSideBySideCalorieRings(),
              const SizedBox(height: 15),
              _buildCombinedMacrosCard(),
              const SizedBox(height: 15),
              // ── AI Tips ──
              InkWell(
                onTap: () {
                  // 1. Copy the base data from the homepage
                  final updatedData = Map<String, dynamic>.from(widget.baseUserData);
                  
                  // 2. Overwrite it with the hyper-accurate live data from this page
                  updatedData['caloriesEaten'] = caloriesConsumed;
                  updatedData['proteinConsumed'] = proteinConsumed;
                  updatedData['carbsConsumed'] = carbsConsumed;
                  updatedData['fatsConsumed'] = fatsConsumed;
                  
                  updatedData['caloriesIntakeTarget'] = caloriesIntakeTarget;
                  updatedData['proteinTarget'] = proteinTarget;
                  updatedData['carbsTarget'] = carbsTarget;
                  updatedData['fatsTarget'] = fatsTarget;

                  // 3. Hand the baton to the Assistant!
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
                  decoration: BoxDecoration(color: const Color(0xff375B86), borderRadius: BorderRadius.circular(22)),
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
                      
                      // THE FIX: Wrapped the loading text in an Expanded widget
                      _isLoadingTip 
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Keeps the spinner at the top if text wraps
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2.0),
                                child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
                              ),
                              const SizedBox(width: 12),
                              Expanded( // <--- This prevents the overflow!
                                child: Text(
                                  "Analyzing your latest data...", 
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
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Meals Today",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  _buildAddMealButton(),
                ],
              ),
              const SizedBox(height: 15),
              ...trackedMealsList.map((meal) => _buildMealListItem(meal)),
              SizedBox(height: 40 + bottomSafeArea),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Side-by-side rings ───────────────────────────────────────────────────

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
            color: const Color(0xff1A3F6B),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _showGoalSettingsSheet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Goal: ", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                    Text(goalTypeLabel(),
                      style: TextStyle(color: goalColor(), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Icon(Icons.edit, color: goalColor(), size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRing(
                    label: "Consumed",
                    currentValue: (caloriesConsumed * _animation.value).toInt(),
                    target: caloriesIntakeTarget.toInt(),
                    progress: consumedProgress,
                    ringColor: const Color(0xff00E5FF),
                    isLoading: false,
                  ),
                  Container(height: 120, width: 1, color: Colors.white12),
                  _buildRing(
                    label: "Burned",
                    currentValue: (caloriesBurned * _animation.value).toInt(),
                    target: caloriesBurnedTarget.toInt(),
                    progress: burnedProgress,
                    ringColor: const Color(0xff00E676),
                    isLoading: _isFitbitLoading,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRing({
    required String label,
    required int currentValue,
    required int target,
    required double progress,
    required Color ringColor,
    required bool isLoading,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(height: 120, width: 120,
              child: CircularProgressIndicator(
                value: 1.0, strokeWidth: 10,
                color: Colors.white.withValues(alpha: 0.08))),
            SizedBox(height: 120, width: 120,
              child: CircularProgressIndicator(
                value: progress, strokeWidth: 10,
                color: ringColor, backgroundColor: Colors.transparent,
                strokeCap: StrokeCap.round,
              )),
            isLoading
              ? SizedBox(height: 28, width: 28,
                  child: CircularProgressIndicator(color: ringColor, strokeWidth: 2.5))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("$currentValue",
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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

  // ─── Macros ───────────────────────────────────────────────────────────────

  Widget _buildCombinedMacrosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xff3183BE), borderRadius: BorderRadius.circular(25)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSingleMacroColumn("Protein", proteinConsumed, proteinTarget, Colors.redAccent),
          _buildSingleMacroColumn("Carbs",   carbsConsumed,   carbsTarget,   Colors.orangeAccent),
          _buildSingleMacroColumn("Fats",    fatsConsumed,    fatsTarget,    Colors.purpleAccent),
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
                SizedBox(height: 75, width: 75,
                  child: CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: Colors.white.withValues(alpha: 0.1))),
                SizedBox(height: 75, width: 75,
                  child: CircularProgressIndicator(
                    value: progress, strokeWidth: 8,
                    color: progressColor, backgroundColor: Colors.transparent, strokeCap: StrokeCap.round,
                  )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("${(consumed * _animation.value).toInt()}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  // ─── Meals ────────────────────────────────────────────────────────────────

  Widget _buildMealListItem(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start, // Keeps the calories aligned to the top if the name wraps
            children: [
              // --- THE FIX: Wrap the name in an Expanded widget ---
              Expanded(
                child: Text(
                  meal["name"],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2, // Let it wrap to a second line if it's long
                  overflow: TextOverflow.ellipsis, // Add "..." if it's ridiculously long
                ),
              ),
              const SizedBox(width: 12), // Add a little breathing room between the name and the numbers
              // ----------------------------------------------------
              
              Text("${meal["calories"]} kcal",
                style: const TextStyle(color: Color(0xff00E5FF), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use (as num).toInt() to prevent crashes from Python floats!
              _buildSmallMacroText("Protein", (meal["protein"] as num).toInt(), Colors.redAccent),
              _buildSmallMacroText("Carbs",   (meal["carbs"] as num).toInt(),   Colors.orangeAccent),
              _buildSmallMacroText("Fats",    (meal["fats"] as num).toInt(),    Colors.purpleAccent),
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
        final newMeal = await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TrackMealCameraPage()));

        if (newMeal != null && newMeal is Map<String, dynamic>) {
          
          // Show a quick loading message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Saving meal to cloud..."), duration: Duration(seconds: 1))
          );

          // 1. Send the meal to the Python Database safely
          bool success = await ApiService.saveMeal(
            name: newMeal["name"],
            calories: (newMeal["calories"] as num).toInt(),
            protein: (newMeal["protein"] as num).toDouble(),
            carbs: (newMeal["carbs"] as num).toDouble(),
            fats: (newMeal["fats"] as num).toDouble(),
          );

          if (success) {
            // 2. Re-fetch the live data to automatically update rings and totals!
            await _loadGoalSettings();

            // FORCE A FRESH GEMINI TIP! 
            _generateAITip(forceRefresh: true);

            // Replay the cool ring animations
            _controller.forward(from: 0.0);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Meal tracked successfully!"), backgroundColor: Color(0xff00E676))
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Failed to save meal. Please try again."), backgroundColor: Colors.redAccent)
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff00E676),
          borderRadius: BorderRadius.circular(12),
        ),
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
}