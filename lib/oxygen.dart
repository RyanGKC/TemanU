import 'package:flutter/material.dart';
import 'dart:ui';

class OxygenSaturationDetail extends StatefulWidget {
  const OxygenSaturationDetail({super.key});

  @override
  State<OxygenSaturationDetail> createState() => _OxygenSaturationDetailState();
}

class _OxygenSaturationDetailState extends State<OxygenSaturationDetail> {
  String selectedRange = "W";

  List<double> getGraphData() {
    switch (selectedRange) {
      case "D": return [98, 97, 99, 96, 98, 95, 98];
      case "W": return [98, 94, 96, 99, 97, 98, 95];
      case "M": return [94, 95, 98, 99, 97, 96, 96, 98, 99, 94];
      default: return [96, 97, 98, 95, 99, 94];
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
        title: const Text(
          "Oxygen Saturation",
          style: TextStyle(color: Color(0xff35E0FF), fontSize: 25, fontWeight: FontWeight.w600),
        ),
        
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff35E0FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 60),
            Center(
              child: Column(
                children: [
                  const Text("Current", style: TextStyle(color: Colors.white, fontSize: 16)),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("98", style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                      Text("%", style: TextStyle(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                  const Text("Normal Range (95% - 100%)", style: TextStyle(color: Color(0xff35E0FF), fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // navigation tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ["D", "W", "M", "3M", "Y"].map((label) => _buildFilterButton(label)).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // the graph with axiss
            Container(
              height: 240,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
              decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(25)),
              child: CustomPaint(
                painter: LabeledOxygenChartPainter(getGraphData(), selectedRange),
              ),
            ),
            
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text("Contextual Insights", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 10),
            Row(children: [
              _buildContextCard("Sleeping", "96%", Icons.bedtime),
              const SizedBox(width: 10),
              _buildContextCard("Resting", "98%", Icons.chair),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    bool isSelected = selectedRange == label;
    return GestureDetector(
      onTap: () => setState(() => selectedRange = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff35E0FF) : Colors.transparent, 
          borderRadius: BorderRadius.circular(20)
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildContextCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xff35E0FF), size: 24),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LabeledOxygenChartPainter extends CustomPainter {
  final List<double> data;
  final String range;
  LabeledOxygenChartPainter(this.data, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff35E0FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    double leftMargin = 40;
    double bottomMargin = 30;
    double usableWidth = size.width - leftMargin;
    double usableHeight = size.height - bottomMargin;

    // Draw Axes
    canvas.drawLine(Offset(leftMargin, 0), Offset(leftMargin, usableHeight), axisPaint);
    canvas.drawLine(Offset(leftMargin, usableHeight), Offset(size.width, usableHeight), axisPaint);

    // 1. Y-Axis Labels (90% - 100%)
    for (int val in [90, 95, 100]) {
      double y = usableHeight - ((val - 90) / 10 * usableHeight);
      _drawText(canvas, "$val%", Offset(5, y - 7), Colors.white54, 10);
      canvas.drawLine(Offset(leftMargin - 5, y), Offset(leftMargin, y), axisPaint);
    }

    if (data.isEmpty) return;

    // 2. dynamic X-Axis Labels based on Range
    List<String> xLabels = [];
    if (range == "D") {
      xLabels = ["12am", "6am", "12pm", "6pm", "12am"];
    } else if (range == "W") {
      xLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    } else if (range == "M") {
      xLabels = ["Week 1", "Week 2", "Week 3", "Week 4"];
    } else {
      xLabels = ["Jan", "Apr", "Jul", "Oct", "Dec"];
    }

    double stepX = usableWidth / (xLabels.length - 1);
    for (int i = 0; i < xLabels.length; i++) {
      double x = leftMargin + (i * stepX);
      _drawText(canvas, xLabels[i], Offset(x - 10, usableHeight + 8), Colors.white54, 9);
    }

    // 3. data line draw here
    double dataStepX = usableWidth / (data.length - 1);
    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      double y = usableHeight - ((data[i] - 90) / 10 * usableHeight);
      double x = leftMargin + (i * dataStepX);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      
      // Draw small glow points
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xff35E0FF));
    }
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size) {
    TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout()..paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}