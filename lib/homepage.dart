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
          children: ([
          
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: MedicationLog(),
            )
          
          ])
        ),
      )
    );
  }
}

