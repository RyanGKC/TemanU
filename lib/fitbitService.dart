import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NEW: For your base URL

class FitbitService {
  // Replace with the 6-character Client ID from the Fitbit Developer Portal
  static const String clientId = '23TYX7'; 

  // Make the redirect URI dynamic based on the platform
  static String get redirectUri => kIsWeb 
      ? 'http://localhost:8080/auth.html' 
      : 'temanu://oauth2redirect';

  // --- NEW: Grab the base URL to route to your Python backend ---
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  // --- Initialize the secure vault ---
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'fitbit_access_token';

  // --- IN-MEMORY CACHES ---
  static String? _cachedSteps;
  static DateTime? _lastStepsFetchTime;

  static String? _cachedCalories;
  static DateTime? _lastCaloriesFetchTime;

  // --- The Smart Token Checker ---
  static Future<String?> getValidToken() async {
    // 1. Check if we already have it on the device
    String? savedToken = await _storage.read(key: _tokenKey);
    if (savedToken != null) return savedToken; 

    // 2. We don't have one! Trigger the Fitbit Login Screen
    String? newToken = await authenticate();
    
    // 3. If login was successful, save it!
    if (newToken != null) {
      // Save it to the phone's secure vault
      await _storage.write(key: _tokenKey, value: newToken);
      
      // --- NEW: Ship it to the Python backend immediately! ---
      // Note: Implicit grant (token flow) doesn't return a refresh_token, so we pass null
      await _linkTokenToBackend(newToken, null);
      // -------------------------------------------------------
    }
    
    return newToken;
  }

  static Future<String?> getSilentToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<String?> authenticate() async {
    final url = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri, 
      'scope': 'activity heartrate sleep',
      'expires_in': '604800', 
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: kIsWeb ? 'http' : 'temanu', 
      );

      final fragment = Uri.parse(result).fragment;
      final params = Uri.splitQueryString(fragment);
      
      return params['access_token']; 
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

  static Future<bool> _linkTokenToBackend(String accessToken, String? refreshToken) async {
    try {
      // 1. Get the logged-in user's TemanU JWT token
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        print("❌ Cannot link Fitbit: User is not logged into TemanU.");
        return false;
      }

      // Note: Replace this with your actual backend URL if it's stored elsewhere
      const String baseUrl = 'http://127.0.0.1:8000'; 

      // 2. Send the Fitbit keys to the new Python route
      final response = await http.post(
        Uri.parse('$baseUrl/fitbit/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', 
        },
        body: jsonEncode({
          'access_token': accessToken,
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ SUCCESS: Fitbit token locked into the MySQL database!");
        return true;
      } else {
        print("❌ Backend rejected the Fitbit token. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error linking token to backend: $e");
      return false;
    }
  }

  /// Fetch Today's Total Steps (Now hitting your Python backend!)
  static Future<String?> getTodaysSteps(String accessToken, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSteps != null && _lastStepsFetchTime != null) {
      if (DateTime.now().difference(_lastStepsFetchTime!).inMinutes < 2) {
        return _cachedSteps;
      }
    }

    try {
      String today = _getTodayDateString(); 
      
      // --- NEW: Grab the TemanU JWT to prove who we are! ---
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        print("❌ Cannot fetch steps: User is not logged into TemanU.");
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$today'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', // <-- Send the JWT, not the Fitbit token!
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steps = data['summary']['steps'].toString();
        
        _cachedSteps = steps;
        _lastStepsFetchTime = DateTime.now();
        
        return steps;
      } else if (response.statusCode == 401) {
        // If Python tells us the Fitbit token is expired, clear our vault
        await logout();
        return null;
      } else {
        print("Backend Proxy Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }

  /// DISABLED HEART RATE: Safely returns null so the app doesn't crash
  static Future<String?> getHeartRate(String accessToken, {bool forceRefresh = false}) async {
    // Returning null means homepage.dart will simply ignore it and leave the "--" on the dashboard.
    return null; 
  }

  /// Fetch Today's Active Calories Burned (Hitting your Python backend)
  static Future<String?> getCaloriesBurned(String accessToken, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCalories != null && _lastCaloriesFetchTime != null) {
      if (DateTime.now().difference(_lastCaloriesFetchTime!).inMinutes < 2) {
        return _cachedCalories;
      }
    }

    try {
      String today = _getTodayDateString();

      // --- NEW: Grab the TemanU JWT to prove who we are! ---
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('jwt_token');

      if (jwtToken == null) {
        print("❌ Cannot fetch calories: User is not logged into TemanU.");
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/fitbit/activity/$today'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', // <-- Send the JWT, not the Fitbit token!
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final calories = data['summary']['caloriesOut'].toString();

        _cachedCalories = calories;
        _lastCaloriesFetchTime = DateTime.now();
        return calories;
      } else if (response.statusCode == 401) {
        // If Python tells us the Fitbit token is expired, clear our vault
        await logout();
        return null;
      } else {
        print("Backend Proxy Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }
}