import 'dart:ui';
import 'package:flutter/material.dart';
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
        title: Text(
          'Hi, James',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF),
          )
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), // Controls blur intensity
            child: Container(
              color: Colors.white.withValues(alpha: 0.25),
            )
          ),
        ),
      ),

      backgroundColor: Color(0xff040F31),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //add health card here
            HealthDashboardContent(),
            //medication log
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: MedicationLog(),
            )
          
          ]
        ),
      )
    );
  }
}

// THE DASHBOARD CONTENT: The list of scrolling health cards
class HealthDashboardContent extends StatelessWidget {
  const HealthDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ListView(
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        
        children: [
          const SizedBox(height: 20), 
          healthCard(Icons.water_drop, "Blood Glucose Level", "110", "mg/dl"),
          healthCard(Icons.directions_run, "Activity", "8240", "steps"),
          healthCard(Icons.favorite, "Heart Rate", "68", "bpm"),
          healthCard(Icons.opacity, "Oxygen Saturation", "98", "%"),
          healthCard(Icons.monitor_heart, "Blood Pressure", "118/76", "mmHg"),
          healthCard(Icons.local_fire_department, "Calories", "1900", "kcal"),
          healthCard(Icons.monitor_weight, "Body Weight", "80.5", "kg"),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes icons to edges
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: () {}, // make sure to add edit logic 
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white, size: 28),
                onPressed: () {}, // make sure to add share logic 
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// REUSABLE HEALTH CARD: A template for all your health data 
Widget healthCard(IconData icon, String title, String value, String unit) {
  return Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xff1A3F6B), // Darker blue card color
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
  );
}