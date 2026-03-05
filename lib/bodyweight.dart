import 'dart:math';
import 'package:flutter/material.dart';

class BodyWeightPage extends StatefulWidget {
  const BodyWeightPage({super.key});

  @override
  State<BodyWeightPage> createState() => _BodyWeightPageState();
}

class _BodyWeightPageState extends State<BodyWeightPage> {
  // ====== Data ======
  // Current weight (kg)
  double _currentWeight = 80.5;

  // Height (cm) for BMI
  double? _heightCm;

  // Weight history (kg) for chart + list (latest last)
  final List<double> _history = [79.2, 79.7, 80.1, 80.0, 80.3, 80.5];

  // ====== Helpers ======
  double? get _bmi {
    final h = _heightCm;
    if (h == null || h <= 0) return null;
    final hm = h / 100.0;
    return _currentWeight / (hm * hm);
  }

  String get _bmiCategory {
    final bmi = _bmi;
    if (bmi == null) return '—';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String get _changeText {
    if (_history.length < 2) return '0.0 kg';
    final diff = _history.last - _history[_history.length - 2];
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)} kg';
  }

  Color get _changeColor {
    if (_history.length < 2) return Colors.white70;
    final diff = _history.last - _history[_history.length - 2];
    if (diff > 0) return const Color(0xffFF8A80); // up = reddish
    if (diff < 0) return const Color(0xffB2FF59); // down = greenish
    return Colors.white70;
  }

  void _applyWeightChange(double deltaKg) {
    setState(() {
      _currentWeight = max(0, _currentWeight + deltaKg);
      _history.add(_currentWeight);
      // keep last 14 points
      while (_history.length > 14) {
        _history.removeAt(0);
      }
    });
  }

  Future<void> _showChangeWeightSheet() async {
    final controller = TextEditingController(text: '2.0');
    double delta = 2.0;
    bool isIncrease = false; // default: decrease (like screenshot "Change -2.0kg")

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff0B1C4D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.monitor_weight, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Change Weight',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // +/- toggle
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _segButton(
                        label: 'Decrease',
                        selected: !isIncrease,
                        onTap: () => setState(() => isIncrease = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _segButton(
                        label: 'Increase',
                        selected: isIncrease,
                        onTap: () => setState(() => isIncrease = true),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (kg)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  delta = double.tryParse(v.trim()) ?? delta;
                },
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff00E5FF),
                    foregroundColor: const Color(0xff040F31),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(controller.text.trim());
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(ctx);
                    _applyWeightChange(isIncrease ? amount : -amount);
                  },
                  child: Text(
                    isIncrease ? 'Apply +${delta.toStringAsFixed(1)} kg' : 'Apply -${delta.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showHeightDialog() async {
    final controller = TextEditingController(text: _heightCm?.toStringAsFixed(0) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff0B1C4D),
          title: const Text('Set Height (cm)', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., 170',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff00E5FF),
                foregroundColor: const Color(0xff040F31),
              ),
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v <= 0) return;
                setState(() => _heightCm = v);
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  // simple segmented button
  Widget _segButton({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xff040F31) : Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Body Weight',
          style: TextStyle(
            color: Color(0xff00E5FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Set height',
            onPressed: _showHeightDialog,
            icon: const Icon(Icons.height),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            // Top summary
            _card(
              child: Row(
                children: [
                  const Icon(Icons.monitor_weight, color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Weight', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currentWeight.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text('kg', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text('Change', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          _changeText,
                          style: TextStyle(color: _changeColor, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Chart
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trend',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _WeightChartPainter(points: _history),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Older', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      Text('Latest', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // BMI + button
            Row(
              children: [
                Expanded(
                  child: _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BMI', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(
                          _bmi == null ? 'Set height' : _bmi!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_bmiCategory, style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _showHeightDialog,
                          child: const Text(
                            'Edit height',
                            style: TextStyle(color: Color(0xff00E5FF), fontWeight: FontWeight.w700),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Actions', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF),
                              foregroundColor: const Color(0xff040F31),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _showChangeWeightSheet,
                            child: const Text('Change weight', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _history.clear();
                                _history.add(_currentWeight);
                              });
                            },
                            child: const Text('Reset trend', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // History list
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Records',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._buildHistoryTiles(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistoryTiles() {
    final items = _history.reversed.take(6).toList();
    return List<Widget>.generate(items.length, (i) {
      final w = items[i];
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Color(0xff00E5FF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${w.toStringAsFixed(1)} kg',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              i == 0 ? 'Latest' : '',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    });
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

// ====== Simple chart painter (no extra packages) ======
class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // grid lines
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), bgPaint);
    }

    if (points.length < 2) return;

    final minV = points.reduce(min);
    final maxV = points.reduce(max);
    final range = max(0.0001, maxV - minV);

    Offset mapPoint(int i) {
      final x = (i / (points.length - 1)) * size.width;
      final t = (points[i] - minV) / range; // 0..1
      final y = size.height - (t * (size.height - 10)) - 5; // padding
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = const Color(0xff00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(mapPoint(0).dx, mapPoint(0).dy);
    for (int i = 1; i < points.length; i++) {
      final p = mapPoint(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // draw dots
    final dotPaint = Paint()..color = Colors.white;
    for (int i = 0; i < points.length; i++) {
      final p = mapPoint(i);
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}