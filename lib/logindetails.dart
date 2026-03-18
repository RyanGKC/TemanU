import 'package:flutter/material.dart';
import 'package:temanu/api_service.dart'; // <-- MAKE SURE TO IMPORT YOUR API SERVICE
import 'package:temanu/button.dart';
import 'package:temanu/forgotPassword.dart';
import 'package:temanu/mainscreen.dart';
import 'package:temanu/registerdetails.dart';
import 'package:temanu/textbox.dart';

class LoginDetails extends StatefulWidget {
  const LoginDetails({super.key});

  @override
  State<LoginDetails> createState() => _LoginDetailsState();
}

class _LoginDetailsState extends State<LoginDetails> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false; // <-- NEW: Track loading state

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6), 
      barrierDismissible: false, 
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  // <-- NEW: The function that talks to your backend
  Future<void> _handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    // 1. Basic validation
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both username and password.')),
      );
      return;
    }

    // 2. Start loading
    setState(() => _isLoading = true);

    // 3. Call the API
    bool success = await ApiService.login(username, password);

    // 4. Stop loading
    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        // Boom! JWT is securely saved, go to the dashboard
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const MainScreen())
        );
      } else {
        // Wrong password or user doesn't exist
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password.')),
        );
      }
    }
  }

  // A dedicated fast-path for developers
  Future<void> _handleDevLogin() async {
    setState(() => _isLoading = true);

    // Hardcoded credentials for your test account
    bool success = await ApiService.login('RyanG', 'Ryan8228');

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const MainScreen())
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dev login failed. Is the test account registered?')),
        );
      }
    }
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                          fontSize: 25,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 30),
                    MyTextField(
                      controller: usernameController,
                      hintText: 'Username',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          )
                        ),
                      )
                    ),

                    const SizedBox(height: 30),
                    
                    // <-- NEW: Show a spinner if loading, otherwise show the Login button
                    _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : MyRoundedButton(
                          text: 'Login',
                          backgroundColor: const Color(0xff3183BE),
                          textColor: Colors.white,
                          onPressed: _handleLogin, // Trigger the API call here
                        ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleDevLogin,
                      icon: const Icon(Icons.bug_report, color: Colors.white70, size: 18),
                      label: const Text(
                        'Dev Fast Login', 
                        style: TextStyle(color: Colors.white70)
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white, thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5.0),
                          child: Text(
                            'Don\'t have an account? ',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    MyRoundedButton(
                      text: 'Register',
                      backgroundColor: Colors.white,
                      textColor: const Color(0xff3183BE),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(builder: (context) => const RegisterDetails())
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}