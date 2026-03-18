import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/api_service.dart'; // Make sure this path is correct

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  int _step = 1; // 1 = Request OTP, 2 = Verify OTP & Change
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOTP() async {
    setState(() => _isLoading = true);

    final result = await ApiService.requestChangePasswordOTP();

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Move to Step 2!
        setState(() => _step = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An OTP has been sent to your email!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleVerifyAndChange() async {
    final code = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (code.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP and your new password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyChangePassword(
      code: code,
      newPassword: newPassword,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xff1A3F6B).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: _step == 1 ? _buildStep1Request() : _buildStep2Verify(),
          ),
        ),
      ),
    );
  }

  // --- STEP 1: REQUEST THE OTP ---
  Widget _buildStep1Request() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xff00E5FF).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.security, color: Color(0xff00E5FF), size: 40),
        ),
        const SizedBox(height: 15),
        const Text(
          "Secure Password Change",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "To protect your account, we need to verify your identity. Click below to send a 6-digit one-time password (OTP) to your registered email address.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _handleRequestOTP,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xff00E5FF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xff040F31), strokeWidth: 2))
                      : const Text("Send OTP", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 2: VERIFY AND UPDATE ---
  Widget _buildStep2Verify() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read, color: Color(0xff00E5FF), size: 40),
        const SizedBox(height: 15),
        const Text(
          "Check Your Email",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        
        // OTP Field
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white, letterSpacing: 5, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: "",
            hintText: "Enter 6-digit OTP",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0, fontSize: 16),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 15),

        // New Password Field
        TextField(
          controller: _newPasswordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "New Password",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
        
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _handleVerifyAndChange,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xff00E5FF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xff040F31), strokeWidth: 2))
                      : const Text("Update", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}