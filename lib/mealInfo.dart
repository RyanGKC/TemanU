import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // <-- Official SDK
import 'package:image_picker/image_picker.dart';
class MealInfo extends StatefulWidget {
  final XFile imageFile; // <-- Changed from String imagePath

  const MealInfo({super.key, required this.imageFile});

  @override
  State<MealInfo> createState() => _MealInfoState();
}

class _MealInfoState extends State<MealInfo> {
  late TextEditingController _nameController;

  int? _calories;
  int? _protein;
  int? _carbs;
  int? _fats;
  String? _errorMessage;

  bool _isAnalyzing = true;
  bool _isSaving = false;

  // 🔑 Get API Key safely from .env
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: "");
    _analyzeMeal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _analyzeMeal() async {
    try {
      final model = GenerativeModel(
        // UPDATE THIS LINE to the newest Flash model
        model: 'gemini-2.5-flash', 
        apiKey: _geminiApiKey,
        generationConfig: GenerationConfig(temperature: 0.2),
      );

      // 2. USE XFILE TO READ BYTES (This works safely on Web, iOS, and Android!)
      final imageBytes = await widget.imageFile.readAsBytes();

      final prompt = '''Analyze this meal photo and estimate its nutritional content.
                      Respond ONLY with a valid JSON object (no markdown, no extra text) in this exact format:
                      {
                        "meal_name": "short descriptive name of the meal",
                        "calories": <integer>,
                        "protein_g": <integer>,
                        "carbs_g": <integer>,
                        "fats_g": <integer>
                      }
                      Base your estimates on typical portion sizes visible in the photo. If you cannot identify a meal, use 0 for all values and "Unknown Meal" as the name.''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes), 
        ])
      ];

      // 4. Send to Gemini
      final response = await model.generateContent(content);
      final rawText = response.text;

      if (rawText != null) {
        // 5. Strip markdown fences and parse
        final cleanText = rawText
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();

        final mealData = jsonDecode(cleanText);

        if (mounted) {
          setState(() {
            _nameController.text = mealData['meal_name'] ?? 'Unknown Meal';
            _calories = (mealData['calories'] as num).toInt();
            _protein = (mealData['protein_g'] as num).toInt();
            _carbs = (mealData['carbs_g'] as num).toInt();
            _fats = (mealData['fats_g'] as num).toInt();
            _isAnalyzing = false;
          });
        }
      } else {
        throw Exception("Gemini returned an empty response.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not analyze meal. Please try again.';
          _isAnalyzing = false;
        });
      }
      debugPrint('_analyzeMeal error: $e');
    }
  }

  void _confirmMeal() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a meal name"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSaving = false);
        
        final newMeal = {
          "name": _nameController.text,
          "calories": _calories,
          "protein": _protein,
          "carbs": _carbs,
          "fats": _fats,
        };
        
        // Pass the newMeal map back to the previous screen
        Navigator.pop(context, newMeal); 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Meal Details',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IMAGE PREVIEW
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xff00E5FF).withValues(alpha: 0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: kIsWeb
                              ? Image.network(widget.imageFile.path, fit: BoxFit.cover)
                              : Image.file(File(widget.imageFile.path), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ANALYSIS CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _isAnalyzing
                            ? _buildLoadingState()
                            : _errorMessage != null
                                ? _buildErrorState()
                                : _buildMealDetails(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // BOTTOM BUTTONS
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Retake",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: (_isSaving || _isAnalyzing) ? null : _confirmMeal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: (_isAnalyzing || _isSaving)
                              ? const Color(0xff00E5FF).withValues(alpha: 0.4)
                              : const Color(0xff00E5FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Color(0xff040F31), strokeWidth: 2),
                              )
                            : const Text(
                                "Confirm",
                                style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const CircularProgressIndicator(color: Color(0xff00E5FF)),
        const SizedBox(height: 16),
        Text("Analyzing your meal...",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
        const SizedBox(height: 6),
        Text("Estimating calories & macros",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
        const SizedBox(height: 12),
        Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            setState(() { _isAnalyzing = true; _errorMessage = null; });
            _analyzeMeal();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xff00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xff00E5FF)),
            ),
            child: const Text("Retry",
                style: TextStyle(color: Color(0xff00E5FF), fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildMealDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                minLines: 1,
                maxLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  hintText: "Enter meal name",
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff00E5FF), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xff00E5FF).withValues(alpha: 0.5)),
              ),
              child: Text(
                "${_calories ?? '--'} kcal",
                style: const TextStyle(color: Color(0xff00E5FF), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.auto_awesome, color: const Color(0xff00E5FF).withValues(alpha: 0.7), size: 12),
            const SizedBox(width: 4),
            Text(
              "Gemini AI estimated · tap name to edit",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMacroItem("Protein", _protein ?? 0, Colors.redAccent),
            _buildMacroItem("Carbs", _carbs ?? 0, Colors.orangeAccent),
            _buildMacroItem("Fats", _fats ?? 0, Colors.purpleAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, int amount, Color dotColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: dotColor, size: 10),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text("${amount}g",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}