import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:temanu/login.dart';
import 'package:temanu/theme.dart';

void main() async{
  // Ensure Flutter bindings are initialized before loading the env file
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the hidden variables
  await dotenv.load(fileName: ".env");
  runApp(TemanU());
}

class TemanU extends StatelessWidget {
  const TemanU({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: LoginPage()
    );
  }
}