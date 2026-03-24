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
import 'package:temanu/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  Uint8List? _profileImageBytes; 

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
      backgroundColor: AppTheme.background, 
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
            color: AppTheme.secondaryColor,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
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
                            color: AppTheme.primaryColor, 
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.cardBackground,
                            backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                            child: _profileImageBytes == null ? const Icon(Icons.person, size: 50, color: AppTheme.textPrimary) : null,
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

                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWideScreen = MediaQuery.of(context).size.width > 800;

                      Widget profileSecurityBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Profile & Security",
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Column(
                                children: [
                                  _buildSettingsTile(
                                    icon: Icons.person_outline, 
                                    title: "Profile Information", 
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const ProfileInformationPage()),
                                      );
                                      _loadProfileData(); 
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
                        ],
                      );

                      Widget accountManagementBlock = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Account Management",
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
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
                                      actionColor: Colors.redAccent,
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
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                                          );

                                          bool success = await ApiService.deleteAccount();

                                          if (context.mounted) Navigator.pop(context);

                                          if (success) {
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
                                          } else {
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
                        ],
                      );

                      if (isWideScreen) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: profileSecurityBlock),
                            const SizedBox(width: 30),
                            Expanded(child: accountManagementBlock),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            profileSecurityBlock,
                            const SizedBox(height: 30),
                            accountManagementBlock,
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
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
    Color iconColor = AppTheme.primaryColor,
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
                // --- THE FIX: Prevents the dialog from stretching on wide screens ---
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.8), 
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5), 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isConnected ? Icons.sync : Icons.watch, color: AppTheme.primaryColor, size: 40),
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
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isConnected ? "Sync Now" : "Connect",
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
                // --- THE FIX: Prevents the dialog from stretching on wide screens ---
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.8), 
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