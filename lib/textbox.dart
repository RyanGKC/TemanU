import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon; // Optional, for the eye icon

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.obscureText = false, // Default to showing text
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Color(0xff3183BE), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon == null ? null :
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Icon(prefixIcon, color: Colors.grey[600])
        ),
        suffixIcon: suffixIcon == null ? null : 
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: suffixIcon
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), 
          borderSide: const BorderSide(color: Color(0xff3183BE), width: 2),
        ),
      ),
    );
  }
}