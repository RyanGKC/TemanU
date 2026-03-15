import 'package:flutter/material.dart';
import 'dart:ui';

class HeartRateDetail extends StatefulWidget {
  const HeartRateDetail({super.key});

  @override
  State<HeartRateDetail> createState() => _HeartRateDetailState();
}

class _HeartRateDetailState extends State<HeartRateDetail> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String selectedRange = "W"; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<int> getGraphData() {
    switch (selectedRange) {
      case "D": return [65, 72, 85, 120, 75, 68, 70];
      case "W": return [70, 75, 72, 80, 68, 74, 72];
      case "M": return [68, 70, 82, 75, 70, 69, 71, 73];
      default: return [72, 70, 75, 71, 74, 72];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff031447),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text("Heart Rate", style: TextStyle(color: Color(0xff35E0FF), fontSize: 25, fontWeight: FontWeight.w600)),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 60),
            
            // 1. main metrics
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  const Text("Current", style: TextStyle(color: Colors.white, fontSize: 18)),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("72", style: TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.bold)),
                      Padding(padding: EdgeInsets.only(bottom: 12, left: 5), child: Text("bpm", style: TextStyle(color: Colors.white, fontSize: 24))),
                    ],
                  ),
                  const Text("Status: Healthy Resting Rate", style: TextStyle(color: Color(0xff35E0FF), fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 30),
                  ScaleTransition(scale: _animation, child: const Icon(Icons.favorite, color: Colors.redAccent, size: 80)),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BpmMetric(label: "MIN", value: "62"),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 40), child: Text("/", style: TextStyle(color: Colors.white24, fontSize: 40))),
                      _BpmMetric(label: "MAX", value: "115"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. graphs
            _buildSectionTitle("Trending Trends"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 20, 20, 15),
              decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(25)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ["D", "W", "M", "Y"].map((range) => _buildFilterButton(range)).toList(),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(painter: LabeledHeartTrendPainter(getGraphData(), selectedRange)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. health notes
            _buildSectionTitle("Heart Health Notes"),
            const SizedBox(height: 10),
            _buildHealthNote("Resting HR", "60-100 BPM", "Normal range for most adults while at rest."),
            _buildHealthNote("Activity", "115 BPM", "High recorded during light exercise today."),
            _buildHealthNote("Recovery", "Excellent", "Your heart returns to resting rate quickly."),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // helpers

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterButton(String label) {
    bool isSelected = selectedRange == label;
    return GestureDetector(
      onTap: () => setState(() => selectedRange = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xff35E0FF) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHealthNote(String title, String value, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xff35E0FF), fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _BpmMetric extends StatelessWidget {
  final String label, value;
  const _BpmMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Painter with Labeled Axes, Y is BPM and X is time
class LabeledHeartTrendPainter extends CustomPainter {
  final List<int> data;
  final String range;
  LabeledHeartTrendPainter(this.data, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff35E0FF)..strokeWidth = 3..style = PaintingStyle.stroke;
    final axisPaint = Paint()..color = Colors.white24..strokeWidth = 1;

    double leftMargin = 35;
    double bottomMargin = 25;
    double usableWidth = size.width - leftMargin;
    double usableHeight = size.height - bottomMargin;

    // Draw Axes
    canvas.drawLine(Offset(leftMargin, 0), Offset(leftMargin, usableHeight), axisPaint);
    canvas.drawLine(Offset(leftMargin, usableHeight), Offset(size.width, usableHeight), axisPaint);

    // Y-Axis Labels (40 - 160 BPM)
    List<int> yTicks = [40, 80, 120, 160];
    for (int tick in yTicks) {
      double y = usableHeight - ((tick - 40) / 120 * usableHeight);
      _drawText(canvas, "$tick", Offset(5, y - 7), Colors.white54, 10);
    }

    // X-Axis Labels
    List<String> xLabels = range == "W" ? ["M", "T", "W", "T", "F", "S", "S"] : ["Start", "Mid", "End"];
    double stepX = usableWidth / (xLabels.length - 1);
    for (int i = 0; i < xLabels.length; i++) {
      _drawText(canvas, xLabels[i], Offset(leftMargin + (i * stepX) - 5, usableHeight + 5), Colors.white54, 10);
    }

    if (data.isEmpty) return;

    // Data Line
    double dataStepX = usableWidth / (data.length - 1);
    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      double y = usableHeight - ((data[i] - 40) / 120 * usableHeight);
      double x = leftMargin + (i * dataStepX);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xff35E0FF));
    }
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size) {
    TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout()..paint(canvas, offset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}