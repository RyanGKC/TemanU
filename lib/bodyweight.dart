import 'dart:math';
import 'package:flutter/material.dart';


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

  List<double> weekData = [82.5, 82.0, 81.8, 81.5, 81.8, 81.0, 80.5];
  List<double> monthData = [84.0, 83.5, 83.0, 82.5, 82.0, 81.5, 81.0, 80.5];
  List<double> threeMonthData = [88.0, 86.5, 85.0, 83.5, 82.0, 81.0, 80.5];
  List<double> sixMonthData = [92.0, 89.0, 87.0, 85.0, 83.0, 81.5, 80.5];
  List<double> yearData = [98.0, 95.0, 92.0, 89.0, 86.0, 84.0, 82.0, 80.5];

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
    double h = heightCm / 100;
    return currentWeight / (h * h);
  }

  double get changeWeight {
    if (weekData.length < 2) return 0;
    return weekData.last - weekData.first;
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
    });
  }

  void showAddDataDialog() {
    TextEditingController weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Weight Data"),
          content: TextField(
            controller: weightController,
            keyboardType: TextInputType.number,
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
                double? newWeight = double.tryParse(weightController.text);
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
        builder: (context) => ShareHighlightPage(
          changeValue: changeWeight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff031447),
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
        leading: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)),
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

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Week",
                style: TextStyle(
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff59A2DD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: CustomPaint(
                painter: WeightChartPainter(currentData),
                child: Container(),
              ),
            ),

            const SizedBox(height: 16),

            // Goal / Change / BMI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoCard("Goal", goalWeight.toStringAsFixed(0)),
                infoCard("Change", "${changeWeight.toStringAsFixed(1)}kg"),
                infoCard("BMI", bmi.toStringAsFixed(1)),
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

            // Assistant
            Container(
              width: 160,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xff4C536F),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.search, size: 38, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    "Assistant",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoCard(String title, String value) {
    return Container(
      width: 105,
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
    bool selected = selectedRange == label;
    return InkWell(
      onTap: () {
        setState(() {
          selectedRange = label;
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

class WeightChartPainter extends CustomPainter {
  final List<double> data;
  WeightChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xff7EF2FF)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;

    double minVal = data.reduce(min) - 3;
    double maxVal = data.reduce(max) + 1;
    double range = maxVal - minVal;

    // Horizontal lines
    for (int i = 0; i < 6; i++) {
      double y = size.height * i / 5;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), gridPaint);
    }

    // Path
    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      double x = 40 + (size.width - 60) * i / (data.length - 1);
      double y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
    canvas.drawPath(path, linePaint);

    // Bottom labels
    List<String> labels = ["Mon", "Tues", "Wed", "Thurs", "Fri", "Sat", "Sun"];
    for (int i = 0; i < min(labels.length, data.length); i++) {
      double x = 30 + (size.width - 60) * i / (data.length - 1);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 12, size.height - 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ShareHighlightPage extends StatelessWidget {
  final double changeValue;
  const ShareHighlightPage({super.key, required this.changeValue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff041B57),
      body: Center(
        child: Container(
          width: 320,
          height: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Column(
            children: [
              const Text(
                "Share Highlights",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 240,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xff4DA5E0),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(
                    "Change\n${changeValue.toStringAsFixed(1)}kg",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("< Back"),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Save to Device"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}