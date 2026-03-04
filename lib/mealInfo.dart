import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MealInfo extends StatefulWidget {
  final String imagePath;

  const MealInfo({super.key, required this.imagePath});

  @override
  State<MealInfo> createState() => _MealInfoState();
}

class _MealInfoState extends State<MealInfo> {
  // 1. ADDED: Controller for the editable meal name
  late TextEditingController _nameController;

  // Mock data for the locked macros
  final int _calories = 450;
  final int _protein = 40;
  final int _carbs = 35;
  final int _fats = 12;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the AI's predicted name
    _nameController = TextEditingController(text: "Grilled Chicken & Veggie Bowl");
  }

  @override
  void dispose() {
    _nameController.dispose(); // Always dispose controllers!
    super.dispose();
  }

  void _confirmMeal() {
    // You can now access the edited name via _nameController.text
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a meal name"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    // Simulate a network save request
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).popUntil((route) => route.isFirst); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Meal tracked successfully!"),
            backgroundColor: Color(0xff00E5FF),
          ),
        );
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)
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
                      // 1. IMAGE PREVIEW
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
                            ? Image.network(
                                widget.imagePath, // On the web, the path is actually a network blob URL!
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                ),
                              )
                            : Image.file(
                                File(widget.imagePath), // On mobile, it's a real file path
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                ),
                              ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // 2. MEAL DESCRIPTION & MACROS CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Calories Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 2. CHANGED: Replaced Text with TextFormField for editing
                                Expanded(
                                  child: TextFormField(
                                    controller: _nameController,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    minLines: 1,
                                    maxLines: 2, 
                                    keyboardType: TextInputType.text,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                      hintText: "Enter meal name",
                                      hintStyle: const TextStyle(color: Colors.white38),
                                      // Shows a subtle line so users know it's an input field
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(20)
                                      ),
                                      // Highlights cyan when typing
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xff00E5FF), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                
                                // LOCKED CALORIES
                                Container(
                                  margin: const EdgeInsets.only(top: 5), // Aligns with the input text naturally
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xff00E5FF).withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    "$_calories kcal",
                                    style: const TextStyle(color: Color(0xff00E5FF), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 25),
                            Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                            const SizedBox(height: 20),

                            // LOCKED MACROS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMacroItem("Protein", _protein, Colors.redAccent),
                                _buildMacroItem("Carbs", _carbs, Colors.orangeAccent),
                                _buildMacroItem("Fats", _fats, Colors.purpleAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. BOTTOM BUTTONS (Retake & Confirm)
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
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
                      onTap: _isSaving ? null : _confirmMeal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xff00E5FF),
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

  Widget _buildMacroItem(String label, int amount, Color dotColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: dotColor, size: 10),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "${amount}g",
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}