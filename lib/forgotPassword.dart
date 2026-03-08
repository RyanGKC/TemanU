import 'dart:ui';
import 'package:flutter/material.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  int _currentStep = 0; // 0 = Email, 1 = OTP, 2 = Reset Password
  
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  String _errorMessage = '';

  void _nextStep() {
    setState(() {
      _errorMessage = ''; 
      
      if (_currentStep == 0) {
        if (emailController.text.contains("@")) {
          _currentStep++;
        } else {
          _errorMessage = "Please enter a valid registered email.";
        }
      } else if (_currentStep == 1) {
        if (otpController.text == "1234") { // Mock OTP
          _currentStep++;
        } else {
          _errorMessage = "Invalid OTP. Please try again.";
        }
      } else if (_currentStep == 2) {
        if (newPasswordController.text.isEmpty) {
          _errorMessage = "Password cannot be empty.";
        } else if (newPasswordController.text != confirmPasswordController.text) {
          _errorMessage = "Passwords do not match.";
        } else {
          Navigator.pop(context); // Close dialog on success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password changed successfully!")),
          );
        }
      }
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = '';
      });
    } else {
      Navigator.pop(context); // Close dialog if on the first step
    }
  }

  // Helper method for sleek TextField styling
  InputDecoration _glassInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white38, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Makes default box invisible
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            // ADDED THIS LINE: Constrains the maximum width
            constraints: const BoxConstraints(maxWidth: 400), 
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xff1A3F6B).withValues(alpha: 0.8), // Dark blue
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrinks vertically to fit content
              children: [
                const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 45),
                const SizedBox(height: 15),
                const Text(
                  'Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Error Message Display
                if (_errorMessage.isNotEmpty) ...[
                  Text(
                    _errorMessage, 
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                ],

                // Step 0: Email
                if (_currentStep == 0) ...[
                  const Text(
                    "Enter the email associated with your account.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _glassInputDecoration('Email Address', Icons.email_outlined),
                  ),
                ] 
                
                // Step 1: OTP
                else if (_currentStep == 1) ...[
                  Text(
                    "Enter the OTP sent to\n${emailController.text}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _glassInputDecoration('Enter OTP', Icons.message_outlined),
                  ),
                ] 
                
                // Step 2: New Password
                else if (_currentStep == 2) ...[
                  const Text(
                    "Enter your new password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _glassInputDecoration('New Password', Icons.lock_outline),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _glassInputDecoration('Confirm Password', Icons.lock_outline),
                  ),
                ],

                const SizedBox(height: 30),

                // Bottom Buttons
                Row(
                  children: [
                    // CANCEL / BACK BUTTON
                    Expanded(
                      child: GestureDetector(
                        onTap: _previousStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white38, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _currentStep == 0 ? "Cancel" : "Back",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    // NEXT / CONFIRM BUTTON
                    Expanded(
                      child: GestureDetector(
                        onTap: _nextStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xff3183BE), // Main blue action color
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _currentStep == 2 ? 'Confirm' : 'Next',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}