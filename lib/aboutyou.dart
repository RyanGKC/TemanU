import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:temanu/api_service.dart'; 
import 'package:temanu/button.dart';
import 'package:temanu/mainscreen.dart';

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
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/desktop-background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const Text('About You', style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 30),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      hint: const Text('Gender', style: TextStyle(color: Color(0xff3183BE), fontWeight: FontWeight.w500)),
                      decoration: myInput('Gender'),
                      onChanged: (String? newValue) => setState(() => selectedGender = newValue),
                      items: genderOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w200)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: dateOfBirthcontroller,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: myInput('Date Of Birth'),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: myInput('Height (cm)'),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                      decoration: myInput('Weight (kg)'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      hint: const Text('Blood Type (Optional)', style: TextStyle(color: Color(0xff3183BE), fontWeight: FontWeight.w500)),
                      decoration: myInput('Blood Type (Optional)'),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((label) => DropdownMenuItem(value: label, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w200))))
                          .toList(),
                      onChanged: (value) => setState(() => bloodTypeController.text = value!),
                    ),
                    const SizedBox(height: 25),
                    
                    _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : MyRoundedButton(
                          text: 'Complete Registration', 
                          backgroundColor: const Color(0xff3183BE), 
                          textColor: Colors.white, 
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

InputDecoration myInput (String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xff3183BE), fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xff3183BE), width: 2)),
  );
}