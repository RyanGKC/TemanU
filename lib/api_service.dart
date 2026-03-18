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
        
        await prefs.setString('jwt_token', data['access_token']);
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
    return await _storage.read(key: 'jwt_token');
  }

  // ─── HEALTH METRICS ───

  /// Saves a metric to your unified /health endpoint
  static Future<bool> saveHealthMetric({
    required String metricType,
    required String value,
    required String unit,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return false; // User is not logged in

      final response = await http.post(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Inject the JWT!
        },
        body: jsonEncode({
          'metric_type': metricType,
          'value': value,
          'unit': unit,
        }),
      );

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
      if (token == null) {
        print("No token found. User might not be logged in.");
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <-- Proves who the user is
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(response.body);
        
        // Convert the dynamic list to a strongly typed list of maps
        List<Map<String, dynamic>> metrics = List<Map<String, dynamic>>.from(decodedData);

        // If we only want Body Weight, filter the list before returning it
        if (metricType != null) {
          metrics = metrics.where((m) => m['metric_type'] == metricType).toList();
        }

        return metrics;
      } else {
        print('Failed to fetch metrics. Status: ${response.statusCode}');
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
}