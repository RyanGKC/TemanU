import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/changePassword.dart';
import 'package:temanu/profileInformation.dart';

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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ProfileInformationPage()),
                          );
                        }
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.lock_outline, 
                        title: "Change Password", 
                        onTap: () {
                          showDialog(
                            context: context, 
                            barrierColor: Colors.black.withValues(alpha: 0.6),
                            builder: (context) => const ChangePasswordDialog(),
                          );
                        }
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
                          // TRIGGERS THE LOG OUT DIALOG
                          _showConfirmationDialog(
                            context,
                            title: "Log Out",
                            content: "Are you sure you want to log out of your account? You will need to sign back in to view your health data.",
                            actionText: "Log Out",
                            actionColor: const Color.fromARGB(168, 0, 229, 255),
                            onConfirm: () {
                              print("User officially logged out!");
                              // Add your actual logout navigation logic here
                            },
                          );
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
                          // TRIGGERS THE DELETE ACCOUNT DIALOG
                          _showConfirmationDialog(
                            context,
                            title: "Delete Account",
                            content: "This action cannot be undone. All of your saved health data, medication logs, and settings will be permanently erased.",
                            actionText: "Delete",
                            actionColor: Colors.redAccent, // Red for destructive actions!
                            onConfirm: () {
                              print("User officially deleted account!");
                              // Add your actual delete logic here
                            },
                          );
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

// WIDGET: Sleek, Glassmorphism Confirmation Dialog
  void _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String actionText,
    required Color actionColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6), // Darkens the background smoothly
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, // Makes the default white box invisible
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B).withValues(alpha: 0.8), // Semi-transparent dark blue
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), // Glass edge
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrinks the dialog to exactly fit the text
                  children: [
                    Icon(Icons.warning_amber_rounded, color: actionColor, size: 45),
                    const SizedBox(height: 15),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        // CANCEL BUTTON
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context), // Closes the dialog
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white38, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        // ACTION BUTTON (Log Out / Delete)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // Close the dialog first
                              onConfirm(); // Then run the actual action
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: actionColor,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                actionText,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
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
  }