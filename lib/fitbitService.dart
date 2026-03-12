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

  // --- NEW: Initialize the secure vault ---
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'fitbit_access_token';

  // --- NEW: The Smart Token Checker ---
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

  // --- NEW: Clear Token (Useful for logging out or when token expires) ---
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

  /// Fetch Today's Total Steps
  static Future<String> getTodaysSteps(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/date/today.json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final steps = data['summary']['steps'];
        return steps.toString();
      } else if (response.statusCode == 401) {
        // --- NEW: If token expired (401), clear the vault so the user can log in again ---
        print("Token expired! Clearing vault.");
        await logout();
        return "0";
      } else {
        print("API Error: ${response.body}");
        return "0";
      }
    } catch (e) {
      print("Network Error: $e");
      return "0";
    }
  }

  /// Fetch Today's Resting Heart Rate
  static Future<String> getHeartRate(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Fitbit nests the heart rate data inside an array
        final heartData = data['activities-heart'][0]['value'];
        
        // Check if a resting heart rate has been calculated for today
        if (heartData != null && heartData.containsKey('restingHeartRate')) {
          return heartData['restingHeartRate'].toString();
        } else {
          return "--"; // Return dashes if they haven't worn the watch enough today
        }
      } else if (response.statusCode == 401) {
        print("Token expired! Clearing vault.");
        await logout();
        return "--";
      } else {
        print("API Error: ${response.body}");
        return "--";
      }
    } catch (e) {
      print("Network Error: $e");
      return "--";
    }
  }
}