import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:temanu/mealInfo.dart';
import 'package:image_picker/image_picker.dart';
import 'package:temanu/theme.dart'; // <-- ADDED THEME IMPORT

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
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("No cameras available");
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false, 
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
      
      final XFile image = await _cameraController!.takePicture();
      
      setState(() => _isCapturing = false);
      
      print("Picture saved to: ${image.path}");
      
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MealInfo(imageFile: image)) 
        );
        
        if (result != null && mounted) {
          Navigator.pop(context, result);
        }
      }

    } catch (e) {
      print("Error capturing picture: $e");
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MealInfo(imageFile: image)) 
      );
      
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // <-- APPLIED THEME
      extendBodyBehindAppBar: true, 
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
                color: AppTheme.cardBackground, // <-- APPLIED THEME
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2), // <-- APPLIED THEME
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
                          color: AppTheme.primaryColor, // <-- APPLIED THEME
                        ),
                      ),
              ),
            ),
          ),

          // 2. BOTTOM CONTROLS (Shutter & Gallery)
          Container(
            padding: const EdgeInsets.only(bottom: 50, top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 60), 
                
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor, // <-- APPLIED THEME
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white, 
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
                
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  color: Colors.white,
                  iconSize: 32,
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}