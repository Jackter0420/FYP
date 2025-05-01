// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Firebase Web API key - use the same one from your project
  static const String apiKey = "AIzaSyCQc1aAveY6fZE2D9avhV-_l5i31duWBRM";
  
  // Save user data to Firestore
  static Future<bool> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      print("FirebaseService: Saving user data for $userId: $userData");
      
      await _firestore.collection('users').doc(userId).set(userData);
      
      print("FirebaseService: User data saved successfully");
      return true;
    } catch (e) {
      print("FirebaseService: Error saving user data: $e");
      return false;
    }
  }
  
  // Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      print("FirebaseService: Getting user data for $userId");
      
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        print("FirebaseService: Retrieved user data: $userData");
        return userData;
      } else {
        print("FirebaseService: No user document found for $userId");
        return null;
      }
    } catch (e) {
      print("FirebaseService: Error getting user data: $e");
      return null;
    }
  }
  
  // Update user data in Firestore
  static Future<bool> updateUserData(String userId, Map<String, dynamic> newData) async {
    try {
      print("FirebaseService: Updating user data for $userId: $newData");
      
      await _firestore.collection('users').doc(userId).update(newData);
      
      print("FirebaseService: User data updated successfully");
      return true;
    } catch (e) {
      print("FirebaseService: Error updating user data: $e");
      return false;
    }
  }

  // For deleting old profile photos when a user updates their photo
  static Future<bool> deleteProfilePhoto(String photoUrl) async {
    try {
      if (photoUrl.startsWith('https://firebasestorage.googleapis.com')) {
        // Extract the path from the URL
        final ref = FirebaseStorage.instance.refFromURL(photoUrl);
        await ref.delete();
        print("FirebaseService: Old profile photo deleted successfully");
        return true;
      }
      return false;
    } catch (e) {
      print("FirebaseService: Error deleting old profile photo: $e");
      return false;
    }
  }

  // Save data to SharedPreferences with user_ prefix
  static Future<void> saveToLocalStorage(Map<String, dynamic> data) async {
    try {
      print("FirebaseService: Saving data to SharedPreferences");
      
      final prefs = await SharedPreferences.getInstance();
      
      for (var entry in data.entries) {
        if (entry.value != null) {
          String key = 'user_${entry.key}';
          
          // Special handling for List and Map types
          if (entry.value is List || entry.value is Map) {
            String value = json.encode(entry.value);
            await prefs.setString(key, value);
          } else {
            String value = entry.value.toString();
            await prefs.setString(key, value);
          }
        }
      }
      
      print("FirebaseService: Data saved to SharedPreferences");
    } catch (e) {
      print("FirebaseService: Error saving to SharedPreferences: $e");
    }
  }
  
  // Get all user_ prefixed data from SharedPreferences
  static Future<Map<String, dynamic>> getFromLocalStorage() async {
    try {
      print("FirebaseService: Getting data from SharedPreferences");
      
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> userData = {};
      
      Set<String> allKeys = prefs.getKeys();
      for (String key in allKeys) {
        if (key.startsWith('user_')) {
          // Remove the 'user_' prefix to get the original field name
          String fieldName = key.substring(5);
          String? rawValue = prefs.getString(key);
          
          if (rawValue != null) {
            // Try to parse JSON for complex types
            try {
              final dynamic decodedValue = json.decode(rawValue);
              userData[fieldName] = decodedValue;
            } catch (e) {
              // If not JSON, use the raw string
              userData[fieldName] = rawValue;
            }
          }
        }
      }
      
      print("FirebaseService: Retrieved data from SharedPreferences: $userData");
      return userData;
    } catch (e) {
      print("FirebaseService: Error getting from SharedPreferences: $e");
      return {};
    }
  }
  
  // Clear all user_ prefixed data from SharedPreferences
  static Future<void> clearLocalStorage() async {
    try {
      print("FirebaseService: Clearing data from SharedPreferences");
      
      final prefs = await SharedPreferences.getInstance();
      
      Set<String> allKeys = prefs.getKeys();
      for (String key in allKeys) {
        if (key.startsWith('user_')) {
          await prefs.remove(key);
        }
      }
      
      print("FirebaseService: Data cleared from SharedPreferences");
    } catch (e) {
      print("FirebaseService: Error clearing SharedPreferences: $e");
    }
  }
  
  // Check if a user exists in Firestore
  static Future<bool> userExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print("FirebaseService: Error checking if user exists: $e");
      return false;
    }
  }
  
  // Create a new collection in Firestore for the user (e.g., jobs, applications)
  static Future<bool> createUserCollection(String userId, String collectionName, Map<String, dynamic> initialData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .add(initialData);
      return true;
    } catch (e) {
      print("FirebaseService: Error creating user collection: $e");
      return false;
    }
  }
  
  // Register a new user with Firebase Auth REST API
  static Future<Map<String, dynamic>> registerUser(
    String email, 
    String password, 
    Map<String, dynamic> userData,
    String userType
  ) async {
    try {
      print("FirebaseService: Starting user registration for $email");
      
      // First try direct Firebase Auth SDK
      UserCredential? userCredential;
      String? userId;
      String? authToken;
      bool usedRestApi = false;
      
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        userId = userCredential.user?.uid;
        authToken = await userCredential.user?.getIdToken();
        
        print("FirebaseService: User registered with Firebase SDK: $userId");
      } catch (authError) {
        print("FirebaseService: Firebase SDK registration failed, trying REST API: $authError");
        
        // If direct SDK fails, fall back to REST API
        usedRestApi = true;
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
          print("FirebaseService: Registration error: ${responseData['error']['message']}");
          return {
            'success': false,
            'message': responseData['error']['message'] ?? 'Registration failed',
          };
        }
        
        userId = responseData['localId'];
        authToken = responseData['idToken'];
      }
      
      if (userId == null) {
        return {
          'success': false,
          'message': 'Failed to create user account',
        };
      }
      
      print("FirebaseService: User registered with ID: $userId");
      
      // Add additional user data to Firestore
      final userProfileData = {
        ...userData,
        'email': email,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Save to Firestore
      bool firestoreSaved = await saveUserData(userId, userProfileData);
      
      if (!firestoreSaved) {
        print("FirebaseService: Warning - User created but Firestore data not saved");
      }
      
      // Save to SharedPreferences
      await saveToLocalStorage({
        'id': userId,
        'email': email,
        'userType': userType,
        'token': authToken,
        ...userData,
      });
      
      return {
        'success': true,
        'message': 'Registration successful',
        'userId': userId,
        'token': authToken,
        'userData': userProfileData,
        'usedRestApi': usedRestApi,
      };
    } catch (e) {
      print("FirebaseService: Registration error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  static Future<Map<String, dynamic>> signInUser(String email, String password) async {
    try {
      print("FirebaseService: Starting login for $email");
      
      // First try direct Firebase Auth SDK
      UserCredential? userCredential;
      String? userId;
      String? authToken;
      bool usedRestApi = false;
      
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        userId = userCredential.user?.uid;
        authToken = await userCredential.user?.getIdToken();
        
        print("FirebaseService: User signed in with Firebase SDK: $userId");
      } catch (authError) {
        print("FirebaseService: Firebase SDK login failed, trying REST API: $authError");
        
        // If direct SDK fails, fall back to REST API
        usedRestApi = true;
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
          print("FirebaseService: Login error: ${responseData['error']['message']}");
          return {
            'success': false,
            'message': responseData['error']['message'] ?? 'Login failed',
          };
        }
        
        userId = responseData['localId'];
        authToken = responseData['idToken'];
      }
      
      if (userId == null) {
        return {
          'success': false,
          'message': 'Failed to authenticate user',
        };
      }
      
      print("FirebaseService: User signed in with ID: $userId");
      
      // Get user data from Firestore
      Map<String, dynamic>? userData = await getUserData(userId);
      
      if (userData == null) {
        userData = {'email': email};
        print("FirebaseService: No user data found in Firestore, using minimal data");
      }
      
      String userType = userData['userType'] ?? 'jobSeeker'; // Default to jobSeeker for safety
      
      // Save to SharedPreferences
      await saveToLocalStorage({
        'id': userId,
        'email': email,
        'userType': userType,
        'token': authToken,
        ...userData,
      });
      
      return {
        'success': true,
        'message': 'Login successful',
        'userId': userId,
        'token': authToken,
        'userType': userType,
        'userData': userData,
        'usedRestApi': usedRestApi,
      };
    } catch (e) {
      print("FirebaseService: Login error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Reset password with Firebase Auth REST API
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      print("FirebaseService: Sending password reset for $email");
      
      // First try direct Firebase Auth SDK
      try {
        await _auth.sendPasswordResetEmail(email: email);
        print("FirebaseService: Password reset email sent via Firebase SDK");
        return {
          'success': true,
          'message': 'Password reset email sent successfully',
        };
      } catch (authError) {
        print("FirebaseService: Firebase SDK password reset failed, trying REST API: $authError");
        
        // Use Firebase Auth REST API for password reset as fallback
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
          print("FirebaseService: Password reset error: ${responseData['error']['message']}");
          return {
            'success': false,
            'message': responseData['error']['message'] ?? 'Failed to send password reset',
          };
        }
        
        return {
          'success': true,
          'message': 'Password reset email sent successfully',
        };
      }
    } catch (e) {
      print("FirebaseService: Password reset error: $e");
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Sign out user
  static Future<void> signOut() async {
    try {
      print("FirebaseService: Signing out user");
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Clear local storage
      await clearLocalStorage();
      
      print("FirebaseService: User signed out successfully");
    } catch (e) {
      print("FirebaseService: Error signing out: $e");
    }
  }
  
  // When getting user profile data, ensure photoUrl is included
  static Future<Map<String, dynamic>> getEmployerProfile(String userId) async {
    try {
      Map<String, dynamic>? userData = await getUserData(userId);
      
      if (userData == null) {
        return {};
      }
      
      // Extract employer specific fields including photoUrl
      return {
        'companyName': userData['companyName'],
        'personalName': userData['personalName'],
        'phoneNumber': userData['phoneNumber'],
        'email': userData['email'],
        'photoUrl': userData['photoUrl'], // Added photoUrl
      };
    } catch (e) {
      print("FirebaseService: Error getting employer profile: $e");
      return {};
    }
  }

  static Future<Map<String, dynamic>> getJobSeekerProfile(String userId) async {
    try {
      Map<String, dynamic>? userData = await getUserData(userId);
      
      if (userData == null) {
        return {};
      }
      
      // Extract job seeker specific fields including photoUrl
      return {
        'personalName': userData['personalName'],
        'preferredJobTitle': userData['preferredJobTitle'],
        'skills': userData['skills'],
        'workingExperience': userData['workingExperience'],
        'email': userData['email'],
        'photoUrl': userData['photoUrl'], // Added photoUrl
      };
    } catch (e) {
      print("FirebaseService: Error getting job seeker profile: $e");
      return {};
    }
  }
}