import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart'; 
import 'package:temanu/button.dart';
import 'package:temanu/mainscreen.dart';
import 'package:temanu/theme.dart';

class AboutYou extends StatefulWidget {
  final String email;
  final String name;
  final String preferredName;
  final String username;
  final String password;
  final String otpCode; // Catching the verified code from the first screen!

  const AboutYou({
    super.key, 
    required this.email, 
    required this.name, 
    required this.preferredName, 
    required this.username, 
    required this.password,
    required this.otpCode,
  });

  @override
  State<AboutYou> createState() => AboutYouState();
}

class AboutYouState extends State<AboutYou> {
  String? selectedGender;
  final List<String> genderOptions = ['Male', 'Female'];
  DateTime? selectedDate;
  
  final dateOfBirthcontroller = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final bloodTypeController = TextEditingController();

  bool _isLoading = false; 

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked; 
        dateOfBirthcontroller.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // --- Submit everything to the Backend ---
  Future<void> _submitData() async {
    // Note: Blood Type is NO LONGER mandatory here!
    if (selectedGender == null || 
        dateOfBirthcontroller.text.isEmpty || 
        heightController.text.isEmpty || 
        weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all mandatory fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.register(
      email: widget.email,
      name: widget.name,
      preferredName: widget.preferredName,
      username: widget.username,
      password: widget.password,
      gender: selectedGender!,
      dob: dateOfBirthcontroller.text,
      // If blood type is empty, default to "Unknown"
      bloodType: bloodTypeController.text.isEmpty ? "Unknown" : bloodTypeController.text,
      otpCode: widget.otpCode, // Send the verified code to the backend!
    );

    if (mounted) {
      if (result['success'] == true) {
        // Success! Log them in
        bool loginSuccess = await ApiService.login(widget.username, widget.password);

        if (loginSuccess) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('gender', selectedGender!);
          await prefs.setString('dob', dateOfBirthcontroller.text);
          await prefs.setString('height', heightController.text);
          await prefs.setString('weight', weightController.text);
          await prefs.setDouble('latest_weight', double.parse(weightController.text));
          await prefs.setString('blood_type', bloodTypeController.text.isEmpty ? "Unknown" : bloodTypeController.text);

          await ApiService.saveHealthMetric(metricType: "Height", value: heightController.text, unit: "cm");
          await ApiService.saveHealthMetric(metricType: "Body Weight", value: weightController.text, unit: "kg");

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (Route<dynamic> route) => false, 
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created, but login failed. Please try logging in manually.')),
          );
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Registration failed')),
        );
      }
    }
  }

  @override
  void dispose() {
    dateOfBirthcontroller.dispose();
    heightController.dispose();
    weightController.dispose();
    bloodTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: AppTheme.background,
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const Text('About You', style: TextStyle(fontSize: 25, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 30),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      dropdownColor: AppTheme.cardBackground,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Gender'),
                      onChanged: (String? newValue) => setState(() => selectedGender = newValue),
                      items: genderOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: dateOfBirthcontroller,
                      readOnly: true,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      onTap: () => _selectDate(context),
                      decoration: const InputDecoration(labelText: 'Date Of Birth'),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Height (cm)'),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      dropdownColor: AppTheme.cardBackground,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Blood Type (Optional)'),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                          .toList(),
                      onChanged: (value) => setState(() => bloodTypeController.text = value!),
                    ),
                    const SizedBox(height: 25),
                    
                    _isLoading
                      ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                      : MyRoundedButton(
                          text: 'Complete Registration', 
                          backgroundColor: AppTheme.primaryColor, 
                          textColor: AppTheme.textPrimary, 
                          onPressed: _submitData, 
                        ),
                  ],
                )
              )
            )
          ),
          Positioned(
            bottom: 20, 
            left: 20,   
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new),
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.black26, padding: const EdgeInsets.all(12)),
            ),
          ),
        ],
      )
    );
  }
}