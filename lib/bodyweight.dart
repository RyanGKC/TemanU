import 'package:flutter/material.dart';

class BodyWeightPage extends StatefulWidget {
  const BodyWeightPage({super.key});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> {

  final weightController = TextEditingController();
  final heightController = TextEditingController();

  double bmi = 0;
  String bmiStatus = "";

  void calculateBMI() {
    double weight = double.parse(weightController.text);
    double height = double.parse(heightController.text) / 100;

    double result = weight / (height * height);

    String status;

    if (result < 18.5) {
      status = "Underweight";
    } else if (result < 25) {
      status = "Normal";
    } else if (result < 30) {
      status = "Overweight";
    } else {
      status = "Obese";
    }

    setState(() {
      bmi = result;
      bmiStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff06163A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Body Weight",
          style: TextStyle(
            color: Color(0xff6CE5FF),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff375B86),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [

                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Weight (kg)",
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Height (cm)",
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: calculateBMI,
                    child: const Text("Calculate BMI"),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 20),

            // BMI Result
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff4F7CA8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [

                  const Text(
                    "BMI Result",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    bmi == 0 ? "-" : bmi.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    bmiStatus,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 40),

            // Assistant
            Column(
              children: const [
                Icon(Icons.search, size: 50, color: Colors.white70),
                Text("Assistant", style: TextStyle(color: Colors.white70))
              ],
            )

          ],
        ),
      ),
    );
  }
}