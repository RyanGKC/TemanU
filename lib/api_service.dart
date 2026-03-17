import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        await _storage.write(key: 'jwt_token', value: data['access_token']); 
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