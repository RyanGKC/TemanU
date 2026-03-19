import 'dart:ui';
import 'dart:convert'; 
import 'dart:typed_data';      
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temanu/api_service.dart'; 
import 'package:temanu/changePassword.dart';
import 'package:temanu/profileInformation.dart';
import 'package:temanu/fitbitService.dart';
import 'package:temanu/logindetails.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  Uint8List? _profileImageBytes; // <-- NEW: Holds the profile picture

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? "User";
        _userEmail = prefs.getString('user_email') ?? "No email linked";
        
        // <-- NEW: Load the saved image -->
        final base64String = prefs.getString('profile_image_base64');
        if (base64String != null && base64String.isNotEmpty) {
          _profileImageBytes = base64Decode(base64String);
        }
      });
    }
  }

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
            child: Container(color: Colors.white.withValues(alpha: 0.25))
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
                      // <-- UPDATED: Display the image if it exists -->
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xff1A3F6B),
                        backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                        child: _profileImageBytes == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _userName, 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _userEmail, 
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
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
                        onTap: () async {
                          // <-- THE FIX: AWAIT the navigator, then reload! -->
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileInformationPage()),
                          );
                          _loadProfileData(); // Instantly updates when returning!
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
                        icon: Icons.sync, 
                        title: "Sync Fitbit Data", 
                        onTap: () async {
                          String? token = await FitbitService.getSilentToken();
                          bool isConnected = token != null;
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
                            
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear(); 
                            
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginDetails()),
                                (route) => false, 
                              );
                            }
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
                            content: "Are you absolutely sure? This action cannot be undone. All of your health data, settings, and profile information will be permanently erased.",
                            actionText: "Delete",
                            actionColor: Colors.redAccent,
                            onConfirm: () async {
                              // 1. Show a loading indicator (optional but good practice)
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                              );

                              // 2. Tell the server to nuke the account
                              bool success = await ApiService.deleteAccount();

                              // Pop the loading circle
                              if (context.mounted) Navigator.pop(context);

                              if (success) {
                                // 3. Disconnect third-party services
                                await FitbitService.logout();
                                
                                // 4. Wipe the local storage
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.clear(); 
                                
                                // 5. Kick them to the login screen and destroy the back button history
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginDetails()),
                                    (route) => false, 
                                  );
                                }
                              } else {
                                // Show an error if the server failed
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Failed to delete account. Please try again later.")),
                                  );
                                }
                              }
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
                              Navigator.pop(context);
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