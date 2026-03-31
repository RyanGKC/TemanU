import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

class FitbitService {
  // CLIENT_ID and REDIRECT_URI have been removed. The Backend handles them!
  
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'fitbit_backend_linked'; // Changed key name for clarity

  // --- IN-MEMORY CACHES ---
  static String? _cachedSteps;
  static DateTime? _lastStepsFetchTime;

  static String? _cachedCalories;
  static DateTime? _lastCaloriesFetchTime;

  // --- The Smart Token Checker ---
  static Future<String?> getValidToken() async {
    // We no longer need the actual token string. 
    // We just check if the user has successfully linked their account to the backend.
    String? isLinked = await _storage.read(key: _tokenKey);
    if (isLinked != null) return "linked"; 

    String? success = await authenticate();
    
    if (success != null) {
      await _storage.write(key: _tokenKey, value: "linked");
    }
    
    return success;
  }

  static Future<String?> getSilentToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<String?> authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final jwtToken = prefs.getString('jwt_token');

    if (jwtToken == null) {
      print("❌ Cannot authenticate: User is not logged into TemanU.");
      return null;
    }

    try {
      // 1. Ask FastAPI for the dynamically generated Fitbit Login URL
      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/connect'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', 
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authUrl = data['auth_url'];

        // 2. Open the URL for the user to log in
        await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: kIsWeb ? 'https' : 'temanu', 
        );

        // 3. We DO NOT need to parse the result string anymore!
        // By the time the popup closes, FastAPI has already grabbed the token 
        // and saved it to the MySQL database. We just return a success string!
        return "backend_linked_success"; 
      } else {
        print("❌ Backend failed to generate auth URL. Status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Fitbit Auth Error: $e");
      return null;
    }
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // NOTE: _linkTokenToBackend HAS BEEN DELETED. 

  /// Fetch Today's Total Steps
  static Future<String?> getTodaysSteps(String accessToken, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSteps != null && _lastStepsFetchTime != null) {
      if (DateTime.now().difference(_lastStepsFetchTime!).inMinutes < 2) {
        return _cachedSteps;
      }
    }

    try {
      String today = _getTodayDateString(); 
      
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) return null;
      
      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$today?force_refresh=$forceRefresh'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', 
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steps = data['summary']['steps'].toString();
        
        _cachedSteps = steps;
        _lastStepsFetchTime = DateTime.now();
        
        return steps;
      } else if (response.statusCode == 401) {
        await logout();
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }

  /// DISABLED HEART RATE: Safely returns null so the app doesn't crash
  static Future<String?> getHeartRate(String accessToken, {bool forceRefresh = false}) async {
    return null; 
  }

  /// Fetch Today's Active Calories Burned
  static Future<String?> getCaloriesBurned(String accessToken, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCalories != null && _lastCaloriesFetchTime != null) {
      if (DateTime.now().difference(_lastCaloriesFetchTime!).inMinutes < 2) {
        return _cachedCalories;
      }
    }

    try {
      String today = _getTodayDateString();

      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$today?force_refresh=$forceRefresh'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', 
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final calories = data['summary']['caloriesOut'].toString();

        _cachedCalories = calories;
        _lastCaloriesFetchTime = DateTime.now();
        return calories;
      } else if (response.statusCode == 401) {
        await logout();
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }
}