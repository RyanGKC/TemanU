import 'package:flutter/material.dart';
import 'package:temanu/bloodPressureSharePage.dart';
import 'package:temanu/bloodPresureChartPainter.dart';


class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  int systolic = 118;
  int diastolic = 76;
  String selectedRange = "Week";

  // Week data
  List<int> weekSys = [122, 120, 119, 118, 117, 119, 118];
  List<int> weekDia = [80, 79, 78, 77, 76, 77, 76];
  List<int> weekSysMin = [120, 118, 118, 117, 116, 118, 117];
  List<int> weekSysMax = [124, 121, 120, 119, 118, 120, 119];
  List<int> weekDiaMin = [78, 78, 77, 76, 75, 76, 75];
  List<int> weekDiaMax = [82, 80, 79, 78, 77, 78, 77];

  // Month data (30 days)
  List<int> monthSys = [
    126, 125, 124, 124, 123, 122, 121, 121, 120, 120,
    119, 119, 118, 118, 118, 119, 120, 121, 122, 121,
    120, 119, 118, 117, 118, 119, 118, 117, 118, 118
  ];
  List<int> monthDia = [
    84, 83, 82, 82, 81, 80, 80, 79, 79, 78,
    78, 77, 77, 76, 76, 77, 78, 79, 80, 79,
    78, 77, 76, 75, 76, 77, 76, 75, 76, 76
  ];

  // 3 Months (12 weekly values)
  List<int> threeMonthSys = [130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 118];
  List<int> threeMonthDia = [86, 85, 84, 84, 83, 82, 81, 80, 79, 78, 77, 76];

  // 6 Months (6 monthly averages)
  List<int> sixMonthSys = [135, 133, 130, 127, 124, 118];
  List<int> sixMonthDia = [90, 88, 86, 84, 82, 76];

  // Year (12 monthly values)
  List<int> yearSys = [140, 138, 136, 134, 132, 130, 128, 126, 124, 122, 120, 118];
  List<int> yearDia = [92, 90, 89, 88, 86, 85, 84, 82, 81, 79, 78, 76];

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

  List<int>? get currentSysMin {
    if (selectedRange == "Week") return weekSysMin;
    return null;
  }

  List<int>? get currentSysMax {
    if (selectedRange == "Week") return weekSysMax;
    return null;
  }

  List<int>? get currentDiaMin {
    if (selectedRange == "Week") return weekDiaMin;
    return null;
  }

  List<int>? get currentDiaMax {
    if (selectedRange == "Week") return weekDiaMax;
    return null;
  }

  String get zoneText {
    if (systolic > 180 || diastolic > 120) {
      return "Crisis";
    } else if (systolic >= 140 || diastolic >= 90) {
      return "High";
    } else if (systolic >= 130 || diastolic >= 80) {
      return "Stage 1";
    } else if (systolic >= 120 && diastolic < 80) {
      return "Elevated";
    } else {
      return "Healthy";
    }
  }

  Color get zoneColor {
    switch (zoneText) {
      case "Healthy":
        return const Color(0xff4DA5E0);
      case "Elevated":
        return Colors.orange;
      case "Stage 1":
        return Colors.deepOrange;
      case "High":
        return Colors.red;
      case "Crisis":
        return Colors.purple;
      default:
        return const Color(0xff4DA5E0);
    }
  }

  String get aiTips {
    switch (zoneText) {
      case "Healthy":
        return "Your blood pressure is in a healthy range. Keep maintaining your healthy lifestyle.";
      case "Elevated":
        return "Your blood pressure is slightly elevated. Reduce salt intake and monitor regularly.";
      case "Stage 1":
        return "Your blood pressure is in Stage 1 hypertension range. Consider lifestyle changes and regular monitoring.";
      case "High":
        return "Your blood pressure is high. Please reduce stress, improve diet, and consult a healthcare professional if needed.";
      case "Crisis":
        return "Your reading is in hypertensive crisis range. Seek medical attention immediately.";
      default:
        return "Monitor your blood pressure regularly.";
    }
  }

  void addBpData(int sys, int dia) {
    setState(() {
      systolic = sys;
      diastolic = dia;

      weekSys.add(sys);
      weekDia.add(dia);
      weekSysMin.add(sys - 2);
      weekSysMax.add(sys + 2);
      weekDiaMin.add(dia - 2);
      weekDiaMax.add(dia + 2);

      if (weekSys.length > 7) weekSys.removeAt(0);
      if (weekDia.length > 7) weekDia.removeAt(0);
      if (weekSysMin.length > 7) weekSysMin.removeAt(0);
      if (weekSysMax.length > 7) weekSysMax.removeAt(0);
      if (weekDiaMin.length > 7) weekDiaMin.removeAt(0);
      if (weekDiaMax.length > 7) weekDiaMax.removeAt(0);
    });
  }

  void showAddDataDialog() {
    final sysController = TextEditingController();
    final diaController = TextEditingController();

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
                  labelText: "Systolic (mmHg)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Diastolic (mmHg)",
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

                if (sys != null && dia != null) {
                  addBpData(sys, dia);
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
          zone: zoneText,
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
                      zoneText,
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

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "$selectedRange Overview",
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff59A2DD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: CustomPaint(
                painter: BloodPressureChartPainter(
                  sysData: currentSysData,
                  diaData: currentDiaData,
                  rangeLabel: selectedRange,
                  sysMinData: currentSysMin,
                  sysMaxData: currentSysMax,
                  diaMinData: currentDiaMin,
                  diaMaxData: currentDiaMax,
                ),
                child: Container(),
              ),
            ),

            const SizedBox(height: 14),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Systolic",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Diastolic",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                infoCard("Systolic", "$systolic mmHg"),
                infoCard("Diastolic", "$diastolic mmHg"),
                zoneCard("Zone", zoneText),
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
      width: 100,
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
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget zoneCard(String title, String value) {
    return Container(
      width: 100,
      height: 95,
      decoration: BoxDecoration(
        color: zoneColor,
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
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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