import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/homepage.dart'; 
import 'package:temanu/settingspage.dart'; // Add your Settings file
import 'package:temanu/assistantpage.dart'; // Add your Assistant file

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 1. Updated the list of pages based on your order
  final List<Widget> _pages = [
    HomePage(),
    SettingsPage(),   // Index 1
    AssistantPage(),  // Index 2
  ];

  @override
  Widget build(BuildContext context) {
    // MOVED HERE: Define pages inside build() so we can use setState to change tabs!
    final List<Widget> pages = [
      const HomePage(),
      const SettingsPage(), // Or Placeholder() if you haven't made it yet
      AssistantPage(
        // This instantly kicks the user back to the Home tab when the back button is pressed!
        onBackTabPressed: () {
          setState(() {
            _currentIndex = 0; 
          });
        },
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false, 
      backgroundColor: const Color(0xff040F31), 
      extendBody: true, 
      body: pages[_currentIndex], // UPDATED to use the local 'pages' list
      
      bottomNavigationBar: _currentIndex == 2 
          ? const SizedBox.shrink() 
          : Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30), 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30), 
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(icon: Icons.home_filled, index: 0),
                        _buildNavItem(icon: Icons.settings, index: 1),       
                        _buildNavItem(icon: Icons.auto_awesome, index: 2),   
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff00E5FF).withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xff00E5FF) : Colors.white70, 
        ),
      ),
    );
  }
}