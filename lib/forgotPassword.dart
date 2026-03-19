import 'package:flutter/material.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/button.dart'; // Assuming you have your custom button
import 'package:temanu/textbox.dart'; // Assuming you have your custom text field

enum ResetStep { email, otpAndNewPassword }

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  ResetStep _currentStep = ResetStep.email;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  Future<void> _handleSendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);

    bool success = await ApiService.requestPasswordReset(email);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Move to the next screen in the dialog
        setState(() => _currentStep = ResetStep.otpAndNewPassword);
      } else {
        _showError("Failed to send OTP. Please check your email and try again.");
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (otp.length != 6) {
      _showError("Please enter the 6-digit OTP.");
      return;
    }
    if (newPassword.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    bool success = await ApiService.resetPassword(email, otp, newPassword);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Success! Close the dialog and tell them to log in.
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated successfully! Please log in."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError("Invalid OTP or expired code. Please try again.");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xff1A3F6B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Reset Password',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // --- STEP 1: EMAIL INPUT ---
            if (_currentStep == ResetStep.email) ...[
              const Text(
                "Enter your registered email address and we will send you a 6-digit verification code.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: _emailController,
                hintText: 'Email Address',
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xff00E5FF))
                  : MyRoundedButton(
                      text: 'Send OTP',
                      backgroundColor: const Color(0xff00E5FF),
                      textColor: const Color(0xff040F31),
                      onPressed: _handleSendOTP,
                    ),
            ],

            // --- STEP 2: OTP & NEW PASSWORD ---
            if (_currentStep == ResetStep.otpAndNewPassword) ...[
              Text(
                "OTP sent to ${_emailController.text}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              MyTextField(
                controller: _otpController,
                hintText: '6-Digit OTP',
                prefixIcon: Icons.message_outlined,
              ),
              const SizedBox(height: 15),
              MyTextField(
                controller: _newPasswordController,
                hintText: 'New Password',
                prefixIcon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xff00E5FF))
                  : MyRoundedButton(
                      text: 'Reset Password',
                      backgroundColor: const Color(0xff00E5FF),
                      textColor: const Color(0xff040F31),
                      onPressed: _handleResetPassword,
                    ),
            ],

            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}