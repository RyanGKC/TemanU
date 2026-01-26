import 'package:flutter/material.dart';

class MyRoundedButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;
  final double? buttonWidth; // Changed to nullable

  const MyRoundedButton({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
    this.buttonWidth, // Removed default 250 value
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // If no width is passed, use double.infinity to fill the parent (like a TextField)
      width: buttonWidth ?? double.infinity, 
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 20), // Matches text field height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Matches text field border radius
          ),
          elevation: 0, // Optional: Removes shadow to match flat text field look
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}