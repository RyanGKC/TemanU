import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/cameraCapture.dart';
import 'package:temanu/fitbitService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaloriesMain extends StatefulWidget {
  const CaloriesMain({super.key});

  @override
  State<CaloriesMain> createState() => _CaloriesMainState();
}

class _CaloriesMainState extends State<CaloriesMain> with SingleTickerProviderStateMixin {
  double caloriesConsumed = 1450;
  double caloriesTarget = 2200;

  double proteinConsumed = 85;
  final double proteinTarget = 140;

  double carbsConsumed = 150;
  final double carbsTarget = 250;

  double fatsConsumed = 45;
  final double fatsTarget = 70;

  // Fitbit calories burned
  double caloriesBurned = 0;
  double caloriesBurnedTarget = 2700; // Will be recalculated from goal settings
  bool _isFitbitLoading = true;

  // Goal settings
  // 'deficit' | 'maintain' | 'surplus'
  String _bodyGoal = 'maintain';
  // The user-adjustable kcal offset (always stored as a positive number;
  // sign is applied automatically: +ve for deficit, -ve for surplus, 0 for maintain)
  int _goalOffset = 500;

  late AnimationController _controller;
  late Animation<double> _animation;

  final List<Map<String, dynamic>> trackedMealsList = [
    {"name": "Oats and Honey",        "calories": 450, "protein": 15, "carbs": 65, "fats": 8},
    {"name": "Grilled Chicken Salad", "calories": 600, "protein": 45, "carbs": 20, "fats": 25},
    {"name": "Salmon and Quinoa",     "calories": 400, "protein": 35, "carbs": 40, "fats": 12},
  ];

