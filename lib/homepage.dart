import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/caloriesMain.dart';
import 'package:temanu/medicationlog.dart';
import 'package:temanu/bodyweight.dart';
import 'package:temanu/bloodpressure.dart';

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

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const HealthDashboardContent(),
            const Padding(
              padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
              child: MedicationLog(),
            ),
            
            // 3. FIXED BOTTOM: Added a large spacer to push content above the floating nav bar
            const SizedBox(height: 120), 
          ]
        ),
      )
    );
  }
}

class HealthDashboardContent extends StatelessWidget {
  const HealthDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        
        children: [
          const SizedBox(height: 20), 
          healthCard(context, Icons.water_drop, "Blood Glucose Level", "110", "mg/dl", HomePage()),
          healthCard(context, Icons.favorite, "Heart Rate", "68", "bpm", HomePage()),
          healthCard(context, Icons.opacity, "Oxygen Saturation", "98", "%", HomePage()),
          healthCard(context, Icons.monitor_heart, "Blood Pressure", "118/76", "mmHg", const BloodPressurePage()),
          healthCard(context, Icons.local_fire_department, "Calories", "1900", "kcal", CaloriesMain()),
          healthCard(context, Icons.monitor_weight, "Body Weight", "80.5", "kg", const BodyWeightPage()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: () {}, 
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 28),
                onPressed: () {},  
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget healthCard(BuildContext context, IconData icon, String title, String value, String unit, Widget destinationPage) {
  return GestureDetector(
    onTap: () {
      // Navigates directly to the Widget passed into the parameter
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