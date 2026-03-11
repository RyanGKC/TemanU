import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/bloodpressure.dart';
import 'package:temanu/bodyweight.dart';
import 'package:temanu/caloriesMain.dart';
import 'package:temanu/medicationlog.dart';
import 'package:temanu/patientData.dart';
import 'package:temanu/pdfGenerator.dart';
import 'package:temanu/profileInformation.dart';

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
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.white.withValues(alpha: 0.25),
            ),
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
              child: MedicationLog(),
            ),
            SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class HealthDashboardContent extends StatefulWidget {
  const HealthDashboardContent({super.key});

  @override
  State<HealthDashboardContent> createState() => _HealthDashboardContentState();
}

class _HealthDashboardContentState extends State<HealthDashboardContent> {
  // Holds patient data returned from ProfileInformationPage
  PatientData _patientData = const PatientData(
    name: 'James',
    dob: '15 May 1990',
    age: '35',
    gender: 'Male',
    height: '180',
    weight: '75',
    bloodType: 'O+',
    conditions: 'None',
  );

  final List<Map<String, dynamic>> _metricsData = [
    {
      "icon": Icons.water_drop, "title": "Blood Glucose Level", "value": "110", "unit": "mg/dl",
      "destination": const HomePage(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.directions_run, "title": "Activity", "value": "8240", "unit": "steps",
      "destination": const HomePage(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.favorite, "title": "Heart Rate", "value": "68", "unit": "bpm",
      "destination": const HomePage(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.opacity, "title": "Oxygen Saturation", "value": "98", "unit": "%",
      "destination": const HomePage(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.monitor_heart, "title": "Blood Pressure", "value": "118/76", "unit": "mmHg",
      "destination": const BloodPressurePage(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.local_fire_department, "title": "Calories", "value": "1900", "unit": "kcal",
      "destination": const CaloriesMain(), "isVisible": true, "isShareSelected": true
    },
    {
      "icon": Icons.monitor_weight, "title": "Body Weight", "value": "80.5", "unit": "kg",
      "destination": const BodyWeightPage(), "isVisible": true, "isShareSelected": true
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
        metric['isVisible'] = prefs.getBool(metric['title']) ?? true;
      }
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Navigate to ProfileInformationPage and capture returned PatientData
  Future<void> _navigateToProfile() async {
    final result = await Navigator.push<PatientData>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileInformationPage()),
    );
    if (result != null) {
      setState(() => _patientData = result);
    }
  }

  List<Map<String, dynamic>> get _selectedMetrics => _metricsData
      .where((m) => m['isShareSelected'] == true)
      .cast<Map<String, dynamic>>()
      .toList();

  void _showEditMetricsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
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
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Customize Dashboard",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return SwitchListTile(
                          activeThumbColor: const Color(0xff00E5FF),
                          activeTrackColor:
                              const Color(0xff00E5FF).withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.1),
                          secondary:
                              Icon(metric['icon'], color: Colors.white70),
                          title: Text(metric['title'],
                              style: const TextStyle(color: Colors.white)),
                          value: metric['isVisible'],
                          onChanged: (bool value) {
                            setModalState(() => metric['isVisible'] = value);
                            setState(() {});
                            _savePreference(metric['title'], value);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff00E5FF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done",
                            style: TextStyle(
                                color: Color(0xff040F31),
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Opens the share/save selection bottom sheet
  void _showShareMetricsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xff1A3F6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Select Data to Export",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),

                  // Metric checkboxes
                  Expanded(
                    child: ListView.builder(
                      itemCount: _metricsData.length,
                      itemBuilder: (context, index) {
                        final metric = _metricsData[index];
                        return CheckboxListTile(
                          activeColor: const Color(0xff00E5FF),
                          checkColor: const Color(0xff040F31),
                          side: const BorderSide(color: Colors.white70),
                          secondary:
                              Icon(metric['icon'], color: Colors.white70),
                          title: Text(metric['title'],
                              style: const TextStyle(color: Colors.white)),
                          value: metric['isShareSelected'],
                          onChanged: (bool? value) {
                            setModalState(
                                () => metric['isShareSelected'] = value ?? false);
                          },
                        );
                      },
                    ),
                  ),

                  // Action buttons — Share is hidden on web
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Row(
                      children: [
                        // Share button — mobile/desktop only
                        if (!kIsWeb) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xff00E5FF), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                PdfGenerator.generateAndShare(
                                  selectedMetrics: _selectedMetrics,
                                  patientData: _patientData.toMap(),
                                );
                              },
                              child: const Text(
                                "Share PDF",
                                style: TextStyle(
                                    color: Color(0xff00E5FF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Save button — always visible
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              PdfGenerator.generateAndSave(
                                selectedMetrics: _selectedMetrics,
                                patientData: _patientData.toMap(),
                                context: context,
                              );
                            },
                            child: const Text(
                              "Save PDF",
                              style: TextStyle(
                                  color: Color(0xff040F31),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final visibleMetrics =
        _metricsData.where((m) => m['isVisible'] == true).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWideScreen = constraints.maxWidth > 800;
              double cardWidth = isWideScreen
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 15,
                runSpacing: 0,
                children: visibleMetrics.map((metric) {
                  return SizedBox(
                    width: cardWidth,
                    child: healthCard(
                      context,
                      metric['icon'],
                      metric['title'],
                      metric['value'],
                      metric['unit'],
                      metric['destination'],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: _showEditMetricsBottomSheet,
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 28),
                onPressed: _showShareMetricsBottomSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget healthCard(BuildContext context, IconData icon, String title,
      String value, String unit, Widget destinationPage) {
    return GestureDetector(
      onTap: () {
        if (destinationPage is ProfileInformationPage) {
          _navigateToProfile();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationPage),
          );
        }
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
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                Text("$value $unit",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}