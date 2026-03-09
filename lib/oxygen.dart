import 'package:flutter/material.dart';

class OxygenSaturationDetail extends StatefulWidget {
  const OxygenSaturationDetail({super.key});

  @override
  State<OxygenSaturationDetail> createState() => _OxygenSaturationDetailState();
}

class _OxygenSaturationDetailState extends State<OxygenSaturationDetail> with SingleTickerProviderStateMixin {
  //  Setting up animation
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  final double currentSpO2 = 98.0;

  final List<Map<String, dynamic>> _historyData = const [
    {"date": "Mar 10, 2:15 PM", "value": 98.0},
    {"date": "Mar 10, 10:30 AM", "value": 94.0},
    {"date": "Mar 9, 8:00 PM", "value": 96.0},
    {"date": "Mar 9, 12:45 PM", "value": 94.0},
  ];

  @override
  void initState() {
    super.initState();
    // initialize the controller to run for 2 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // this animation goes from 0.0 to 0.98 (98%)
    _progressAnimation = Tween<double>(begin: 0.0, end: currentSpO2 / 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward(); // start the animation when page loads
  }

  @override
  void dispose() {
    _controller.dispose(); // to help prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // the logic from standard values guide
    Color statusColor;
    String statusText;
    if (currentSpO2 >= 98) {
      statusColor = const Color(0xff8BC34A); // Green: Normal
      statusText = "Oxygen levels are normal";
    } else if (currentSpO2 >= 95) {
      statusColor = const Color(0xffDCD835); // Yellow: Insufficient
      statusText = "Insufficient level";
    } else {
      statusColor = Colors.orangeAccent;
      statusText = "Decreased levels";
    }

    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      appBar: AppBar(
        title: const Text("Oxygen Saturation", style: TextStyle(color: Color(0xff00E5FF))),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 50),
            
            // 2. ANIMATED CIRCULAR GAUGE
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180, height: 180,
                      child: CircularProgressIndicator(
                        value: _progressAnimation.value, // Animates from 0 to 0.98
                        strokeWidth: 15,
                        color: statusColor,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      "${(currentSpO2 * (_progressAnimation.value / (currentSpO2 / 100))).toInt()}%",
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 20),
            Text(statusText, style: TextStyle(color: statusColor, fontSize: 18)),
            
            const SizedBox(height: 50),
            const Text("Oxygen Wave", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),

            // 3. SMOOTH MEDICAL WAVEFORM
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xff1A3F6B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: CustomPaint(
                painter: SmoothWavePainter(waveColor: statusColor), 
                size: Size.infinite
              ),
            ),
            
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25.0),
              child: Align(alignment: Alignment.centerLeft, child: Text("History", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 15),
            ..._historyData.map((data) => _buildHistoryCard(data["date"], data["value"])),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(String date, double value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(color: Colors.white70)),
          Text("${value.toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// smooth wave
class SmoothWavePainter extends CustomPainter {
  final Color waveColor;
  SmoothWavePainter({required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    var path = Path();
    double midHeight = size.height / 2;
    double waveLength = 40.0;
    double waveHeight = 20.0;

    path.moveTo(0, midHeight);

    for (double i = 0; i <= size.width; i += waveLength) {
      // QuadraticBezier for the smooth curvy waves
      path.quadraticBezierTo(
        i + (waveLength / 4), midHeight - waveHeight, // Peak
        i + (waveLength / 2), midHeight, 
      );
      path.quadraticBezierTo(
        i + (3 * waveLength / 4), midHeight + waveHeight, // bottom
        i + waveLength, midHeight,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}