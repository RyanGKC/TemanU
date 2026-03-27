import 'package:flutter/material.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/button.dart';
import 'package:temanu/forgotPassword.dart';
import 'package:temanu/mainscreen.dart';
import 'package:temanu/registerdetails.dart';
import 'package:temanu/textbox.dart';
import 'package:temanu/theme.dart';

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
  // Future<void> _handleDevLogin() async {
  //   setState(() => _isLoading = true);

  //   // Hardcoded credentials for your test account
  //   bool success = await ApiService.login('RyanG', '12345678');

  //   if (mounted) {
  //     setState(() => _isLoading = false);

  //     if (success) {
  //       Navigator.pushReplacement(
  //         context, 
  //         MaterialPageRoute(builder: (context) => const MainScreen())
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Dev login failed. Is the test account registered?')),
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Welcome Back!',
                    style: TextStyle(
                        fontSize: 28,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Username',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                MyTextField(
                  controller: usernameController,
                  hintText: 'Enter your username',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Password',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                MyTextField(
                  controller: passwordController,
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppTheme.textSecondary,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      )
                    ),
                  )
                ),

                const SizedBox(height: 40),
                
                // <-- NEW: Show a spinner if loading, otherwise show the Login button
                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : MyRoundedButton(
                      text: 'Login',
                      backgroundColor: AppTheme.primaryColor,
                      textColor: AppTheme.textPrimary,
                      onPressed: _handleLogin, // Trigger the API call here
                    ),
                // const SizedBox(height: 16),
                // Center(
                //   child: TextButton.icon(
                //     onPressed: _isLoading ? null : _handleDevLogin,
                //     icon: const Icon(Icons.bug_report, color: AppTheme.textSecondary, size: 18),
                //     label: const Text(
                //       'Dev Fast Login', 
                //       style: TextStyle(color: AppTheme.textSecondary)
                //     ),
                //   ),
                // ),
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.cardBackground, thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        'Don\'t have an account?',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.cardBackground, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 32),
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
            ),
          ),
        ),
      ),
    );
  }
}