import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:temanu/aboutyou.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/button.dart';
import 'package:temanu/logindetails.dart';
import 'package:temanu/textbox.dart';

class RegisterDetails extends StatefulWidget {
  const RegisterDetails({super.key});

  @override
  State<RegisterDetails> createState() => _RegisterDetailsState();
}

class _RegisterDetailsState extends State<RegisterDetails> {
  final emailController = TextEditingController();
  final fullNameController = TextEditingController();
  final preferredNameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isRequestingOtp = false;
  bool _isVerifying = false;

  // --- NEW: Password Requirement States ---
  bool _hasLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    // Listen to every keystroke in the password field
    passwordController.addListener(_validatePassword);
  }

  // --- NEW: Dynamic Password Validator ---
  void _validatePassword() {
    final pass = passwordController.text;
    setState(() {
      _hasLength = pass.length >= 8;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasLowercase = pass.contains(RegExp(r'[a-z]'));
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
      _hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    passwordController.removeListener(_validatePassword);
    emailController.dispose();
    fullNameController.dispose();
    preferredNameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Request OTP ---
  Future<void> _handleRegister() async {
    final email = emailController.text.trim();
    final name = fullNameController.text.trim();
    final preferredName = preferredNameController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || name.isEmpty || preferredName.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all fields.')));
      return;
    }

    setState(() => _isRequestingOtp = true);

    final result = await ApiService.requestRegistrationOtp(email, username, password);

    if (mounted) {
      setState(() => _isRequestingOtp = false);
      
      if (result['success'] == true) {
        // Success! Show the OTP dialog
        _showOtpVerificationDialog(email, name, preferredName, username, password);
      } else {
        // Display the EXACT error message from the backend!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Registration failed. Please check your details.')),
        );
      }
    }
  }

  // --- Verify OTP Dialog ---
  void _showOtpVerificationDialog(String email, String name, String prefName, String user, String pass) {
    final otpController = TextEditingController();
    _isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false, 
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      color: const Color(0xff1A3F6B).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mark_email_read_outlined, color: Color(0xff00E5FF), size: 50),
                        const SizedBox(height: 15),
                        const Text(
                          "Verify Your Email",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "We sent a 6-digit code to\n$email",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 25),
                        
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            hintText: "000000",
                            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                            filled: true,
                            fillColor: const Color(0xff040F31).withValues(alpha: 0.4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _isVerifying ? null : () => Navigator.pop(context),
                                child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff00E5FF), elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _isVerifying ? null : () async {
                                  final code = otpController.text.trim();
                                  if (code.length != 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code must be 6 digits")));
                                    return;
                                  }

                                  setDialogState(() => _isVerifying = true);
                                  
                                  bool isValid = await ApiService.verifyRegistrationOtp(email, code);

                                  if (mounted) {
                                    if (isValid) {
                                      Navigator.pop(context); // Close Dialog
                                      
                                      // Push to Next Screen with the Code!
                                      Navigator.push(
                                        context, 
                                        MaterialPageRoute(
                                          builder: (context) => AboutYou(
                                            email: email, name: name, preferredName: prefName,
                                            username: user, password: pass, otpCode: code, 
                                          )
                                        )
                                      );
                                    } else {
                                      setDialogState(() => _isVerifying = false);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid or expired code.")));
                                    }
                                  }
                                },
                                child: _isVerifying 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xff040F31), strokeWidth: 2))
                                  : const Text("Verify", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
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
          },
        );
      },
    );
  }

  // --- NEW: Helper Widget for Checklist Rows ---
  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? const Color(0xff00E676) : Colors.white38,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.white : Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/desktop-background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const Text('Registration', style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 30),
                    MyTextField(controller: emailController, hintText: 'Email'),
                    const SizedBox(height: 15),
                    MyTextField(controller: fullNameController, hintText: 'Full Name'),
                    const SizedBox(height: 15),
                    MyTextField(controller: preferredNameController, hintText: 'Preferred Name'),
                    const SizedBox(height: 15),
                    MyTextField(controller: usernameController, hintText: 'Username'),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), 
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      )
                    ),
                    const SizedBox(height: 10),
                    
                    // --- NEW: Dynamic Password Checklist ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xff040F31).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Password Requirements:", 
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(height: 8),
                          _buildRequirementRow("At least 8 characters", _hasLength),
                          _buildRequirementRow("One uppercase letter (A-Z)", _hasUppercase),
                          _buildRequirementRow("One lowercase letter (a-z)", _hasLowercase),
                          _buildRequirementRow("One number (0-9)", _hasNumber),
                          _buildRequirementRow("One special symbol (!@#\$&*)", _hasSpecial),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _isRequestingOtp 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : MyRoundedButton(
                          text: 'Register', 
                          backgroundColor: const Color(0xff3183BE), 
                          textColor: Colors.white, 
                          onPressed: _handleRegister,
                        ),

                    const SizedBox(height: 15),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Colors.white, thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text('Already have an account?', style: TextStyle(color: Colors.white, fontSize: 14))
                        ),
                        Expanded(child: Divider(color: Colors.white, thickness: 1))
                      ],
                    ),
                    const SizedBox(height: 15),
                    MyRoundedButton(
                      text: 'Login', 
                      backgroundColor: Colors.white, 
                      textColor: const Color(0xff3183BE), 
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginDetails()));
                      }
                    )
                  ],
                )
              )
            ),
          ),
        ],
      ),
    );
  }
}