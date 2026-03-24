import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      // Color comes from the theme
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null :
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Icon(prefixIcon)
        ),
        suffixIcon: suffixIcon == null ? null : 
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: suffixIcon
        ),
        // Relies on global InputDecorationTheme for borders/colors
      ),
    );
  }
}