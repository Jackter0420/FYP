// lib/services/standalone_auth.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// Standalone authentication service that minimizes Firebase plugin usage
class StandaloneAuth {
  // Firebase Web API key - use the same one from your project
  static const String apiKey = "AIzaSyCQc1aAveY6fZE2D9avhV-_l5i31duWBRM";
  
  // Register a new user directly using REST API and store profile in Firestore
  static Future<Map<String, dynamic>> registerUser(
    String email, 
    String password, 
    Map<String, dynamic> userData,
    String userType
  ) async {
    try {
      print("StandaloneAuth: Starting REST API registration for $email");
      print("StandaloneAuth: User data to save: $userData");
      
      // Use the Firebase Auth REST API directly
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200) {
        print("StandaloneAuth: API error: ${responseData['error']['message']}");
        return {
          'success': false,
          'message': responseData['error']['message'] ?? 'Registration failed',
        };
      }
      
      final userId = responseData['localId'];
      final authToken = responseData['idToken'];
      
      print("StandaloneAuth: Auth registration successful, userId: $userId");
      
      // Save user data to Firestore - now we use Firestore directly
      try {
        // Combine all user data including type and timestamp
        final userProfileData = {
          ...userData,
          'email': email,
          'userType': userType,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        print("StandaloneAuth: Saving profile data to Firestore: $userProfileData");
        
        // Save to users collection
        await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userProfileData);
        
        print("StandaloneAuth: User profile saved to Firestore");
        
        // Save current user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', authToken);
        await prefs.setString('user_email', email);
        await prefs.setString('user_id', userId);
        await prefs.setString('user_type', userType);
        
        // Also save user profile data
        for (var entry in userData.entries) {
          await prefs.setString('user_${entry.key}', entry.value.toString());
        }
        
        print("StandaloneAuth: User data saved to SharedPreferences");
      } catch (firestoreError) {
        print("StandaloneAuth: Error saving to Firestore: $firestoreError");
        // Continue anyway since auth account was created
      }
      
      return {
        'success': true,
        'message': 'Registration successful',
        'userId': userId,
        'token': authToken,
        'userData': userData,
      };
    } catch (e) {
      print("StandaloneAuth: Registration error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Sign in a user and get user data from Firestore
  static Future<Map<String, dynamic>> signInUser(String email, String password) async {
    try {
      print("StandaloneAuth: Starting login for $email");
      
      // Use the Firebase Auth REST API directly
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200) {
        print("StandaloneAuth: API error: ${responseData['error']['message']}");
        return {
          'success': false,
          'message': responseData['error']['message'] ?? 'Login failed',
        };
      }
      
      final userId = responseData['localId'];
      final authToken = responseData['idToken'];
      
      // Get user data from Firestore
      Map<String, dynamic> userData = {};
      String userType = 'employer'; // Default
      
      try {
        final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
        
        if (userDoc.exists) {
          userData = userDoc.data() ?? {};
          if (userData.containsKey('userType')) {
            userType = userData['userType'].toString();
          }
          print("StandaloneAuth: Retrieved user data: $userData");
        } else {
          print("StandaloneAuth: No user document found in Firestore");
        }
      } catch (e) {
        print("StandaloneAuth: Error getting user data from Firestore: $e");
        // Continue with basic data
      }
      
      // Save auth data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_token', authToken);
      await prefs.setString('user_email', email);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_type', userType);
      
      // Also save user profile data
      for (var entry in userData.entries) {
        if (entry.value != null) {
          await prefs.setString('user_${entry.key}', entry.value.toString());
        }
      }
      
      print("StandaloneAuth: Login successful, saved data to SharedPreferences");
      return {
        'success': true,
        'message': 'Login successful',
        'userId': userId,
        'token': authToken,
        'userType': userType,
        'userData': userData,
      };
    } catch (e) {
      print("StandaloneAuth: Login error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Get current user info from SharedPreferences
  static Future<Map<String, dynamic>> getCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userEmail = prefs.getString('user_email');
    final userType = prefs.getString('user_type');
    
    if (userId == null || userEmail == null) {
      return {
        'isLoggedIn': false,
      };
    }
    
    // Collect all user_ prefixed keys for additional profile data
    Map<String, dynamic> userData = {
      'email': userEmail,
      'userId': userId,
      'userType': userType,
    };
    
    // Get all keys and filter for user_ prefixed ones (except the ones we already have)
    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key.startsWith('user_') && 
          key != 'user_id' && 
          key != 'user_email' && 
          key != 'user_type' &&
          key != 'user_token') {
        // Remove the 'user_' prefix to get the original field name
        String fieldName = key.substring(5);
        userData[fieldName] = prefs.getString(key);
      }
    }
    
    print("StandaloneAuth: Retrieved user data from SharedPreferences: $userData");
    return {
      'isLoggedIn': true,
      'userData': userData,
    };
  }
  
  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    return token != null;
  }
  
  // Reset password
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      print("StandaloneAuth: Sending password reset for $email");
      
      // Use the Firebase Auth REST API for password reset
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requestType': 'PASSWORD_RESET',
          'email': email,
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200) {
        print("StandaloneAuth: API error: ${responseData['error']['message']}");
        return {
          'success': false,
          'message': responseData['error']['message'] ?? 'Failed to send reset email',
        };
      }
      
      print("StandaloneAuth: Password reset email sent successfully");
      return {
        'success': true,
        'message': 'Password reset email sent successfully',
      };
    } catch (e) {
      print("StandaloneAuth: Password reset error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Sign out
  static Future<void> signOut() async {
    print("StandaloneAuth: Signing out user");
    final prefs = await SharedPreferences.getInstance();
    
    // Get all keys and filter for user_ prefixed ones
    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key.startsWith('user_')) {
        await prefs.remove(key);
      }
    }
    
    print("StandaloneAuth: User signed out successfully");
  }
}