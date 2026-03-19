import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Grab the URL from your .env file (e.g., http://10.0.2.2:8000)
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  
  static const _storage = FlutterSecureStorage();

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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
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
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Account created!'};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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
  
  static Future<Map<String, dynamic>?> fetchFitbitData(String date, String fitbitAccessToken) async {
    try {
      // Notice we are calling YOUR backend, not api.fitbit.com!
      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$date'), 
        headers: {
          'Content-Type': 'application/json',
          // We pass the Fitbit token in a custom header so Python can use it
          'fitbit-token': fitbitAccessToken, 
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Backend proxy failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Proxy connection error: $e');
      return null;
    }
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

  /// Fetch the 7-day aggregated insights from Python
  static Future<List<dynamic>> getWeeklyInsights() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/insights/weekly'),
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
}