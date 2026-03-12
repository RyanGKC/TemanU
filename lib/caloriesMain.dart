import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/cameraCapture.dart';

class CaloriesMain extends StatefulWidget {
  const CaloriesMain({super.key});

  @override
  State<CaloriesMain> createState() => _CaloriesMainState();
}

class _CaloriesMainState extends State<CaloriesMain> with SingleTickerProviderStateMixin {
  // Dummy data, to be replaced with real variables
  double caloriesConsumed = 1450;
  final double caloriesTarget = 2200;
  
  double proteinConsumed = 85;
  final double proteinTarget = 140;
  
  double carbsConsumed = 150;
  final double carbsTarget = 250;
  
  double fatsConsumed = 45;
  final double fatsTarget = 70;
  
  // Declare animation variables
  late AnimationController _controller;
  late Animation<double> _animation;

  // Dummy data for the meal list
  final List<Map<String, dynamic>> trackedMealsList = [
    {
      "name": "Oats and Honey", 
      "calories": 450, 
      "protein": 15, 
      "carbs": 65, 
      "fats": 8
    },
    {
      "name": "Grilled Chicken Salad", 
      "calories": 600, 
      "protein": 45, 
      "carbs": 20, 
      "fats": 25
    },
    {
      "name": "Salmon and Quinoa", 
      "calories": 400, 
      "protein": 35, 
      "carbs": 40, 
      "fats": 12
    },
  ];

  final String aiTips = "You've hit 60% of your protein goal but only 30% of your calories. Great lean eating! Consider a balanced dinner to hit your energy targets.";

  @override
  void initState() {
    super.initState();
    // Initialize the animation controller with a duration of 1.5 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Apply a smooth curve to the animation
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    // Always dispose of controllers to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }

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
        title: const Text(
          "Calories",
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
            onPressed: () {}, // to add sharing page
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
              // 1. TOP: FULL-WIDTH CALORIE TRACKER
              _buildMainCalorieCard(),
              const SizedBox(height: 15),

              // 2. MIDDLE: COMBINED MACROS CARD
              _buildCombinedMacrosCard(),

              const SizedBox(height: 15),

              //AI Tips
              InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantPage()));
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
                    const SizedBox(height: 8),
                    Text(aiTips, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                  ],
                ),
              ),
            ),

              const SizedBox(height: 40), 

              // 3. BOTTOM: MEALS SECTION
              const Text(
                "Meals Today",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              
              // Map through the dummy data to generate meal cards
              ...trackedMealsList.map((meal) => _buildMealListItem(meal)),
              
              const SizedBox(height: 15),
              _buildAddMealButton(),
              
              SizedBox(height: 40 + bottomSafeArea), // Reduced bottom padding since the nav bar is gone
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCalorieCard() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double targetProgress = (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0);
        double currentProgress = targetProgress * _animation.value;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff3183BE),
            borderRadius: BorderRadius.circular(25), 
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. CIRCULAR SCALE ON TOP
              SizedBox(height: 15),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 140, 
                    width: 140,  
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12, 
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox(
                    height: 140, 
                    width: 140,  
                    child: CircularProgressIndicator(
                      value: currentProgress, 
                      strokeWidth: 12, 
                      color: const Color(0xff00E5FF),
                      backgroundColor: Colors.transparent,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(caloriesConsumed * _animation.value).toInt()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "kcal",
                        style: TextStyle(color: Colors.white70, fontSize: 18), 
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20), // Spacing between circle and text
              
              // 2. TEXT LABELS BELOW
              const Text(
                "Calories",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4), // Tight spacing between title and target
              Text(
                "Target: ${caloriesTarget.toInt()}",
                style: const TextStyle(
                  color: Colors.white70, 
                  fontSize: 16 
                ),
              ),
              SizedBox(height: 15)
            ],
          ),
        );
      }
    );
  }

  // WIDGET: Combined Macros Card (Middle section)
  Widget _buildCombinedMacrosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xff3183BE),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Spaces them perfectly
        children: [
          _buildSingleMacroColumn("Protein", proteinConsumed, proteinTarget, Colors.redAccent),
          _buildSingleMacroColumn("Carbs", carbsConsumed, carbsTarget, Colors.orangeAccent),
          _buildSingleMacroColumn("Fats", fatsConsumed, fatsTarget, Colors.purpleAccent),
        ],
      ),
    );
  }

  // WIDGET: Individual Macro Column inside the combined card
  Widget _buildSingleMacroColumn(String title, double consumed, double target, Color progressColor) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double targetProgress = (consumed / target).clamp(0.0, 1.0);
        double currentProgress = targetProgress * _animation.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 75, // Scaled down to fit 3 in a row
                  width: 75,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                SizedBox(
                  height: 75,
                  width: 75,
                  child: CircularProgressIndicator(
                    value: currentProgress, 
                    strokeWidth: 8,
                    color: progressColor,
                    backgroundColor: Colors.transparent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${(consumed * _animation.value).toInt()}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Scaled down slightly
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "g",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Target: ${target.toInt()}g", 
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        );
      }
    );
  }

  // WIDGET: Individual Meal Item
  Widget _buildMealListItem(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B), // Slightly darker blue for contrast
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                meal["name"],
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              Text(
                "${meal["calories"]} kcal",
                style: const TextStyle(
                  color: Color(0xff00E5FF), // Cyan highlight for calories
                  fontSize: 16, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallMacroText("Protein", meal["protein"], Colors.redAccent),
              _buildSmallMacroText("Carbs", meal["carbs"], Colors.orangeAccent),
              _buildSmallMacroText("Fats", meal["fats"], Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET: Small Macro Text for the Meal Item
  Widget _buildSmallMacroText(String title, int amount, Color dotColor) {
    return Row(
      children: [
        Icon(Icons.circle, color: dotColor, size: 10), // Tiny colored dot matching the charts
        const SizedBox(width: 6),
        Text(
          "$title: ",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          "${amount}g",
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // WIDGET: Add New Meal Button
  Widget _buildAddMealButton() {
    return GestureDetector(
      onTap: () async {
        // 1. Wait for the camera/info pages to finish
        final newMeal = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TrackMealCameraPage())
        );

        // 2. If we got data back, update the UI!
        if (newMeal != null && newMeal is Map<String, dynamic>) {
          setState(() {
            // Add to your list of meals
            trackedMealsList.add(newMeal);

            // Add the new macros to your daily totals
            caloriesConsumed += (newMeal["calories"] as num).toDouble();
            proteinConsumed += (newMeal["protein"] as num).toDouble();
            carbsConsumed += (newMeal["carbs"] as num).toDouble();
            fatsConsumed += (newMeal["fats"] as num).toDouble();
          });

          // 3. Restart the circular animations from zero to show the new progress!
          _controller.forward(from: 0.0);
          
          // Optional: Show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Meal tracked successfully!"),
              backgroundColor: Color(0xff00E5FF),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xff00E5FF), width: 2), // Cyan border
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Color(0xff00E5FF)),
            SizedBox(width: 8),
            Text(
              "Track New Meal",
              style: TextStyle(
                color: Color(0xff00E5FF), 
                fontSize: 16, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}