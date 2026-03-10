import 'package:flutter/material.dart';

class BloodPressureSharePage extends StatelessWidget {
  final int sys;
  final int dia;
  final String zone;

  const BloodPressureSharePage({
    super.key,
    required this.sys,
    required this.dia,
    required this.zone,
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
                    "Blood Pressure\n$sys / $dia\n\nZone: $zone",
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