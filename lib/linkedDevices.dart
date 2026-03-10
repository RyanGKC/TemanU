import 'dart:ui';
import 'package:flutter/material.dart';

class LinkedDevices extends StatefulWidget {
  const LinkedDevices({super.key});

  @override
  State<LinkedDevices> createState() => _LinkedDevicesState();
}

class _LinkedDevicesState extends State<LinkedDevices> {
  // Mock data for currently connected integrations
  final List<Map<String, dynamic>> _connectedDevices = [
    {
      "name": "Apple Watch",
      "provider": "Apple HealthKit",
      "icon": Icons.watch,
      "color": Colors.white,
    }
  ];

  // Mock data for available integrations
  final List<Map<String, dynamic>> _availableDevices = [
    {
      "name": "Google Fit",
      "provider": "Android Health API",
      "icon": Icons.health_and_safety,
      "color": Colors.greenAccent,
    },
    {
      "name": "Garmin Device",
      "provider": "Garmin Connect API",
      "icon": Icons.watch_rounded,
      "color": Colors.blueAccent,
    },
    {
      "name": "Oura Ring",
      "provider": "Oura Cloud API",
      "icon": Icons.circle_outlined,
      "color": Colors.grey,
    },
  ];

  bool _isLoading = false;

  void _connectDevice(Map<String, dynamic> device) {
    setState(() => _isLoading = true);
    
    // Simulate API connection delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _availableDevices.remove(device);
        _connectedDevices.add(device);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully connected to ${device['provider']}!"),
          backgroundColor: const Color(0xff00E5FF),
        ),
      );
    });
  }

  void _disconnectDevice(Map<String, dynamic> device) {
    // Show a confirmation dialog before disconnecting
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
                    const Icon(Icons.link_off, color: Colors.redAccent, size: 45),
                    const SizedBox(height: 15),
                    const Text(
                      "Disconnect Device",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Are you sure you want to disconnect your ${device['name']}? We will stop syncing data from ${device['provider']}.",
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
                              child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // Close dialog
                              setState(() {
                                _connectedDevices.remove(device);
                                _availableDevices.add(device);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              alignment: Alignment.center,
                              child: const Text("Disconnect", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        // Explicit Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Linked Devices',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                // 1. CONNECTED DEVICES SECTION
                const Text(
                  "Connected",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                if (_connectedDevices.isEmpty)
                  _buildEmptyState("No devices currently connected.")
                else
                  ..._connectedDevices.map((device) => _buildDeviceCard(device, isConnected: true)),

                const SizedBox(height: 40),

                // 2. AVAILABLE DEVICES SECTION
                const Text(
                  "Available Integrations",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                if (_availableDevices.isEmpty)
                  _buildEmptyState("All available integrations are connected!")
                else
                  ..._availableDevices.map((device) => _buildDeviceCard(device, isConnected: false)),
                  
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xff00E5FF)),
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget for empty lists
  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white54, fontSize: 15),
        ),
      ),
    );
  }

  // Helper widget for individual device cards
  Widget _buildDeviceCard(Map<String, dynamic> device, {required bool isConnected}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? const Color(0xff00E5FF).withValues(alpha: 0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Device Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff040F31),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(device['icon'], color: device['color'], size: 28),
          ),
          const SizedBox(width: 15),
          
          // Device Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  device['provider'],
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Connect / Disconnect Button
          GestureDetector(
            onTap: () {
              if (isConnected) {
                _disconnectDevice(device);
              } else {
                _connectDevice(device);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isConnected ? Colors.transparent : const Color(0xff00E5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected ? Colors.redAccent.withValues(alpha: 0.5) : Colors.transparent,
                ),
              ),
              child: Text(
                isConnected ? "Remove" : "Connect",
                style: TextStyle(
                  color: isConnected ? Colors.redAccent : const Color(0xff040F31),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}