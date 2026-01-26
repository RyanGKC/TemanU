import 'package:flutter/material.dart';
import 'package:temanu/login.dart';

void main() {
  runApp(TemanU());
}

class TemanU extends StatelessWidget {
  const TemanU({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      home: LoginPage()
    );
  }
}