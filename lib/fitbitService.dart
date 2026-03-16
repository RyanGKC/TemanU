import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FitbitService {
  // Replace with the 6-character Client ID from the Fitbit Developer Portal
  static const String clientId = '23TYX7'; 

  // Make the redirect URI dynamic based on the platform
  static String get redirectUri => kIsWeb 
      ? 'http://localhost:8080/auth.html' 
      : 'temanu://oauth2redirect';

  // --- Initialize the secure vault ---
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'fitbit_access_token';

  // --- NEW: IN-MEMORY CACHES ---
  static String? _cachedSteps;
  static DateTime? _lastStepsFetchTime;

  static String? _cachedHeartRate;
  static DateTime? _lastHeartRateFetchTime;

  static String? _cachedCalories;
  static DateTime? _lastCaloriesFetchTime;

  // --- The Smart Token Checker ---
  static Future<String?> getValidToken() async {
    // 1. Look in the vault first
    String? savedToken = await _storage.read(key: _tokenKey);
    
    if (savedToken != null) {
      return savedToken; // Fast path! Skip the browser.
    }

    // 2. If the vault is empty, open the browser
    String? newToken = await authenticate();
    
    // 3. If they logged in successfully, lock the new token in the vault
    if (newToken != null) {
      await _storage.write(key: _tokenKey, value: newToken);
    }
    
    return newToken;
  }

  static Future<String?> getSilentToken() async {
    // Only looks in the vault. NEVER opens the browser!
    return await _storage.read(key: _tokenKey);
  }

  // --- Clear Token (Useful for logging out or when token expires) ---
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<String?> authenticate() async {
    final url = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri, // Uses the dynamic getter
      'scope': 'activity heartrate sleep',
      'expires_in': '604800', // Token stays valid for 1 week
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        // The scheme doesn't matter for the web, but we pass 'http' just in case
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

/// Fetch Today's Total Steps (Now Returns String? and caches)
  static Future<String?> getTodaysSteps(String accessToken, {bool forceRefresh = false}) async {
    // --- CACHE CHECK ---
    // If we are NOT forcing a refresh, and the cache is less than 2 minutes old, use it!
    if (!forceRefresh && _cachedSteps != null && _lastStepsFetchTime != null) {
      if (DateTime.now().difference(_lastStepsFetchTime!).inMinutes < 2) {
        print("Using cached steps to save API limits.");
        return _cachedSteps;
      }
    }

    try {
      String today = _getTodayDateString(); 
      
      final response = await http.get(
        // Inject the formatted date into the URL
        Uri.parse('https://api.fitbit.com/1/user/-/activities/date/$today.json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steps = data['summary']['steps'].toString();
        
        // Save to cache before returning
        _cachedSteps = steps;
        _lastStepsFetchTime = DateTime.now();
        
        return steps;
      } else if (response.statusCode == 401) {
        await logout();
        return null;
      } else {
        print("API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }

  /// Fetch Today's Resting Heart Rate (Now Returns String? and caches)
  static Future<String?> getHeartRate(String accessToken, {bool forceRefresh = false}) async {
    // --- CACHE CHECK ---
    if (!forceRefresh && _cachedHeartRate != null && _lastHeartRateFetchTime != null) {
      if (DateTime.now().difference(_lastHeartRateFetchTime!).inMinutes < 2) {
        print("Using cached heart rate to save API limits.");
        return _cachedHeartRate;
      }
    }

    try {
      String today = _getTodayDateString(); 
      
      final response = await http.get(
        // Inject the formatted date into the URL
        Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$today/1d.json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final heartData = data['activities-heart'][0]['value'];
        
        if (heartData != null && heartData.containsKey('restingHeartRate')) {
          final hr = heartData['restingHeartRate'].toString();
          
          // Save to cache before returning
          _cachedHeartRate = hr;
          _lastHeartRateFetchTime = DateTime.now();
          return hr;
        }
        
        // Cache the "--" so we don't spam the API looking for non-existent data
        _cachedHeartRate = "--";
        _lastHeartRateFetchTime = DateTime.now();
        return "--";

      } else if (response.statusCode == 401) {
        await logout();
        return null;
      } else {
        print("API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }

  /// Fetch Today's Active Calories Burned
static Future<String?> getCaloriesBurned(String accessToken, {bool forceRefresh = false}) async {
  // Reuse the same 2-minute cache pattern
  if (!forceRefresh && _cachedCalories != null && _lastCaloriesFetchTime != null) {
    if (DateTime.now().difference(_lastCaloriesFetchTime!).inMinutes < 2) {
      print("Using cached calories to save API limits.");
      return _cachedCalories;
    }
  }

  try {
    String today = _getTodayDateString();

    final response = await http.get(
      // Same activities endpoint as steps — calories are in the same summary object
      Uri.parse('https://api.fitbit.com/1/user/-/activities/date/$today.json'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // "activityCalories" = active burn only, "caloriesOut" = total including BMR
      final calories = data['summary']['caloriesOut'].toString();

      _cachedCalories = calories;
      _lastCaloriesFetchTime = DateTime.now();
      return calories;

    } else if (response.statusCode == 401) {
      await logout();
      return null;
    } else {
      print("API Error: ${response.body}");
      return null;
    }
  } catch (e) {
    print("Network Error: $e");
    return null;
  }
}
}