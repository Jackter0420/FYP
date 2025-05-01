// lib/screens/profile_edit_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({Key? key}) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmployer = true;
  String? _errorMessage;
  
  // Added for debugging purposes
  Map<String, dynamic>? _originalData;

  @override
  void initState() {
    super.initState();
    // Check authentication status
    final currentUser = FirebaseAuth.instance.currentUser;
    print("ProfileEditPage init - User: ${currentUser != null ? 'logged in' : 'not logged in'}");
    if (currentUser != null) {
      print("User ID: ${currentUser.uid}");
    }
    
    _loadUserData();
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userData = userProvider.userData;
    
    // If not logged in, show error
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = "You must be logged in to edit your profile";
      });
      return;
    }
    
    // Save original data for comparison
    _originalData = Map<String, dynamic>.from(userData);

    setState(() {
      _isEmployer = userProvider.isEmployer;
      _nameController.text = userData['personalName'] ?? '';
      _companyNameController.text = userData['companyName'] ?? '';
      _phoneController.text = userData['phoneNumber'] ?? '';
      _emailController.text = userData['email'] ?? '';
    });
    
    print('Profile Edit: Loaded user data:');
    print('  personalName: ${_nameController.text}');
    print('  companyName: ${_companyNameController.text}');
    print('  phoneNumber: ${_phoneController.text}');
    print('  email: ${_emailController.text}');
    print('  isEmployer: $_isEmployer');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check authentication first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to update your profile');
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Create data map based on user type
      Map<String, dynamic> userData = {
        'personalName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      };

      // Add company name if it's an employer
      if (_isEmployer) {
        userData['companyName'] = _companyNameController.text.trim();
      }
      
      // Debug: Print what we're about to update
      print('Profile Edit: About to update with:');
      userData.forEach((key, value) {
        print('  $key: $value');
      });
      
      // Check if there are actual changes
      bool hasChanges = false;
      userData.forEach((key, value) {
        if (_originalData?[key] != value) {
          hasChanges = true;
          print('  Change detected in $key: ${_originalData?[key]} -> $value');
        }
      });
      
      if (!hasChanges) {
        print('No changes detected, still proceeding with update');
      }

      // Update user data in Firestore and local storage
      bool success = await userProvider.updateUserData(userData);

      if (!success) {
        throw Exception('Failed to update profile');
      }

      if (mounted) {
        // Refresh local provider data to make sure changes are reflected immediately
        await userProvider.fetchUserData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _errorMessage = 'Failed to update profile: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication state in build
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = currentUser != null;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: !isLoggedIn
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You must be logged in to edit your profile',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Profile Picture (Circle Avatar)
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Personal Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Company Name (Only for employers)
                  if (_isEmployer)
                    TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                        labelText: 'Company Name',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (_isEmployer && (value == null || value.isEmpty)) {
                          return 'Please enter company name';
                        }
                        return null;
                      },
                    ),
                  
                  if (_isEmployer) const SizedBox(height: 20),
                  
                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Email (Read-only)
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      helperText: 'Email cannot be changed',
                    ),
                    enabled: false, // Make it read-only
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  
                  // Debug button
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Check auth state
                        final currentUser = FirebaseAuth.instance.currentUser;
                        print("Auth check from debug button - User: ${currentUser != null ? 'logged in' : 'not logged in'}");
                        if (currentUser != null) {
                          print("Current user ID: ${currentUser.uid}");
                        }
                        
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        // Print current provider state
                        print("Current UserProvider state:");
                        userProvider.userData.forEach((key, value) {
                          print("  $key: $value");
                        });
                      },
                      child: const Text("Print Debug Info"),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}