import 'package:flutter/material.dart';
import 'package:temanu/button.dart';
import 'package:temanu/logindetails.dart';
import 'package:temanu/registerdetails.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/desktop-background.png'),
                fit: BoxFit.cover,
              ),
            )
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('assets/img/TemanU-logo.png'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'TemanU',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                      )
                    ),
                    const SizedBox(height: 30),
                    MyRoundedButton(
                      text: 'Login',
                      backgroundColor: const Color(0xff3183BE),
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(builder: (context) => const LoginDetails())
                        );
                      },
                    ),
                    SizedBox(height: 20),
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
                )
              )
            )
          )
        ],
      )
    );
  }
}