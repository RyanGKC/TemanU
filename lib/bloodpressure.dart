import 'dart:math';
import 'package:flutter/material.dart';


class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  int systolic = 118;
  int diastolic = 76;
  int pulse = 70;
  String selectedRange = "Week";

  List<int> weekSys = [122, 120, 119, 118, 117, 119, 118];
  List<int> weekDia = [80, 79, 78, 77, 76, 77, 76];

  List<int> monthSys = [126, 124, 123, 121, 120, 119, 118];
  List<int> monthDia = [84, 82, 81, 80, 79, 78, 76];

  List<int> threeMonthSys = [130, 128, 126, 124, 122, 120, 118];
  List<int> threeMonthDia = [86, 84, 83, 81, 80, 79, 76];

  List<int> sixMonthSys = [135, 133, 130, 127, 124, 121, 118];
  List<int> sixMonthDia = [90, 88, 86, 84, 82, 80, 76];

  List<int> yearSys = [140, 138, 136, 132, 128, 124, 118];
  List<int> yearDia = [92, 90, 88, 86, 84, 80, 76];

  List<int> get currentSysData {
    switch (selectedRange) {
      case "Month":
        return monthSys;
      case "3 Months":
        return threeMonthSys;
      case "6 Months":
        return sixMonthSys;
      case "Year":
        return yearSys;
      default:
        return weekSys;
    }
  }

  List<int> get currentDiaData {
    switch (selectedRange) {
      case "Month":
        return monthDia;
      case "3 Months":
        return threeMonthDia;
      case "6 Months":
        return sixMonthDia;
      case "Year":
        return yearDia;
      default:
        return weekDia;
    }
  }

  String get bpStatus {
    if (systolic >= 140 || diastolic >= 90) return "High";
    if (systolic < 90 || diastolic < 60) return "Low";
    return "Normal";
  }

  int get changeSys {
    final data = currentSysData;
    if (data.length < 2) return 0;
    return data.last - data.first;
  }

  int get changeDia {
    final data = currentDiaData;
    if (data.length < 2) return 0;
    return data.last - data.first;
  }

  String get changeText {
    final sysSign = changeSys > 0 ? "+" : "";
    final diaSign = changeDia > 0 ? "+" : "";
    return "$sysSign$changeSys / $diaSign$changeDia";
  }

  String get aiTips {
    if (bpStatus == "High") {
      return "Your blood pressure is high. Reduce salt intake, manage stress, exercise regularly, and monitor your readings consistently.";
    } else if (bpStatus == "Low") {
      return "Your blood pressure is low. Stay hydrated, eat balanced meals, and seek medical advice if dizziness continues.";
    } else {
      return "Your blood pressure is in the normal range. Maintain your healthy lifestyle, exercise regularly, and continue monitoring.";
    }
  }

  void addBpData(int sys, int dia, int pulseValue) {
    setState(() {
      systolic = sys;
      diastolic = dia;
      pulse = pulseValue;

      weekSys.add(sys);
      weekDia.add(dia);

      if (weekSys.length > 7) weekSys.removeAt(0);
      if (weekDia.length > 7) weekDia.removeAt(0);
    });
  }

  void showAddDataDialog() {
    final sysController = TextEditingController();
    final diaController = TextEditingController();
    final pulseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Blood Pressure Data"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Systolic",
                ),
              ),
              TextField(
                controller: diaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Diastolic",
                ),
              ),
              TextField(
                controller: pulseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Pulse",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final sys = int.tryParse(sysController.text);
                final dia = int.tryParse(diaController.text);
                final p = int.tryParse(pulseController.text);

                if (sys != null && dia != null && p != null) {
                  addBpData(sys, dia, p);
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
        builder: (context) => BloodPressureSharePage(
          sys: systolic,
          dia: diastolic,
          change: changeText,
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
          "Blood Pressure",
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
                    Text(
                      "$systolic / $diastolic",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$pulse bpm  |  $bpStatus",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
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

            Text(
              selectedRange,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
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
                painter: BloodPressureChartPainter(currentSysData),
                child: Container(),
              ),
            ),

            const SizedBox(height: 16),

            // Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoCard("Systolic", systolic.toString()),
                infoCard("Diastolic", diastolic.toString()),
                infoCard("Pulse", pulse.toString()),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                changeCard("Change", changeText),
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
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18),
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

  Widget changeCard(String title, String value) {
    return Container(
      width: 180,
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
            style: const TextStyle(color: Colors.white, fontSize: 18),
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

class BloodPressureChartPainter extends CustomPainter {
  final List<int> data;
  BloodPressureChartPainter(this.data);

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

    final minVal = data.reduce(min) - 10;
    final maxVal = data.reduce(max) + 5;
    final range = maxVal - minVal;

    for (int i = 0; i < 6; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = 40 + (size.width - 60) * i / (data.length - 1);
      final y = size.height - ((data[i] - minVal) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
    canvas.drawPath(path, linePaint);

    const labels = ["Mon", "Tues", "Wed", "Thurs", "Fri", "Sat", "Sun"];
    for (int i = 0; i < min(labels.length, data.length); i++) {
      final x = 30 + (size.width - 60) * i / (data.length - 1);
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

class BloodPressureSharePage extends StatelessWidget {
  final int sys;
  final int dia;
  final String change;

  const BloodPressureSharePage({
    super.key,
    required this.sys,
    required this.dia,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff041B57),
      body: Center(
        child: Container(
          width: 320,
          height: 400,
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
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xff4DA5E0),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(
                    "Blood Pressure\n$sys / $dia\n\nChange: $change",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
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