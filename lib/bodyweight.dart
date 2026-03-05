import 'package:flutter/material.dart';

class BodyWeightPage extends StatefulWidget {
  const BodyWeightPage({super.key});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  String _result = '';

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calc() {
    final weight = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());

    if (weight == null || heightCm == null || heightCm <= 0) {
      setState(() => _result = 'Please enter valid weight and height.');
      return;
    }

    final heightM = heightCm / 100.0;
    final bmi = weight / (heightM * heightM);

    String category;
    if (bmi < 18.5) {
      category = 'Underweight';
    } else if (bmi < 25) {
      category = 'Normal';
    } else if (bmi < 30) {
      category = 'Overweight';
    } else {
      category = 'Obese';
    }

    setState(() {
      _result =
          'Weight: ${weight.toStringAsFixed(1)} kg\nHeight: ${heightCm.toStringAsFixed(1)} cm\nBMI: ${bmi.toStringAsFixed(1)} ($category)';
    });
  }

  void _clear() {
    _weightController.clear();
    _heightController.clear();
    setState(() => _result = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body Weight')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'e.g., 60',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                hintText: 'e.g., 170',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _calc,
                    child: const Text('Calculate BMI'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_result.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_result),
              ),
          ],
        ),
      ),
    );
  }
}