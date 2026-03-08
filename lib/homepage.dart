import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/bloodpressure.dart';
import 'package:temanu/bodyweight.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/caloriesMain.dart';
import 'package:temanu/medicationlog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Hi, James',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF),
          )
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), 
            child: Container(
              color: Colors.white.withValues(alpha: 0.25),
            )
          ),
        ),
      ),

      backgroundColor: const Color(0xff040F31),

      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HealthDashboardContent(),
            Padding(
              padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
              child: MedicationLog(), // Assuming this is your custom widget
            ),
            
            // FIXED BOTTOM: Spacer to push content above the floating nav bar
            SizedBox(height: 120), 
          ]
        ),
      )
    );
  }
}

// 1. CONVERTED TO STATEFUL WIDGET
class HealthDashboardContent extends StatefulWidget {
  const HealthDashboardContent({super.key});

  @override
  State<HealthDashboardContent> createState() => _HealthDashboardContentState();
}

class _HealthDashboardContentState extends State<HealthDashboardContent> {
  
  // 2. MASTER LIST OF METRICS
  // We store the visibility state ('isVisible') for each card here.
  final List<Map<String, dynamic>> _metricsData = [
    {
      "icon": Icons.water_drop, "title": "Blood Glucose Level", "value": "110", "unit": "mg/dl", 
      "destination": const HomePage(), "isVisible": true
    },
    {
      "icon": Icons.favorite, "title": "Heart Rate", "value": "68", "unit": "bpm", 
      "destination": const HomePage(), "isVisible": true
    },
    {
      "icon": Icons.opacity, "title": "Oxygen Saturation", "value": "98", "unit": "%", 
      "destination": const HomePage(), "isVisible": true
    },
    {
      "icon": Icons.monitor_heart, "title": "Blood Pressure", "value": "118/76", "unit": "mmHg", 
      "destination": const HomePage(), "isVisible": true
    },
    {
      "icon": Icons.local_fire_department, "title": "Calories", "value": "1900", "unit": "kcal", 
      "destination": const CaloriesMain(), "isVisible": true
    },
    {
      "icon": Icons.monitor_weight, "title": "Body Weight", "value": "80.5", "unit": "kg", 
      "destination": const HomePage(), "isVisible": true
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var metric in _metricsData) {
        // Look up the saved boolean using the metric's title as the key.
        // If it doesn't exist (e.g., first time opening the app), default to true.
        metric['isVisible'] = prefs.getBool(metric['title']) ?? true;
      }
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // 3. EDIT BOTTOM SHEET
  void _showEditMetricsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // StatefulBuilder allows the bottom sheet to update its own switches instantly
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xff1A3F6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text(
                      "Customize Dashboard",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  
                  // List of Toggle Switches
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return SwitchListTile(
                          activeColor: const Color(0xff00E5FF),
                          activeTrackColor: const Color(0xff00E5FF).withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                          secondary: Icon(metric['icon'], color: Colors.white70),
                          title: Text(metric['title'], style: const TextStyle(color: Colors.white)),
                          value: metric['isVisible'],
                          onChanged: (bool value) {
                            // Update the bottom sheet UI
                            setModalState(() {
                              metric['isVisible'] = value;
                            });
                            // Update the main page UI behind the bottom sheet
                            setState(() {}); 

                            _savePreference(metric['title'], value);
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Done Button
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff00E5FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter the list to only show items where 'isVisible' is true
    final visibleMetrics = _metricsData.where((m) => m['isVisible'] == true).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          const SizedBox(height: 20), 
          healthCard(context, Icons.water_drop, "Blood Glucose Level", "110", "mg/dl", HomePage()),
          healthCard(context, Icons.favorite, "Heart Rate", "68", "bpm", HomePage()),
          healthCard(context, Icons.opacity, "Oxygen Saturation", "98", "%", HomePage()),
          healthCard(context, Icons.monitor_heart, "Blood Pressure", "118/76", "mmHg", const BloodPressurePage()),
          healthCard(context, Icons.local_fire_department, "Calories", "1900", "kcal", CaloriesMain()),
          healthCard(context, Icons.monitor_weight, "Body Weight", "80.5", "kg", const BodyWeightPage()),
          const SizedBox(height: 20),
          
          // 1. ADDED: LayoutBuilder to detect screen width
          LayoutBuilder(
            builder: (context, constraints) {
              // 600 pixels is the standard cutoff for tablets / wide screens
              bool isWideScreen = constraints.maxWidth > 800;
              
              // If wide, divide the width by 2 and subtract a little extra for the gap between them.
              // If narrow, use the full available width.
              double cardWidth = isWideScreen ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              // 2. REPLACED: ListView.builder with a responsive Wrap
              return Wrap(
                spacing: 15, // Horizontal gap between the 2 columns
                runSpacing: 0, // Vertical gap (Already handled by your healthCard's bottom margin!)
                children: visibleMetrics.map((metric) {
                  return SizedBox(
                    width: cardWidth,
                    child: healthCard(
                      context, 
                      metric['icon'], 
                      metric['title'], 
                      metric['value'], 
                      metric['unit'], 
                      metric['destination']
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // Edit & Share Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: _showEditMetricsBottomSheet, // Triggers the bottom sheet!
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 28),
                onPressed: () {
                  // TODO: Add share logic
                },  
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Global Widget Builder (Remains mostly the same)
  Widget healthCard(BuildContext context, IconData icon, String title, String value, String unit, Widget destinationPage) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff1A3F6B), 
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 35),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(color: Colors.white70, fontSize: 14)
                ),
                Text(
                  "$value $unit", 
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}