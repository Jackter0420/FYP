// lib/providers/user_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prototype_2/services/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic> _userData = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserProvider() {
    print("Initializing UserProvider");
    // Use Future.microtask to prevent calling notifyListeners during build
    Future.microtask(() {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    // Don't call notifyListeners here - it might be during build
    
    // First try to get data from SharedPreferences (faster)
    await _loadFromSharedPreferences();
    
    // Set up auth state listener
    _auth.authStateChanges().listen((User? user) async {
      print("Auth state changed: user ${user != null ? 'logged in' : 'logged out'}");
      if (user != null) {
        await fetchUserData();
      } else {
        _userData = {};
        // Safe to call notifyListeners here because it's in a callback
        notifyListeners();
      }
    });
    
    _isLoading = false;
    _isInitialized = true;
    // Safe to call notifyListeners here as it's part of a future
    notifyListeners();
  }
  
  Future<void> _loadFromSharedPreferences() async {
    try {
      // Use FirebaseService to get data from SharedPreferences
      final userData = await FirebaseService.getFromLocalStorage();
      if (userData.isNotEmpty) {
        _userData = userData;
        print("UserProvider: Loaded user data from SharedPreferences: $_userData");
      }
    } catch (e) {
      print("UserProvider: Error loading from SharedPreferences: $e");
    }
  }

  // Use auth.currentUser directly instead of storing _user
  User? get user => _auth.currentUser;
  Map<String, dynamic> get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  bool get isLoggedIn => _auth.currentUser != null;
  
  String? get userType => _userData['userType'];
  String? get companyName => _userData['companyName'];
  String? get personalName => _userData['personalName'];
  String? get phoneNumber => _userData['phoneNumber'];
  String? get email => _userData['email'];
  
  bool get isEmployer => userType == 'employer';
  bool get isJobSeeker => userType == 'jobSeeker';

  // Public method to fetch user data - can be called from login screen
Future<void> fetchUserData() async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) {
    print("fetchUserData: No user logged in");
    
    // Try loading from shared preferences
    await _loadFromSharedPreferences();
    return;
  }
  
  _isLoading = true;
  
  // REMOVE THIS BLOCK ENTIRELY:
  // // Only notify outside of initialization to avoid build-time notifies
  // if (_isInitialized) {
  //   notifyListeners();
  // }
  
  try {
    print('Fetching user data for UID: ${currentUser.uid}');
    
    // Use FirebaseService to get user data
    Map<String, dynamic>? userData = await FirebaseService.getUserData(currentUser.uid);
    
    if (userData != null && userData.isNotEmpty) {
      _userData = Map<String, dynamic>.from(userData);
      
      print('User data fetched successfully:');
      _userData.forEach((key, value) {
        print('  $key: $value');
      });
      
      // Save to shared preferences for faster access later
      await FirebaseService.saveToLocalStorage(_userData);
    } else {
      print('No user document found in Firestore for UID: ${currentUser.uid}');
    }
  } catch (e) {
    print('Error fetching user data: $e');
  } finally {
    _isLoading = false;
    
    // Use a safer way to notify listeners by scheduling it for the next frame
    if (_isInitialized) {
      // Schedule the notification for after the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}
  // Method to update user data
  Future<bool> updateUserData(Map<String, dynamic> newData) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('updateUserData: No user logged in. Cannot update data.');
      return false;
    }
    
    print('Attempting to update user data with: $newData');
    
    try {
      // Update in Firestore using FirebaseService
      bool updated = await FirebaseService.updateUserData(currentUser.uid, newData);
      
      if (updated) {
        print('Firestore update successful. Updating local data.');
        
        // Update local data - create a new map to trigger proper state update
        Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(_userData);
        updatedUserData.addAll(newData);
        _userData = updatedUserData;
        
        // Save to shared preferences
        print('Saving updated data to SharedPreferences');
        await FirebaseService.saveToLocalStorage(_userData);
        
        print('Data updated successfully. New data:');
        _userData.forEach((key, value) {
          print('  $key: $value');
        });
        
        // Notify listeners of the change
        notifyListeners();
        return true;
      } else {
        print('Failed to update data in Firestore');
        return false;
      }
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // Improved sign out method
  Future<void> signOut() async {
    try {
      print("UserProvider: Signing out user");
      
      // First clear shared preferences
      await FirebaseService.clearLocalStorage();
      
      // Then sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      
      // Finally clear local data
      _userData = {};
      
      notifyListeners();
      
      print("UserProvider: User signed out successfully");
    } catch (e) {
      print("UserProvider: Error signing out: $e");
      // Re-throw to allow UI to show error
      rethrow;
    }
  }
}