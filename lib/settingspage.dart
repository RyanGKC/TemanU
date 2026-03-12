import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:temanu/changePassword.dart';
import 'package:temanu/profileInformation.dart';
import 'package:temanu/fitbitService.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
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
                        color: Color(0xff00E5FF), 
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xff1A3F6B),
                        child: Icon(Icons.person, size: 50, color: Colors.white),
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
                            MaterialPageRoute(builder: (context) => const ProfileInformationPage()),
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
                      // --- UPDATED: FITBIT MANUAL SYNC TILE ---
                      _buildSettingsTile(
                        icon: Icons.sync, 
                        title: "Sync Fitbit Data", 
                        onTap: () async {
                          // 1. Silently check if they are already connected
                          String? token = await FitbitService.getSilentToken();
                          bool isConnected = token != null;

                          // 2. Show the smart dialog based on their status
                          if (context.mounted) {
                            _showFitbitSyncDialog(context, isConnected);
                          }
                        }
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 3. DANGER ZONE
              const Text(
                "Account Management",
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
                          _showConfirmationDialog(
                            context,
                            title: "Log Out",
                            content: "Are you sure you want to log out of your account? You will need to sign back in to view your health data.",
                            actionText: "Log Out",
                            actionColor: const Color.fromARGB(168, 0, 229, 255),
                            onConfirm: () async {
                              await FitbitService.logout();
                              print("User officially logged out!");
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
                          _showConfirmationDialog(
                            context,
                            title: "Delete Account",
                            content: "This action cannot be undone. All of your saved health data, medication logs, and settings will be permanently erased.",
                            actionText: "Delete",
                            actionColor: Colors.redAccent, 
                            onConfirm: () async {
                              await FitbitService.logout();
                              print("User officially deleted account!");
                            },
                          );
                        }
                      ),
                  ],
                ),
              ),
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
      behavior: HitTestBehavior.opaque, 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1), 
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

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
      indent: 65, 
      endIndent: 20,
    );
  }

  // --- NEW: DEDICATED SMART FITBIT SYNC DIALOG ---
  void _showFitbitSyncDialog(BuildContext context, bool isConnected) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6), 
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B).withValues(alpha: 0.8), 
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isConnected ? Icons.sync : Icons.watch, color: const Color(0xff00E5FF), size: 40),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      isConnected ? "Fitbit Connected" : "Connect Fitbit",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isConnected 
                          ? "Your account is already linked. Would you like to pull the latest health data right now?" 
                          : "Your account is not linked yet. Connect to Fitbit to automatically track your health data.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context), 
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context); // Close the dialog
                              // Trigger the connection or sync
                              String? token = await FitbitService.getValidToken();
                              if (token != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Fitbit synchronized successfully!", style: TextStyle(color: Color(0xff040F31))), 
                                    backgroundColor: Color(0xff00E5FF)
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xff00E5FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isConnected ? "Sync Now" : "Connect",
                                style: const TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold),
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

  // STANDARD DESTRUCTIVE DIALOG
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
      barrierColor: Colors.black.withValues(alpha: 0.6), 
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B).withValues(alpha: 0.8), 
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context), 
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context); 
                              onConfirm(); 
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
}