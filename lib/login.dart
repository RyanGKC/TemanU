import 'package:flutter/material.dart';
import 'package:temanu/button.dart';
import 'package:temanu/logindetails.dart';
import 'package:temanu/registerdetails.dart';
import 'package:temanu/theme.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.cardBackground,
                  backgroundImage: AssetImage('assets/img/TemanU-logo.png'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'TemanU',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  )
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Health Companion',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                MyRoundedButton(
                  text: 'Login',
                  backgroundColor: AppTheme.primaryColor,
                  textColor: AppTheme.textPrimary,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const LoginDetails())
                    );
                  },
                ),
                const SizedBox(height: 16),
                MyRoundedButton(
                  text: 'Register',
                  backgroundColor: AppTheme.cardBackground,
                  textColor: AppTheme.textPrimary,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const RegisterDetails())
                    );
                  },
                ),
              ],
            )
          )
        )
      )
    );
  }
}