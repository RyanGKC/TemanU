// WIDGET: Stateful Change Password Dialog
import 'dart:ui';

import 'package:flutter/material.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  // 0 = OTP Step, 1 = New Password Step
  int _currentStep = 0; 

  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    if (_otpController.text.length == 6) {
      // Simulate network request to verify OTP
      setState(() => _isLoading = true);
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _isLoading = false;
          _currentStep = 1; // Move to password step
        });
      });
    }
  }

  void _saveNewPassword() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // Simulate saving to backend
      Future.delayed(const Duration(seconds: 1), () {
        setState(() => _isLoading = false);
        Navigator.pop(context); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated successfully!"),
            backgroundColor: Color(0xff00E5FF),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xff1A3F6B).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            // AnimatedSwitcher gives a smooth crossfade between the two steps
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == 0 ? _buildOtpStep() : _buildPasswordStep(),
            ),
          ),
        ),
      ),
    );
  }

  // --- STEP 1: OTP VIEW ---
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey("OtpStep"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, color: Color(0xff00E5FF), size: 45),
        const SizedBox(height: 15),
        const Text(
          "Enter OTP",
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "A 6-digit code has been sent to your registered email address.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 25),
        
        // OTP Input Field
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: "", // Hides the 0/6 counter
            hintText: "••••••",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          onChanged: (val) {
            if (val.length == 6) {
              FocusScope.of(context).unfocus(); // Auto dismiss keyboard
            }
          },
        ),
        
        const SizedBox(height: 25),
        _buildDialogButtons(
          primaryText: "Verify",
          onPrimaryPressed: _otpController.text.length == 6 ? _verifyOtp : null,
        ),
      ],
    );
  }

  // --- STEP 2: NEW PASSWORD VIEW ---
  Widget _buildPasswordStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey("PasswordStep"),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_reset, color: Color(0xff00E5FF), size: 45),
          const SizedBox(height: 15),
          const Text(
            "New Password",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),

          // New Password Field
          _buildPasswordField(
            controller: _newPasswordController,
            label: "New Password",
            obscure: _obscureNewPass,
            onToggleObscure: () => setState(() => _obscureNewPass = !_obscureNewPass),
            validator: (val) {
              if (val == null || val.length < 8) return "Must be at least 8 characters";
              return null;
            },
          ),
          const SizedBox(height: 15),

          // Confirm Password Field
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: "Confirm Password",
            obscure: _obscureConfirmPass,
            onToggleObscure: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
            validator: (val) {
              if (val != _newPasswordController.text) return "Passwords do not match";
              return null;
            },
          ),
          const SizedBox(height: 25),

          _buildDialogButtons(
            primaryText: "Save",
            onPrimaryPressed: _saveNewPassword,
          ),
        ],
      ),
    );
  }

  // --- HELPER FOR PASSWORD INPUTS ---
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: Colors.redAccent),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }

  // --- HELPER FOR BOTTOM BUTTONS ---
  Widget _buildDialogButtons({required String primaryText, required VoidCallback? onPrimaryPressed}) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white38, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: _isLoading ? null : onPrimaryPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: onPrimaryPressed == null ? Colors.grey : const Color(0xff00E5FF),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xff040F31), strokeWidth: 2))
                : Text(primaryText, style: const TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}