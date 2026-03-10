import 'package:flutter/material.dart';

class ShareWeightHighlightPage extends StatelessWidget {
  final double changeValue;

  const ShareWeightHighlightPage({
    super.key,
    required this.changeValue,
  });

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