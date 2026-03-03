import 'dart:ui';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31), // Match app background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF),
          )
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.white.withValues(alpha: 0.25),
            )
          ),
        ),
      ),
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              
              // 1. PROFILE HEADER
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xff00E5FF), // Cyan border ring
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xff1A3F6B),
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                        // backgroundImage: AssetImage('assets/profile_pic.png'), // Uncomment to add an actual image
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "James",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "james@example.com",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 2. PROFILE & SECURITY
              const Text(
                "Profile & Security",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B),
                  borderRadius: BorderRadius.circular(20),
                ),
                // ADDED: ClipRRect forces the tap ripples to respect the rounded corners!
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.person_outline, 
                        title: "Profile Information", 
                        onTap: () {}
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.lock_outline, 
                        title: "Change Password", 
                        onTap: () {}
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.devices, 
                        title: "Linked Devices", 
                        onTap: () {}
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 3. DANGER ZONE
              const Text(
                "Account Managment",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.logout, 
                      title: "Log Out", 
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      hideArrow: true,
                      onTap: () {
                        // Log out logic here
                      }
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.delete_forever, 
                      title: "Delete Account", 
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      hideArrow: true,
                      onTap: () {
                        // Delete account logic here
                      }
                    ),
                  ],
                ),
              ),

              // Extra padding to ensure it scrolls above the floating navigation bar
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color iconColor = const Color(0xff00E5FF),
    bool hideArrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      // HitTestBehavior.opaque ensures the tap registers even if you click the empty space between the text and arrow!
      behavior: HitTestBehavior.opaque, 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1), // Soft glow behind the icon
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (!hideArrow)
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  // WIDGET: Subtle divider line between settings items
  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
      indent: 65, // Aligns the line with the text, not the icon
      endIndent: 20,
    );
  }
}