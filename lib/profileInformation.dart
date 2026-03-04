import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({super.key});

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  bool _isEditing = false;
  
  // 1. ADDED: Form Key for validation
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _preferredNameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String _gender = "Male";
  String _bloodType = "O+";
  DateTime _dateOfBirth = DateTime(1990, 5, 15);

  // 2. ADDED: Master list of conditions and user's selected conditions
  final List<String> _availableConditions = [
    "Asthma", "Diabetes Type 1", "Diabetes Type 2", 
    "Hypertension", "High Cholesterol", "Anemia", "Thyroid Disorder"
  ];
  List<String> _selectedConditions = ["Asthma", "Hypertension"];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: "James Alexander Doe");
    _preferredNameController = TextEditingController(text: "James");
    _heightController = TextEditingController(text: "180");
    _weightController = TextEditingController(text: "75");
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _preferredNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      // 3. ADDED: Validation check before saving
      if (_formKey.currentState!.validate()) {
        setState(() {
          _isEditing = false;
        });
        print("Data is valid. Saving profile...");
        // TODO: Send data to backend here
      } else {
        // If validation fails, don't exit edit mode
        print("Validation failed.");
      }
    } else {
      setState(() {
        _isEditing = true;
      });
    }
  }

  String get _formattedDob => "${_dateOfBirth.day}/${_dateOfBirth.month}/${_dateOfBirth.year}";

  Future<void> _selectDate(BuildContext context) async {
    if (!_isEditing) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff00E5FF),
              onPrimary: Color(0xff040F31),
              surface: Color(0xff1A3F6B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() => _dateOfBirth = picked);
    }
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
          'Profile Info',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _toggleEdit,
            child: Text(
              _isEditing ? "Save" : "Edit",
              style: const TextStyle(color: Color(0xff00E5FF), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      // Wrapped the entire scrollable area in a Form
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PROFILE PICTURE
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xff00E5FF), shape: BoxShape.circle),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xff1A3F6B),
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                    ),
                    if (_isEditing)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xff00E5FF), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Color(0xff040F31), size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // PERSONAL DETAILS CARD
              _buildSectionHeader("Personal Details"),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      "Full Name", 
                      _fullNameController,
                      validator: (value) => value!.isEmpty ? "Full name is required" : null,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      "Preferred Name", 
                      _preferredNameController,
                      validator: (value) => value!.isEmpty ? "Preferred name is required" : null,
                    ),
                    const SizedBox(height: 15),
                    _buildDropdownField("Gender", ["Male", "Female", "Non-binary", "Prefer not to say"], _gender, (val) => setState(() => _gender = val!)),
                    const SizedBox(height: 15),
                    _buildDateField("Date of Birth", _formattedDob),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // HEALTH & METRICS CARD
              _buildSectionHeader("Health & Metrics"),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff1A3F6B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align to top for error text
                      children: [
                        Expanded(child: _buildTextField(
                          "Height (cm)", 
                          _heightController, 
                          isNumber: true,
                          validator: _validateNumber,
                        )),
                        const SizedBox(width: 15),
                        Expanded(child: _buildTextField(
                          "Weight (kg)", 
                          _weightController, 
                          isNumber: true,
                          validator: _validateNumber,
                        )),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildDropdownField("Blood Type", ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"], _bloodType, (val) => setState(() => _bloodType = val!)),
                    const SizedBox(height: 25),
                    
                    // HEALTH CONDITIONS MULTI-SELECT
                    const Text("Health Conditions", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 10),
                    
                    if (_isEditing)
                      GestureDetector(
                        onTap: () => _showHealthConditionsBottomSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xff00E5FF).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedConditions.isEmpty 
                                  ? "Select Conditions" 
                                  : "${_selectedConditions.length} Selected",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xff00E5FF)),
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedConditions.isEmpty 
                          ? [const Text("None reported", style: TextStyle(color: Colors.white, fontSize: 16))]
                          : _selectedConditions.map((condition) => Chip(
                              label: Text(condition, style: const TextStyle(color: Colors.white)),
                              backgroundColor: const Color(0xff040F31),
                              side: const BorderSide(color: Color(0xff00E5FF), width: 1),
                            )).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- VALIDATION HELPER ---
  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return "Required";
    final number = double.tryParse(value);
    if (number == null || number <= 0) return "Invalid";
    return null; // Passes validation
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ADDED: validator parameter
  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          enabled: _isEditing,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          validator: validator, // Triggered by _formKey
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xff00E5FF))),
            errorStyle: const TextStyle(color: Colors.redAccent),
            errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> items, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 5),
        _isEditing
            ? DropdownButtonFormField<String>(
                initialValue: value,
                dropdownColor: const Color(0xff1A3F6B),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xff00E5FF))),
                ),
                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
      ],
    );
  }

  Widget _buildDateField(String label, String value) {
    // ... [Same as previous implementation] ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _isEditing ? Colors.white24 : Colors.transparent)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
                if (_isEditing) const Icon(Icons.calendar_today, color: Color(0xff00E5FF), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. MULTI-SELECT BOTTOM SHEET ---
  void _showHealthConditionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparent so we can apply our own styling
      isScrollControlled: true, // Allows sheet to take up more screen space if needed
      builder: (BuildContext context) {
        // StatefulBuilder allows the bottom sheet to rebuild its checkboxes without rebuilding the whole page
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6, // Take up 60% of screen
              decoration: const BoxDecoration(
                color: Color(0xff1A3F6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Bottom sheet drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 15, bottom: 10),
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text(
                      "Select Health Conditions",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  
                  // Scrollable list of checkboxes
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableConditions.length,
                      itemBuilder: (context, index) {
                        final condition = _availableConditions[index];
                        final isSelected = _selectedConditions.contains(condition);

                        return CheckboxListTile(
                          title: Text(condition, style: const TextStyle(color: Colors.white)),
                          value: isSelected,
                          activeColor: const Color(0xff00E5FF),
                          checkColor: const Color(0xff040F31), // Dark checkmark
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                _selectedConditions.add(condition);
                              } else {
                                _selectedConditions.remove(condition);
                              }
                            });
                            // We also need to update the main page's state so the UI reflects changes when we close the sheet
                            setState(() {}); 
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Done Button
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff00E5FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}