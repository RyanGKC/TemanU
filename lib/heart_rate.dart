import 'package:flutter/material.dart';

class HeartRateDetail extends StatefulWidget {
  const HeartRateDetail({super.key}); 

  @override
  State<HeartRateDetail> createState() => _HeartRateDetailState();
}

class _HeartRateDetailState extends State<HeartRateDetail> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // current heart rate
  final int currentBpm = 68; 
  
  // History data list 
  final List<Map<String, dynamic>> _historyData = [
    {"date": "Mar 10, 2:15 PM", "value": 68},
    {"date": "Mar 10, 10:30 AM", "value": 110}, 
    {"date": "Mar 9, 8:00 PM", "value": 65},
    {"date": "Mar 9, 12:45 PM", "value": 72},
    {"date": "Mar 8, 3:30 PM", "value": 85},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // logic to determine if heart rate is normal
    bool isNormal = currentBpm >= 60 && currentBpm <= 100;
    Color statusColor = isNormal ? const Color(0xff00E5FF) : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      appBar: AppBar(
        title: const Text("Heart Rate", style: TextStyle(color: Color(0xff00E5FF))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView( // the page is scrollable
        child: Column(
          children: [
            const SizedBox(height: 40),
            ScaleTransition(
              scale: _animation,
              child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100),
            ),
            const SizedBox(height: 20),
            Text(
              "$currentBpm BPM",
              style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
            ),
            Text(
              isNormal ? "Your heart rate is normal" : "Heart rate is outside normal range",
              style: TextStyle(color: statusColor, fontSize: 16),
            ),
            
            const SizedBox(height: 60),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("History", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            
            // 
            ..._historyData.map((data) => _buildHistoryCard(data["date"], data["value"])),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(String date, int value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(color: Colors.white70)),
          Text("$value BPM", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}