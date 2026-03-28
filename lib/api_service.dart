import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> requestRegistrationOtp(String email, String username, String password) async {
    try {
      final url = Uri.parse('$_baseUrl/register/request-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        // Decode the FastAPI error and send it back to the UI
        final decoded = jsonDecode(response.body);
        return {'success': false, 'message': decoded['detail'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server. Please check your internet.'};
    }
  }

  static Future<bool> verifyRegistrationOtp(String email, String code) async {
    try {
      final url = Uri.parse('$_baseUrl/register/verify-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateProfile({
    String? name,
    String? preferredName,
    String? gender,
    String? dob,
    String? bloodType,
    String? height,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (preferredName != null) body['preferred_name'] = preferredName;
      if (gender != null) body['gender'] = gender;
      if (dob != null) body['dob'] = dob;
      if (bloodType != null) body['blood_type'] = bloodType;
      if (height != null) body['height'] = height;

      final response = await http.put(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getFullProfile() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me/full'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── AUTHENTICATION ───
  static Future<Map<String, dynamic>> register({
    required String email,
    required String name,
    required String preferredName,
    required String username,
    required String password,
    required String gender,
    required String dob,
    required String bloodType,
    required String otpCode, // <-- NEW
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'preferred_name': preferredName,
          'username': username,
          'password': password,
          'gender': gender,
          'dob': dob,
          'blood_type': bloodType,
          'otp_code': otpCode, // <-- NEW
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final decoded = jsonDecode(response.body);
        return {'success': false, 'message': decoded['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server. Please check your internet.'};
    }
  }

  static Future<bool> deleteAccount() async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Account deleted from server successfully.");
        return true;
      } else {
        print("❌ Failed to delete account. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error deleting account: $e");
      return false;
    }
  }
  
  /// Fitbit activity data
  static Future<Map<String, dynamic>?> getFitbitActivity(String date, {bool forceRefresh = false}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$date?force_refresh=$forceRefresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Fitbit API Failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Connection error: $e');
      return null;
    }
  }

  static Future<bool> removePersonalDoctor(String doctorId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/care-team/doctors/$doctorId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyAppointments() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/appointments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch the 7-day aggregated insights from Python
  static Future<List<dynamic>> getWeeklyInsights({bool forceRefresh = false}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/insights/weekly?force_refresh=$forceRefresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to fetch insights. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching insights: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getFitbitIntradaySteps(String date, {bool forceRefresh = false}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/steps/intraday/$date?force_refresh=$forceRefresh'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Fitbit API Failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error fetching intraday steps: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getFitbitTimeSeriesSteps(String period, String date, {bool forceRefresh = false}) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/steps/timeseries/$period/$date?force_refresh=$forceRefresh'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Fitbit TimeSeries API Failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error fetching timeseries steps: $e");
    }
    return null;
  }

  /// Step 1: Request the OTP to be sent to the user's email
  static Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        print("✅ OTP sent successfully to $email");
        return true;
      } else {
        print("❌ Failed to send OTP. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error requesting password reset: $e");
      return false;
    }
  }

  /// Step 2: Verify the OTP and save the new password
  static Future<bool> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Password reset successful!");
        return true;
      } else {
        print("❌ Failed to reset password. Server says: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error resetting password: $e");
      return false;
    }
  }

  // 1. Request the OTP (Requires the user's JWT Token)
  static Future<Map<String, dynamic>> requestChangePasswordOTP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$_baseUrl/change-password/request-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <-- Backend reads this to know who to email!
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP sent to your email'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      print("OTP Request Error: $e");
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // 2. Verify the OTP and save the new password
  static Future<Map<String, dynamic>> verifyChangePassword({
    required String code,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$_baseUrl/change-password/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
        body: jsonEncode({
          'code': code,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password changed successfully'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Invalid or expired OTP'};
      }
    } catch (e) {
      print("Verify Password Error: $e");
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }
  
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'), 
        headers: {'Content-Type': 'application/json'}, // <-- Must be JSON
        body: jsonEncode({                             // <-- Must be JSON Encoded
          'username': username,
          'password': password,
        }), 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        final newToken = data['access_token'];
        
        // 1. Save it to storage
        await prefs.setString('jwt_token', newToken);
        
        // 2. X-Ray to prove it saved
        print("✅ FLUTTER SAVED NEW TOKEN ENDING IN: ${newToken.toString().substring(newToken.toString().length - 10)}");
        
        // 3. Save the rest of the profile data
        await prefs.setString('user_name', data['name'] ?? 'User');
        await prefs.setString('user_email', data['email'] ?? '');
        await prefs.setString('full_name', data['full_name'] ?? '');
        await prefs.setString('username', data['username'] ?? '');
        
        return true;
      } else {
        print('Login Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  // Helper method to get the token for protected routes
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    // X-Ray to prove it grabbed the right one from storage
    if (token != null && token.length > 10) {
      print("🔍 STORAGE CHECK: Flutter pulled token ending in: ${token.substring(token.length - 10)}");
    }
    
    return token;
  }

  // ─── HEALTH METRICS ───

  static Future<bool> saveHealthMetric({
    required String metricType,
    required String value,
    required String unit,
  }) async {
    try {
      final token = await _getToken();
      
      if (token == null) return false;

      final Map<String, dynamic> payload = {};
      final parsedValue = double.tryParse(value);
      
      // --- THE FULLY MAPPED ADAPTER ---
      if (metricType == "Body Weight") {
        payload['body_weight'] = parsedValue;
      } else if (metricType == "Heart Rate") {
        payload['heart_rate'] = int.tryParse(value);
      } else if (metricType == "Blood Glucose") {
        payload['blood_glucose'] = parsedValue;
      } else if (metricType == "Oxygen Saturation") {
        payload['oxygen_saturation'] = parsedValue;
      } else if (metricType == "Calories") {
        payload['calories'] = int.tryParse(value);
      } else if (metricType == "Blood Pressure") {
        // Automatically split "120/80" into two database columns!
        final parts = value.split('/');
        if (parts.length == 2) {
          payload['blood_pressure_systolic'] = int.tryParse(parts[0].trim());
          payload['blood_pressure_diastolic'] = int.tryParse(parts[1].trim());
        } else {
          print("⚠️ Warning: Blood pressure format should be '120/80'");
        }
      }

      if (payload.isEmpty) {
        print("⚠️ Warning: Metric type '$metricType' not mapped. Skipping save.");
        return true; 
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print("📱 SERVER REJECTED HEALTH METRIC: ${response.body}");
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error saving $metricType: $e");
      return false;
    }
  }

  /// Fetches health metrics, optionally filtered by type (e.g., 'Body Weight')
  static Future<List<Map<String, dynamic>>> getHealthMetrics({String? metricType}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> rawData = jsonDecode(response.body);
        List<Map<String, dynamic>> translatedData = [];

        for (var row in rawData) {
          String timestamp = row['timestamp'] ?? '';

          if (row['body_weight'] != null) {
            translatedData.add({'metric_type': 'Body Weight', 'value': row['body_weight'].toString(), 'timestamp': timestamp});
          }
          if (row['heart_rate'] != null) {
            translatedData.add({'metric_type': 'Heart Rate', 'value': row['heart_rate'].toString(), 'timestamp': timestamp});
          }
          if (row['blood_glucose'] != null) {
            translatedData.add({'metric_type': 'Blood Glucose', 'value': row['blood_glucose'].toString(), 'timestamp': timestamp});
          }
          if (row['oxygen_saturation'] != null) {
            translatedData.add({'metric_type': 'Oxygen Saturation', 'value': row['oxygen_saturation'].toString(), 'timestamp': timestamp});
          }
          if (row['calories'] != null) {
            translatedData.add({'metric_type': 'Calories', 'value': row['calories'].toString(), 'timestamp': timestamp});
          }
          // Handle Blood Pressure (often displayed together)
          if (row['blood_pressure_systolic'] != null && row['blood_pressure_diastolic'] != null) {
            translatedData.add({
              'metric_type': 'Blood Pressure', 
              'value': '${row['blood_pressure_systolic']}/${row['blood_pressure_diastolic']}', 
              'timestamp': timestamp
            });
          }
        }

        // --- NEW: Filter the data if the UI asked for a specific metric! ---
        if (metricType != null) {
          return translatedData.where((metric) => metric['metric_type'] == metricType).toList();
        }

        return translatedData;
      } else {
        print("Failed to fetch metrics. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching metrics: $e");
      return [];
    }
  }

  // ─── ACTIVITY METRICS ───
  static Future<bool> saveActivity(int steps) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/activity'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'steps': steps,
          // Sending today's date formatted as YYYY-MM-DD
          'date': DateTime.now().toIso8601String().split('T')[0], 
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error saving activity: $e");
      return false;
    }
  }


  /// 1. Save a new meal to the database
  static Future<bool> saveMeal({
    required String name, 
    required int calories, 
    double protein = 0, 
    double carbs = 0, 
    double fats = 0
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/meals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fats': fats,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error saving meal: $e");
      return false;
    }
  }

  /// 2. Fetch all meals logged today
  static Future<List<dynamic>> getTodaysMeals() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/meals/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to fetch meals. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching meals: $e");
      return [];
    }
  }

  // --- MEDICATION APIS ---

  static Future<List<dynamic>> getMedications() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/medications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Error fetching meds: $e");
      return [];
    }
  }

  static Future<bool> addMedication(String name, String dosage, double inventory, String unit, List<String> times) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/medications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name, 
          'dosage': dosage, 
          'inventory': inventory,
          'unit': unit,
          'times': times, // Pass the list directly!
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> takeMedication(int medId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/medications/$medId/take'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteMedication(int medId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/medications/$medId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting medication: $e");
      return false;
    }
  }

  static Future<int> getMedicationAdherence() async {
    try {
      final token = await _getToken();
      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('$_baseUrl/medications/adherence'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['adherence_percentage'] ?? 0;
      }
      return 0;
    } catch (e) {
      print("Error fetching adherence: $e");
      return 0;
    }
  }

  static Future<bool> editMedication(int medId, String name, String dosage, double inventory, String unit, List<String> times) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$_baseUrl/medications/$medId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name, 'dosage': dosage, 'inventory': inventory,
          'unit': unit, 'times': times,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error editing medication: $e");
      return false;
    }
  }

  // ==========================================
  // DOCTORS & CARE TEAM API CALLS
  // ==========================================

  /// 1. Fetch Linked Doctors
  static Future<List<Map<String, dynamic>>> getLinkedDoctors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];

      final url = Uri.parse('$_baseUrl/care-team/doctors');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        print("Failed to load doctors: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching doctors: $e");
      return [];
    }
  }

  /// 2. Fetch Appointments
  static Future<List<Map<String, dynamic>>> getAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];

      final url = Uri.parse('$_baseUrl/care-team/appointments');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        print("Failed to load appointments: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching appointments: $e");
      return [];
    }
  }

  /// 3. Book a New Appointment
  static Future<bool> bookAppointment({
    required String doctorId,
    required DateTime appointmentTime,
    required String purpose,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final url = Uri.parse('$_baseUrl/care-team/appointments');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'doctor_id': doctorId,
          // FastAPI expects ISO 8601 string format for datetimes
          'appointment_time': appointmentTime.toIso8601String(), 
          'purpose': purpose,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Failed to book appointment: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error booking appointment: $e");
      return false;
    }
  }

  /// 4. Fetch Medical Records
  static Future<List<Map<String, dynamic>>> getMedicalRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];

      final url = Uri.parse('$_baseUrl/care-team/records');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        print("Failed to load records: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching records: $e");
      return [];
    }
  }

  /// 5. Save Medical Record Metadata
  static Future<bool> saveMedicalRecord({
    required String doctorId,
    required String fileName,
    required String recordType,
    required String fileUrl,
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final url = Uri.parse('$_baseUrl/care-team/records');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'doctor_id': doctorId,
          'file_name': fileName,
          'record_type': recordType,
          'file_url': fileUrl,
          if (description != null) 'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Failed to save record metadata: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error saving record metadata: $e");
      return false;
    }
  }

  // ─── CARE TEAM REQUESTS ───

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> approveRequest(int requestId, Map<String, bool> permissions) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse('$_baseUrl/care-team/requests/$requestId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'permissions': permissions}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> declineRequest(int requestId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse('$_baseUrl/care-team/requests/$requestId/decline'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── PERMISSIONS ───

  static Future<Map<String, dynamic>?> getPermissions(String doctorId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/permissions/$doctorId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updatePermissions(String doctorId, Map<String, bool> permissions) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final response = await http.put(
        Uri.parse('$_baseUrl/care-team/permissions/$doctorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(permissions),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 8. Chatbot

  static Future<String?> sendChatMessage(String message, List<Map<String, String>> history) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      } else {
        print("Chat failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Chat error: $e");
      return null;
    }
  }

  // ==========================================
  // AWS S3 SECURE FILE UPLOAD & DOWNLOAD
  // ==========================================

  /// 6. Get a secure Pre-signed URL to upload a file to AWS S3
  static Future<Map<String, dynamic>?> getUploadUrl(String fileName, String fileType) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      // We use Uri.encodeComponent to safely handle filenames with spaces (e.g. "Blood Test.pdf")
      final url = Uri.parse('$_baseUrl/care-team/records/upload-url?file_name=${Uri.encodeComponent(fileName)}&file_type=${Uri.encodeComponent(fileType)}');
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to get upload URL: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error getting upload URL: $e");
      return null;
    }
  }

  /// 7. Get a secure Pre-signed URL to view/download a private file from AWS S3
  static Future<Map<String, dynamic>?> getDownloadUrl(String recordId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final url = Uri.parse('$_baseUrl/care-team/records/$recordId/download-url');
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to get download URL: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error getting download URL: $e");
      return null;
    }
  }
}