  final String aiTips =
      "You've hit 60% of your protein goal but only 30% of your calories. Great lean eating! Consider a balanced dinner to hit your energy targets.";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
    _loadGoalSettings();
    _loadFitbitCalories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadGoalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      caloriesTarget = prefs.getDouble('calories_intake_target') ?? 2200;
      _bodyGoal      = prefs.getString('body_goal') ?? 'maintain';
      _goalOffset    = prefs.getInt('goal_offset') ?? 500;
      _recalculateBurnTarget();
    });
  }

  Future<void> _saveGoalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('calories_intake_target', caloriesTarget);
    await prefs.setString('body_goal', _bodyGoal);
    await prefs.setInt('goal_offset', _goalOffset);
  }

  /// Derives the burn target from the intake target + goal offset.
  /// Deficit → burn MORE  (+offset)
  /// Surplus → burn LESS  (-offset)
  /// Maintain → burn same (0)
  void _recalculateBurnTarget() {
    int signedOffset = 0;
    if (_bodyGoal == 'deficit') signedOffset = _goalOffset;
    if (_bodyGoal == 'surplus') signedOffset = -_goalOffset;
    caloriesBurnedTarget = (caloriesTarget + signedOffset).clamp(500, 9999).toDouble();
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
    // Local copies — only committed on "Save"
    double tempIntakeTarget = caloriesTarget;
    String tempGoal         = _bodyGoal;
    int    tempOffset       = _goalOffset; // always positive; sign applied per goal type
    final intakeController  = TextEditingController(text: caloriesTarget.toInt().toString());
    final offsetController  = TextEditingController(text: _goalOffset.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {

            // Derive burn target live from temp values
            int signedOffset = 0;
            if (tempGoal == 'deficit') signedOffset =  tempOffset;
            if (tempGoal == 'surplus') signedOffset = -tempOffset;
            final burnTarget  = (tempIntakeTarget + signedOffset).clamp(500, 9999).toInt();
            final netCalories = tempIntakeTarget.toInt() - burnTarget;

            Color goalColor() {
              if (tempGoal == 'deficit') return Colors.orangeAccent;
              if (tempGoal == 'surplus') return Colors.greenAccent;
              return const Color(0xff00E5FF);
            }

            String goalDescription() {
              if (tempGoal == 'deficit') {
                return "Burn $tempOffset kcal more than you consume to lose weight.";
              }
              if (tempGoal == 'surplus') {
                return "Burn $tempOffset kcal less than you consume to gain muscle.";
              }
              return "Match your burn to your intake to maintain your current weight.";
            }

            // Shared text field style
            InputDecoration fieldDecoration(String suffix) => InputDecoration(
              suffixText: suffix,
              suffixStyle: TextStyle(color: goalColor(), fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xff040F31).withValues(alpha: 0.5), // Matches app background
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: goalColor(), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            );

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xff1A3F6B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                      const SizedBox(height: 25),

                      const Text("Calorie Goal Settings",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("Set your intake target and body goal. Your burn target will be calculated automatically.",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),

                      const SizedBox(height: 30),

                      // ── Intake Target ──
                      const Text("Daily Calorie Intake Goal",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: intakeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: fieldDecoration("kcal"),
                        onChanged: (val) => setSheetState(() {
                          tempIntakeTarget = double.tryParse(val) ?? tempIntakeTarget;
                        }),
                      ),

                      const SizedBox(height: 30),

                      // ── Body Goal Chips ──
                      const Text("Body Goal",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _goalChip(setSheetState, "deficit",  "Deficit",  tempGoal,
                            (v) => tempGoal = v, Colors.orangeAccent),
                          const SizedBox(width: 12),
                          _goalChip(setSheetState, "maintain", "Maintain", tempGoal,
                            (v) => tempGoal = v, const Color(0xff00E5FF)),
                          const SizedBox(width: 12),
                          _goalChip(setSheetState, "surplus",  "Surplus",  tempGoal,
                            (v) => tempGoal = v, Colors.greenAccent),
                        ],
                      ),

                      // ── Offset adjuster (hidden for Maintain) ──
                      if (tempGoal != 'maintain') ...[
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tempGoal == 'deficit' ? "Calorie Deficit" : "Calorie Surplus",
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            // Quick-pick preset buttons
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? goalColor().withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive ? goalColor() : Colors.white24,
                                        width: isActive ? 2 : 1,
                                      ),
                                    ),
                                    child: Text("$preset",
                                      style: TextStyle(
                                        color: isActive ? goalColor() : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      )),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Slider + manual text input side by side
                        Row(
                          children: [
                            // Slider
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: goalColor(),
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: goalColor(),
                                  overlayColor: goalColor().withValues(alpha: 0.15),
                                  trackHeight: 6,
                                ),
                                child: Slider(
                                  value: tempOffset.toDouble().clamp(50, 1000),
                                  min: 50,
                                  max: 1000,
                                  divisions: 19, // steps of 50
                                  onChanged: (val) => setSheetState(() {
                                    tempOffset = val.toInt();
                                    offsetController.text = tempOffset.toString();
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Manual text input
                            SizedBox(
                              width: 95,
                              child: TextField(
                                controller: offsetController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                style: TextStyle(color: goalColor(), fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: fieldDecoration("kcal").copyWith(
                                  suffixText: null,
                                  hintText: "kcal",
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15), 
                                    borderSide: BorderSide.none
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: goalColor(), width: 2),
                                  ),
                                ),
                                onChanged: (val) => setSheetState(() {
                                  final parsed = int.tryParse(val);
                                  if (parsed != null) tempOffset = parsed.clamp(50, 1000);
                                }),
                              ),
                            ),
                          ],
                        ),
                        // Min/max labels under slider
                        const Padding(
                          padding: EdgeInsets.only(left: 14, right: 115),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("50", style: TextStyle(color: Colors.white38, fontSize: 12)),
                              Text("1000", style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // ── Live Preview ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xff040F31).withValues(alpha: 0.3), // Darker inset background
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: goalColor().withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goalDescription(),
                              style: TextStyle(color: goalColor(), fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _previewStat("Intake Goal", "${tempIntakeTarget.toInt()} kcal", const Color(0xff00E5FF)),
                                Container(width: 1, height: 40, color: Colors.white12),
                                _previewStat("Burn Goal", "$burnTarget kcal", goalColor()),
                                Container(width: 1, height: 40, color: Colors.white12),
                                _previewStat(
                                  "Net",
                                  "${netCalories > 0 ? '+' : ''}$netCalories kcal",
                                  netCalories <= 0 ? Colors.greenAccent : Colors.orangeAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ── Save Button ──
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            caloriesTarget = tempIntakeTarget;
                            _bodyGoal      = tempGoal;
                            _goalOffset    = tempOffset;
                            _recalculateBurnTarget();
                          });
                          _saveGoalSettings();
                          Navigator.pop(context);
                          _controller.forward(from: 0.0);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xff00E5FF), width: 2),
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                          ),
                          child: const Center(
                            child: Text("Save Goals",
                              style: TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold)),
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

  /// A selectable chip for the body goal row
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
            borderRadius: BorderRadius.circular(16),
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
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
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
          // Sync button
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
              // ── Side-by-side calorie rings ──
              _buildSideBySideCalorieRings(),
              const SizedBox(height: 15),

              // ── Macros ──
              _buildCombinedMacrosCard(),
              const SizedBox(height: 15),

              // ── AI Tips ──
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantPage())),
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
                      const SizedBox(height: 8),
                      Text(aiTips, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Meals ──
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
        final consumedProgress = (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0) * _animation.value;
        final burnedProgress   = (caloriesBurned / caloriesBurnedTarget).clamp(0.0, 1.0) * _animation.value;

        // Goal badge colour
        Color goalBadgeColor() {
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
              // Tappable goal label
              GestureDetector(
                onTap: _showGoalSettingsSheet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Goal: ",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                    ),
                    Text(
                      goalTypeLabel(),
                      style: TextStyle(
                        color: goalBadgeColor(),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.edit, color: goalBadgeColor(), size: 14),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // The two rings side by side
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Consumed
                  _buildRing(
                    label: "Consumed",
                    currentValue: (caloriesConsumed * _animation.value).toInt(),
                    target: caloriesTarget.toInt(),
                    progress: consumedProgress,
                    ringColor: const Color(0xff00E5FF),
                    isLoading: false,
                  ),

                  // Divider
                  Container(height: 120, width: 1, color: Colors.white12),

                  // Burned
                  _buildRing(
                    label: "Burned",
                    currentValue: (caloriesBurned * _animation.value).toInt(),
                    target: caloriesBurnedTarget.toInt(),
                    progress: burnedProgress,
                    ringColor: const Color(0xff00E676),
                    isLoading: _isFitbitLoading,
                    badge: "Fitbit",
                    badgeColor: const Color(0xff00E676),
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
    String? badge,
    Color? badgeColor,
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

        Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text("Goal: $target kcal",
          style: const TextStyle(color: Colors.white54, fontSize: 12))
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
            children: [
              Text(meal["name"],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${meal["calories"]} kcal",
                style: const TextStyle(color: Color(0xff00E5FF), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallMacroText("Protein", meal["protein"], Colors.redAccent),
              _buildSmallMacroText("Carbs",   meal["carbs"],   Colors.orangeAccent),
              _buildSmallMacroText("Fats",    meal["fats"],    Colors.purpleAccent),
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
          setState(() {
            trackedMealsList.add(newMeal);
            caloriesConsumed += (newMeal["calories"] as num).toDouble();
            proteinConsumed  += (newMeal["protein"]  as num).toDouble();
            carbsConsumed    += (newMeal["carbs"]    as num).toDouble();
            fatsConsumed     += (newMeal["fats"]     as num).toDouble();
          });
          _controller.forward(from: 0.0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Meal tracked successfully!"), backgroundColor: Color(0xff00E676)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff00E676), // Vibrant green matching your burn ring
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Color(0xff040F31), size: 18), // Dark contrast icon
            SizedBox(width: 4),
            Text("Track",
              style: TextStyle(color: Color(0xff040F31), fontSize: 14, fontWeight: FontWeight.bold)), // Dark contrast text
          ],
        ),
      ),
    );
  }
}