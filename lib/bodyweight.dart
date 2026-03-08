import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/shareWeightHighlightPage.dart';
import 'package:temanu/weightLineChartPainter.dart';


class BodyWeightPage extends StatefulWidget {
  const BodyWeightPage({super.key});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> {
  double currentWeight = 80.5;
  double goalWeight = 80.0;
  double heightCm = 186.0;
  String selectedRange = "Week";

  int? touchedIndex; // Tracks which data point is currently selected

  void _handleChartTap(TapUpDetails details, double width) {
    final double leftPadding = 58;
    final double rightPadding = 20;
    final double usableWidth = width - leftPadding - rightPadding;
    final double dx = details.localPosition.dx;

    // If tapped outside the chart area, deselect
    if (dx < leftPadding - 10 || dx > width - rightPadding + 10) {
      setState(() => touchedIndex = null);
      return;
    }

    final int dataLength = currentData.length;
    if (dataLength < 2) return;

    int index;
    if (isLineChart) {
      final double step = usableWidth / (dataLength - 1);
      index = ((dx - leftPadding) / step).round();
    } else {
      final double step = usableWidth / dataLength;
      index = ((dx - leftPadding) / step).floor();
    }

    // Update the state with the tapped index
    if (index >= 0 && index < dataLength) {
      setState(() => touchedIndex = index);
    } else {
      setState(() => touchedIndex = null);
    }
  }

  // Week: 7 daily values
  List<double> weekData = [82.5, 82.0, 81.8, 81.5, 81.8, 81.0, 80.5];

  // Month: 30 daily values
  List<double> monthData = [
    84.0, 83.8, 83.7, 83.6, 83.4, 83.2, 83.0, 82.9, 82.8, 82.7,
    82.5, 82.4, 82.3, 82.2, 82.1, 82.0, 81.9, 81.8, 81.7, 81.6,
    81.5, 81.4, 81.3, 81.2, 81.1, 81.0, 80.9, 80.8, 80.7, 80.5,
  ];

  // 3 Months: 12 weekly averages
  List<double> threeMonthData = [
    86.8, 86.2, 85.9, 85.4, 85.0, 84.6,
    84.0, 83.4, 82.9, 82.3, 81.5, 80.8,
  ];

  // 6 Months: 6 monthly averages
  List<double> sixMonthData = [89.0, 87.6, 86.1, 84.8, 82.9, 80.8];

  // Year: 12 monthly values
  List<double> yearData = [
    96.0, 94.8, 93.5, 92.2, 90.8, 89.4,
    88.0, 86.7, 85.2, 83.9, 82.3, 80.8,
  ];

  List<double> get currentData {
    switch (selectedRange) {
      case "Month":
        return monthData;
      case "3 Months":
        return threeMonthData;
      case "6 Months":
        return sixMonthData;
      case "Year":
        return yearData;
      default:
        return weekData;
    }
  }

  double get bmi {
    final h = heightCm / 100;
    return currentWeight / (h * h);
  }

  double get changeWeight {
    final data = currentData;
    if (data.length < 2) return 0;
    return data.last - data.first;
  }

  String get bmiStatus {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  String get aiTips {
    if (changeWeight < 0) {
      return "You've done well, losing ${changeWeight.abs().toStringAsFixed(1)} kg and getting close to your goal. "
          "Now is the time to focus on steady, lasting progress. Keep your meals balanced, stay hydrated, and prioritize good rest.";
    } else if (changeWeight > 0) {
      return "Your weight has increased slightly. Try improving your diet, increase activity, and stay consistent with healthy habits.";
    } else {
      return "Your weight is stable. Keep maintaining your current healthy routine.";
    }
  }

  void addWeightData(double value) {
    setState(() {
      currentWeight = value;

      weekData.add(value);
      if (weekData.length > 7) {
        weekData.removeAt(0);
      }

      monthData.add(value);
      if (monthData.length > 30) {
        monthData.removeAt(0);
      }

      threeMonthData.add(value);
      if (threeMonthData.length > 12) {
        threeMonthData.removeAt(0);
      }

      sixMonthData.add(value);
      if (sixMonthData.length > 6) {
        sixMonthData.removeAt(0);
      }

      yearData.add(value);
      if (yearData.length > 12) {
        yearData.removeAt(0);
      }
    });
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

  bool get isLineChart {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff031447),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xff55607D),
        elevation: 0,
        title: const Text(
          "Body Weight",
          style: TextStyle(
            color: Color(0xff35E0FF),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current + Add data
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

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedRange,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Chart
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff59A2DD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapUp: (details) => _handleChartTap(details, constraints.maxWidth),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: WeightLineChartPainter(currentData, selectedRange, touchedIndex)
                      // painter: isLineChart
                      //     ? WeightLineChartPainter(currentData, selectedRange, touchedIndex)
                      //     : WeightBarChartPainter(currentData, selectedRange, touchedIndex),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Goal / Change / BMI
            Row(
              children: [
                Expanded(
                  child: infoCard("Goal", goalWeight.toStringAsFixed(0)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg"),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: infoCard("BMI", bmi.toStringAsFixed(1)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Tips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff375B86),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "💡 AI Tips",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aiTips,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Time filter
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  filterButton("Week"),
                  filterButton("Month"),
                  filterButton("3 Months"),
                  filterButton("6 Months"),
                  filterButton("Year"),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left:20, right: 20, bottom: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1), 
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => AssistantPage())
                          );
                        },
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome,
                            size: 28,
                            color: Colors.white70
                          ),
                        )
                      )
                    )
                  )
                )
              ),
            ]
          )
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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
          touchedIndex = null; // <-- Clear selection on tab change
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff6CE5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}