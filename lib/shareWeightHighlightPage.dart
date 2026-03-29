import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:temanu/theme.dart';

enum WeightHighlight { change, bmi, goal }

class ShareWeightHighlightPage extends StatefulWidget {
  final double currentWeight;
  final double changeValue;
  final double bmi;
  final double? goalWeight;
  final String rangeName;
  final String dateRangeLabel;
  final String userName;

  const ShareWeightHighlightPage({
    super.key,
    required this.currentWeight,
    required this.changeValue,
    required this.bmi,
    required this.goalWeight,
    required this.rangeName,
    required this.dateRangeLabel,
    required this.userName,
  });

  @override
  State<ShareWeightHighlightPage> createState() => _ShareWeightHighlightPageState();
}

class _ShareWeightHighlightPageState extends State<ShareWeightHighlightPage> {
  final _screenshotController = ScreenshotController();
  WeightHighlight _selectedHighlight = WeightHighlight.change;

  Future<Uint8List?> _captureImage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
    );

    try {
      // --- THE FIX: Force a high-res pixel density regardless of screen ---
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      
      if (mounted) Navigator.pop(context); // Dismiss loading
      return imageBytes;
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      _showSnackBar("Failed to capture image.", isError: true);
      return null;
    }
  }

  void _shareImage() async {
    if (kIsWeb) {
      _showSnackBar("Sharing is only supported on the mobile app.");
      return;
    }

    final bytes = await _captureImage();
    if (bytes == null) return;

    try {
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/Weight_Progress.png').writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(imagePath.path)],
          text: "Here's my weight progress from Temanu!",
        )
      );
    } catch (e) {
      _showSnackBar("Failed to share image.", isError: true);
    }
  }

  void _saveImage() async {
    final bytes = await _captureImage();
    if (bytes == null) return;

    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'Weight_Progress', 
          bytes: bytes, 
          ext: 'png', 
          mimeType: MimeType.png
        );
        _showSnackBar("Image downloaded successfully!");
      } else {
        final String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Progress Image', 
          fileName: 'Weight_Progress.png', 
          type: FileType.custom, 
          allowedExtensions: ['png']
        );
        
        if (outputPath != null) {
          await File(outputPath).writeAsBytes(bytes);
          if (mounted) _showSnackBar("Image saved successfully!");
        }
      }
    } catch (e) {
      _showSnackBar("Failed to save image.", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xff00E676),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Share Progress", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              // --- THE FIX: FittedBox shrinks the UI so it doesn't break small screens ---
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Screenshot(
                  controller: _screenshotController,
                  child: _buildShareableCard(),
                ),
              ),
            ),
            const SizedBox(height: 40),

            const Text(
              "Choose Highlight",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                _buildFilterChip("Weight Change", WeightHighlight.change),
                _buildFilterChip("Current BMI", WeightHighlight.bmi),
                _buildFilterChip("Goal Progress", WeightHighlight.goal),
              ],
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt, size: 20),
                    label: const Text("Save"),
                    onPressed: _saveImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.ios_share, size: 20),
                    label: const Text("Share"),
                    onPressed: _shareImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: const Color(0xff031447),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, WeightHighlight highlight) {
    final isSelected = _selectedHighlight == highlight;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedHighlight = highlight);
      },
      backgroundColor: AppTheme.cardBackground,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildShareableCard() {
    String title;
    String value;
    String subtitle;

    switch (_selectedHighlight) {
      case WeightHighlight.change:
        title = "Weight Change";
        value = "${widget.changeValue > 0 ? '+' : ''}${widget.changeValue.toStringAsFixed(1)} kg";
        subtitle = "In the last ${widget.rangeName.toLowerCase()}";
        break;
      case WeightHighlight.bmi:
        title = "Current BMI";
        value = widget.bmi.toStringAsFixed(1);
        subtitle = "Based on ${widget.currentWeight.toStringAsFixed(1)} kg";
        break;
      case WeightHighlight.goal:
        title = "Progress to Goal";
        if (widget.goalWeight == null) {
          value = "No goal set";
          subtitle = "Set a goal to track progress";
        } else {
          final diff = widget.currentWeight - widget.goalWeight!;
          value = "${diff.abs().toStringAsFixed(1)} kg";
          subtitle = diff > 0 ? "to go!" : "past your goal!";
        }
        break;
    }

    return Container(
      // --- THE FIX: Hardcoded fixed dimensions ---
      width: 400,
      height: 450,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: const Color(0xff040F31), 
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        // --- THE FIX: Uses MainAxisAlignment.spaceBetween to push the top, middle, and bottom rows perfectly apart ---
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.monitor_weight_outlined, color: AppTheme.primaryColor, size: 28),
              Text(
                widget.dateRangeLabel,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          
          // Middle Data
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 56, fontWeight: FontWeight.w800, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          
          // Bottom User Row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                child: Text(
                  widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "U",
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Tracked with Temanu",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}