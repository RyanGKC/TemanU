import 'package:flutter/material.dart';
import 'package:temanu/bottomNavBar.dart';
import 'package:temanu/homepage.dart'; 
import 'package:temanu/myDoctors.dart';
import 'package:temanu/settingspage.dart'; 
import 'package:temanu/assistantpage.dart'; 
import 'package:temanu/theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // 1. Create the GlobalKey to access the dashboard state
  final GlobalKey<HealthDashboardContentState> _dashboardKey = GlobalKey();

  // 2. Store the latest health data to pass to the Assistant
  Map<String, dynamic> _latestHealthData = {};

  @override
  Widget build(BuildContext context) {
    // --- THE FIX: Added MyDoctorsPage to the list of screens ---
    final List<Widget> pages = [
      // Index 0
      HomePage(dashboardKey: _dashboardKey),
      
      // Index 1
      const MyDoctorsPage(), 
      
      // Index 2
      AssistantPage(
        userData: _latestHealthData,
        onBackTabPressed: () {
          setState(() {
            _currentIndex = 0; 
          });
        },
      ),

      // Index 3
      const SettingsPage(), 
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false, 
      backgroundColor: AppTheme.background, 
      extendBody: true, 
      body: pages[_currentIndex], 
      
      bottomNavigationBar: _currentIndex == 2 // Hides the nav bar when the Assistant (Index 2) is open
          ? const SizedBox.shrink() 
          : CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                // Intercept the tap to grab data before switching to the Assistant (Index 2)
                if (index == 2) {
                  if (_dashboardKey.currentState != null) {
                    _latestHealthData = _dashboardKey.currentState!.gatherDataForAI();
                  }
                }
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
    );
  }
}