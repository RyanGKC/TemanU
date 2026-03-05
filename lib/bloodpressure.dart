import 'package:flutter/material.dart';

class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  final systolicCtrl = TextEditingController();
  final diastolicCtrl = TextEditingController();
  final pulseCtrl = TextEditingController();

  String currentText = "118 / 76 mmHg";
  String statusText = "Status: Normal";

  void saveData() {
    final sStr = systolicCtrl.text.trim();
    final dStr = diastolicCtrl.text.trim();
    final pStr = pulseCtrl.text.trim();

    final s = int.tryParse(sStr);
    final d = int.tryParse(dStr);

    if (s == null || d == null) {
      setState(() {
        statusText = "Status: Please enter valid numbers";
      });
      return;
    }

    String status;
    // 简单判断规则（作业够用）
    if (s >= 140 || d >= 90) {
      status = "High";
    } else if (s < 90 || d < 60) {
      status = "Low";
    } else {
      status = "Normal";
    }

    setState(() {
      currentText = "$s / $d mmHg";
      if (pStr.isNotEmpty) {
        currentText += "  |  Pulse: $pStr";
      }
      statusText = "Status: $status";
    });
  }

  void clearData() {
    systolicCtrl.clear();
    diastolicCtrl.clear();
    pulseCtrl.clear();

    setState(() {
      currentText = "— / — mmHg";
      statusText = "Status: —";
    });
  }

  @override
  void dispose() {
    systolicCtrl.dispose();
    diastolicCtrl.dispose();
    pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff06163A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Blood Pressure",
          style: TextStyle(
            color: Color(0xff6CE5FF),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [Icon(Icons.share)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current BP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current", style: TextStyle(color: Colors.white70)),
                    Text(
                      currentText,
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 5),
                    Text("Add data", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff375B86),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  bpField("Systolic (mmHg)", systolicCtrl),
                  const SizedBox(height: 12),
                  bpField("Diastolic (mmHg)", diastolicCtrl),
                  const SizedBox(height: 12),
                  bpField("Pulse (optional)", pulseCtrl),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: saveData,
                          child: const Text("Save / Calculate"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: clearData,
                          child: const Text("Clear"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Chart placeholder
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xff4F7CA8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  "Blood Pressure Chart (later)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Time filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text("Week", style: TextStyle(color: Colors.white)),
                Text("Month", style: TextStyle(color: Colors.white70)),
                Text("3 Months", style: TextStyle(color: Colors.white70)),
                Text("6 Months", style: TextStyle(color: Colors.white70)),
                Text("Year", style: TextStyle(color: Colors.white70)),
              ],
            ),

            const SizedBox(height: 40),

            // Assistant
            Column(
              children: const [
                Icon(Icons.search, size: 50, color: Colors.white70),
                Text("Assistant", style: TextStyle(color: Colors.white70)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

Widget bpField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xff2B4B74),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}