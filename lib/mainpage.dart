import 'dart:ui';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // This keeps track of which tab (Home, Search, or Profile) is selected 
  int _selectedIndex = 0;

  // This is a list of the different screens for each tab 
  final List<Widget> _pages = [
    const HealthDashboardContent(), // Our main dashboard with cards
    const Center(child: Text('Search Page', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Profile Page', style: TextStyle(color: Colors.white))),
  ];

  // This function updates the screen when a tab is clicked 
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31), // Main dark background 
      
      // THE TOP BAR: Includes "Hi, James" and the Notification Bell 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Hi, James',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF), // Bright blue text
          )
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: Color(0xff00E5FF)),
              onPressed: () {
                // Future: Add notification logic here 
              },
            ),
          ),
        ],
      ),

      // THE BODY: Layers the content and the bottom corner buttons 
      body: Stack(
        children: [
          _pages[_selectedIndex], // Shows the current tab's content 

          // Only show Edit/Share buttons if we are on the Home tab (index 0)
          if (_selectedIndex == 0)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            ),
        ],
      ),

      // THE NAVIGATION TABS: Home, Search, Profile 
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xff040F31),
        selectedItemColor: const Color(0xff00E5FF),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
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
        children: [
          const SizedBox(height: 20), // Extra space below the AppBar
          healthCard(Icons.water_drop, "Blood Glucose Level", "110", "mg/dl"),
          healthCard(Icons.directions_run, "Activity", "8240", "steps"),
          healthCard(Icons.favorite, "Heart Rate", "68", "bpm"),
          healthCard(Icons.opacity, "Oxygen Saturation", "98", "%"),
          healthCard(Icons.monitor_heart, "Blood Pressure", "118/76", "mmHg"),
          healthCard(Icons.local_fire_department, "Calories", "1900", "kcal"),
          healthCard(Icons.monitor_weight, "Body Weight", "80.5", "kg"),
          const SizedBox(height: 80), // Space so buttons don't cover last card
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