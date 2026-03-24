import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400), 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30), 
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
                  child: Container(
                    width: double.infinity, 
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground.withValues(alpha: 0.9), 
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2), width: 1.5), 
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(icon: Icons.home_filled, index: 0),
                        _buildNavItem(icon: Icons.settings, index: 1),       
                        _buildNavItem(icon: Icons.auto_awesome, index: 2),   
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    bool isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index), // Trigger the function passed from the parent
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary, 
        ),
      ),
    );
  }
}