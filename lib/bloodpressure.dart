import 'package:flutter/material.dart';

class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _pulseController = TextEditingController();

  String _result = '';

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _save() {
    final sys = int.tryParse(_sysController.text.trim());
    final dia = int.tryParse(_diaController.text.trim());
    final pulse = int.tryParse(_pulseController.text.trim());

    if (sys == null || dia == null) {
      setState(() => _result = 'Please enter valid SYS and DIA values.');
      return;
    }

    String category;
    if (sys >= 180 || dia >= 120) {
      category = 'Hypertensive Crisis (Seek medical help)';
    } else if (sys >= 140 || dia >= 90) {
      category = 'High Blood Pressure (Stage 2)';
    } else if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) {
      category = 'High Blood Pressure (Stage 1)';
    } else if (sys >= 120 && dia < 80) {
      category = 'Elevated';
    } else {
      category = 'Normal';
    }

    setState(() {
      _result = 'SYS: $sys, DIA: $dia'
          '${pulse == null ? '' : ', Pulse: $pulse'}\nCategory: $category';
    });
  }

  void _clear() {
    _sysController.clear();
    _diaController.clear();
    _pulseController.clear();
    setState(() => _result = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blood Pressure')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _sysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Systolic (SYS) mmHg',
                hintText: 'e.g., 120',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Diastolic (DIA) mmHg',
                hintText: 'e.g., 80',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pulse (optional) bpm',
                hintText: 'e.g., 72',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save / Calculate'),
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