import 'package:flutter/material.dart';
import 'package:temanu/api_service.dart'; // <-- IMPORT YOUR API SERVICE
import 'package:temanu/aboutyou.dart';
import 'package:temanu/button.dart';
import 'package:temanu/logindetails.dart';
import 'package:temanu/textbox.dart';

class RegisterDetails extends StatefulWidget {
  const RegisterDetails({super.key});

  @override
  State<RegisterDetails> createState() => _RegisterDetailsState();
}

class _RegisterDetailsState extends State<RegisterDetails> {
  // 1. Controllers to capture input
  final emailController = TextEditingController();
  final fullNameController = TextEditingController();
  final preferredNameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // 2. State variables
  bool _isPasswordVisible = false;
  bool _isLoading = false; // <-- NEW: Track loading state

  @override
  void dispose() {
    emailController.dispose();
    fullNameController.dispose();
    preferredNameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // <-- NEW: The function that handles registration and auto-login
  Future<void> _handleRegister() async {
    final email = emailController.text.trim();
    final name = fullNameController.text.trim();
    final preferredName = preferredNameController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    // 1. Basic validation
    if (email.isEmpty || name.isEmpty || preferredName.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    // 2. Start loading
    setState(() => _isLoading = true);

    // 3. Call the API to Register
    final result = await ApiService.register(
      email: email,
      name: name,
      preferredName: preferredName,
      username: username,
      password: password,
    );

    if (mounted) {
      if (result['success'] == true) {
        // 4. If registration worked, automatically log them in to get the JWT token!
        bool loginSuccess = await ApiService.login(username, password);

        setState(() => _isLoading = false);

        if (loginSuccess) {
          // Success! Send them to the About You page to finish onboarding
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AboutYou())
          );
        } else {
          // Fallback just in case auto-login fails
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created, but auto-login failed. Please log in.')),
          );
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const LoginDetails())
          );
        }
      } else {
        // Registration failed (e.g., username already taken)
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
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
                  children: [
                    const Text(
                      'Registration',
                      style: TextStyle(
                        fontSize: 25,
                        color: Colors.white,
                        fontWeight: FontWeight.w600
                      )
                    ),
                    const SizedBox(height: 30),
                    MyTextField(
                      controller: emailController,
                      hintText: 'Email'
                    ),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: fullNameController,
                      hintText: 'Full Name'
                    ),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: preferredNameController,
                      hintText: 'Preferred Name'
                    ),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: usernameController,
                      hintText: 'Username'
                    ),
                    const SizedBox(height: 15),
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible 
                            ? Icons.visibility 
                            : Icons.visibility_off,
                          color: Colors.grey
                        ), 
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      )
                    ),
                    const SizedBox(height: 15),
                    
                    // <-- NEW: Show spinner or Register button
                    _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : MyRoundedButton(
                          text: 'Register', 
                          backgroundColor: const Color(0xff3183BE), 
                          textColor: Colors.white, 
                          onPressed: _handleRegister, // <-- Attach the function here
                        ),

                    const SizedBox(height: 15),
                    Row(
                      children: const [
                        Expanded(
                          child: Divider(
                            color: Colors.white,
                            thickness: 1
                          )
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14
                            )
                          )
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white,
                            thickness: 1,
                          )
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    MyRoundedButton(
                      text: 'Login', 
                      backgroundColor: Colors.white, 
                      textColor: const Color(0xff3183BE), 
                      onPressed: () {
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(builder: (context) => const LoginDetails())
                        );
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