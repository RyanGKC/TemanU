import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:temanu/assistantpage.dart';
import 'package:temanu/mealInfo.dart';

class TrackMealCameraPage extends StatefulWidget {
  const TrackMealCameraPage({super.key});

  @override
  State<TrackMealCameraPage> createState() => _TrackMealCameraPageState();
}

class _TrackMealCameraPageState extends State<TrackMealCameraPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    // Observe app lifecycle to pause/resume camera
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // Safely initialize the device's camera
  Future<void> _initializeCamera() async {
    try {
      // Fetch available cameras on the device
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("No cameras available");
        return;
      }

      // Use the first available camera (usually the back camera)
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false, // We only need photos for meals
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  // Handle camera background/foreground states to prevent crashes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) {
      return;
    }

    try {
      setState(() => _isCapturing = true);
      
      // Capture the image
      final XFile image = await _cameraController!.takePicture();
      
      setState(() => _isCapturing = false);
      
      print("Picture saved to: ${image.path}");
      
      // TODO: Navigate to an "Analyze Meal" or "Confirm Meal" screen here, passing the image.path
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MealInfo(imagePath: image.path))
        );
      }

    } catch (e) {
      print("Error capturing picture: $e");
      setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31), // Match your app background
      extendBodyBehindAppBar: true, // Let the camera preview slide under the app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan Meal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          )
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.white.withValues(alpha: 0.1),
            )
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. CAMERA PREVIEW
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 110, left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xff1A3F6B),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff00E5FF).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff00E5FF),
                        ),
                      ),
              ),
            ),
          ),

          // 2. BOTTOM CONTROLS (Shutter Button)
          Container(
            padding: const EdgeInsets.only(bottom: 50, top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom Shutter Button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff00E5FF), // Cyan outer ring
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white, // Inner button
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}