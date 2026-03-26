import 'dart:ui';
import 'dart:convert';           // Image Base64 Encoding
import 'dart:typed_data';        // Byte data handling
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:image_picker/image_picker.dart'; // Image Picker
import 'package:temanu/api_service.dart'; 
import 'package:temanu/patientData.dart';
import 'package:temanu/theme.dart';

class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({super.key});

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  bool _isEditing = false;
  bool _isLoading = true; 
  
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _preferredNameController;
  late TextEditingController _usernameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String _gender = "Male";
  String _bloodType = "O+";
  DateTime _dateOfBirth = DateTime(1990, 5, 15);

  Uint8List? _profileImageBytes; 
  String? _base64Image;          

  final List<String> _availableConditions = [
    "Asthma", "Diabetes Type 1", "Diabetes Type 2", 
    "Hypertension", "High Cholesterol", "Anemia", "Thyroid Disorder"
  ];
  // ignore: prefer_final_fields
  List<String> _selectedConditions = ["Asthma", "Hypertension"];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _preferredNameController = TextEditingController();
    _usernameController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    
    _loadProfileData(); 
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final serverProfile = await ApiService.getFullProfile();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        if (serverProfile != null) {
          _fullNameController.text = serverProfile['name'] ?? '';
          _preferredNameController.text = serverProfile['preferred_name'] ?? '';
          _usernameController.text = serverProfile['username'] ?? '';
          _gender = serverProfile['gender'] ?? 'Male';
          _bloodType = serverProfile['blood_type'] ?? 'O+';
          _heightController.text = serverProfile['height'] ?? prefs.getString('height') ?? '170';

          final dobStr = serverProfile['dob'] ?? '';
          try {
            final parts = dobStr.split('/');
            if (parts.length == 3) {
              _dateOfBirth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          } catch (_) {}

          prefs.setString('full_name', serverProfile['name'] ?? '');
          prefs.setString('user_name', serverProfile['preferred_name'] ?? '');
          prefs.setString('username', serverProfile['username'] ?? '');
          prefs.setString('gender', serverProfile['gender'] ?? '');
          prefs.setString('blood_type', serverProfile['blood_type'] ?? '');
          if (serverProfile['height'] != null) {
            prefs.setString('height', serverProfile['height']);
          }
        } else {
          _fullNameController.text = prefs.getString('full_name') ?? '';
          _preferredNameController.text = prefs.getString('user_name') ?? 'User';
          _usernameController.text = prefs.getString('username') ?? '';
          _heightController.text = prefs.getString('height') ?? '170';
          _gender = prefs.getString('gender') ?? 'Male';
          _bloodType = prefs.getString('blood_type') ?? 'O+';
          final dobStr = prefs.getString('dob') ?? '15/5/1990';
          try {
            final parts = dobStr.split('/');
            if (parts.length == 3) {
               _dateOfBirth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          } catch (_) {}
        }

        final latestWeight = prefs.getDouble('latest_weight') ??
            double.tryParse(prefs.getString('weight') ?? '70') ?? 70.0;
        _weightController.text = latestWeight.toStringAsFixed(1);

        _base64Image = prefs.getString('profile_image_base64');
        if (_base64Image != null && _base64Image!.isNotEmpty) {
          try {
            _profileImageBytes = base64Decode(_base64Image!);
          } catch (_) {}
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return; 
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 50, 
    ); 
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
        _base64Image = base64Encode(bytes); 
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _preferredNameController.dispose();
    _usernameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      if (_formKey.currentState!.validate()) {
        setState(() => _isLoading = true);
        
        final prefs = await SharedPreferences.getInstance();

        await ApiService.updateProfile(
          name: _fullNameController.text.trim(),
          preferredName: _preferredNameController.text.trim(),
          gender: _gender,
          dob: _formattedDob,
          bloodType: _bloodType,
          height: _heightController.text.trim(),
        );

        final newWeight = double.tryParse(_weightController.text) ?? 0.0;
        if (newWeight > 0) {
          await ApiService.saveHealthMetric(
            metricType: "Body Weight",
            value: _weightController.text,
            unit: "kg",
          );
          await prefs.setDouble('latest_weight', newWeight);
        }

        await prefs.setString('height', _heightController.text.trim());
        await prefs.setString('user_name', _preferredNameController.text.trim());
        await prefs.setString('full_name', _fullNameController.text.trim());
        await prefs.setString('gender', _gender);
        await prefs.setString('dob', _formattedDob);
        await prefs.setString('blood_type', _bloodType);
        if (_base64Image != null) {
          await prefs.setString('profile_image_base64', _base64Image!);
        }

        if (mounted) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
          Navigator.pop(context, toPatientData());
        }
      }
    } else {
      setState(() => _isEditing = true);
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
              primary: AppTheme.primaryColor,
              onPrimary: AppTheme.textPrimary,
              surface: AppTheme.cardBackground,
              onSurface: AppTheme.textPrimary,
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

  PatientData toPatientData() {
    final dob = _dateOfBirth;
    final age = DateTime.now().year - dob.year;

    return PatientData(
      name: _preferredNameController.text,
      dob: "${dob.day} ${_monthName(dob.month)} ${dob.year}",
      age: age.toString(),
      gender: _gender,
      height: _heightController.text,
      weight: _weightController.text,
      bloodType: _bloodType,
      conditions: _selectedConditions.isEmpty ? 'None' : _selectedConditions.join(', '),
    );
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        title: const Text(
          'Profile Info',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: AppTheme.background.withOpacity(0.5)),
          ),
        ),
        actions: [
          if (!_isLoading) 
            TextButton(
              onPressed: _toggleEdit,
              child: Text(
                _isEditing ? "Save" : "Edit",
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              // Wrap the main content to prevent it getting TOO massive on ultra-wide screens
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // --- PROFILE PICTURE SECTION ---
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage, 
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppTheme.cardBackground,
                                backgroundImage: _profileImageBytes != null 
                                  ? MemoryImage(_profileImageBytes!) 
                                  : null,
                                child: _profileImageBytes == null 
                                  ? const Icon(Icons.person, size: 50, color: AppTheme.textPrimary) 
                                  : null,
                              ),
                            ),
                            if (_isEditing)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: AppTheme.textPrimary, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- RESPONSIVE LAYOUT BUILDER ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWideScreen = MediaQuery.of(context).size.width > 800;

                        // BLOCK 1: Personal Details
                        Widget personalDetailsBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Personal Details"),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
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
                                  _buildTextField(
                                    "Username", 
                                    _usernameController,
                                    isReadOnly: true,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildDropdownField("Gender", ["Male", "Female", "Non-binary", "Prefer not to say"], _gender, (val) => setState(() => _gender = val!)),
                                  const SizedBox(height: 15),
                                  _buildDateField("Date of Birth", _formattedDob),
                                ],
                              ),
                            ),
                          ],
                        );

                        // BLOCK 2: Health & Metrics
                        Widget healthMetricsBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Health & Metrics"),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  
                                  const Text("Health Conditions", style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  const SizedBox(height: 10),
                                  
                                  if (_isEditing)
                                    GestureDetector(
                                      onTap: () => _showHealthConditionsBottomSheet(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.textSecondary.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
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
                                            const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
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
                                            backgroundColor: AppTheme.background,
                                            side: const BorderSide(color: AppTheme.primaryColor, width: 1),
                                          )).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );

                        // --- RENDER LOGIC ---
                        if (isWideScreen) {
                          // Display in two columns on wide screens
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: personalDetailsBlock),
                              const SizedBox(width: 30), // Gap between columns
                              Expanded(child: healthMetricsBlock),
                            ],
                          );
                        } else {
                          // Stack vertically on mobile
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              personalDetailsBlock,
                              const SizedBox(height: 30),
                              healthMetricsBlock,
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return "Required";
    final number = double.tryParse(value);
    if (number == null || number <= 0) return "Invalid";
    return null;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, String? Function(String?)? validator, bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          enabled: isReadOnly ? false : _isEditing,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(color: isReadOnly ? Colors.white54 : Colors.white, fontSize: 16),
          validator: validator,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
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
                dropdownColor: AppTheme.cardBackground,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
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
                if (_isEditing) const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showHealthConditionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableConditions.length,
                      itemBuilder: (context, index) {
                        final condition = _availableConditions[index];
                        final isSelected = _selectedConditions.contains(condition);

                        return CheckboxListTile(
                          title: Text(condition, style: const TextStyle(color: Colors.white)),
                          value: isSelected,
                          activeColor: AppTheme.primaryColor,
                          checkColor: AppTheme.textPrimary,
                          side: BorderSide(color: Colors.white.withOpacity(0.5)),
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                _selectedConditions.add(condition);
                              } else {
                                _selectedConditions.remove(condition);
                              }
                            });
                            setState(() {}); 
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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