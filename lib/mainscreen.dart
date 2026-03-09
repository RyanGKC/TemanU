import 'package:flutter/material.dart';
import 'package:temanu/bottomNavBar.dart';
import 'package:temanu/homepage.dart'; 
import 'package:temanu/settingspage.dart'; 
import 'package:temanu/assistantpage.dart'; 

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const SettingsPage(), 
      AssistantPage(
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
      body: pages[_currentIndex], 
      
      // Look how clean this is now!
      bottomNavigationBar: _currentIndex == 2 
          ? const SizedBox.shrink() 
          : CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
    );
  }
}