import 'dart:ui';
import 'homepage.dart';
import 'settingspage.dart';
import 'assistantpage.dart';

import 'package:flutter/material.dart';

class Mainscreen extends StatefulWidget {
  const Mainscreen({super.key});
  @override
  State<Mainscreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<Mainscreen> {

  int  _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    SettingsPage(),
    AssistantPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: IndexedStack(
        index:_currentIndex,
        children:_pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Home"
          ),
         
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings"
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Assistant"
          ),
        ],
      ),
    );
  }
}