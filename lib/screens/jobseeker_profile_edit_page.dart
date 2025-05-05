// lib/screens/jobseeker_profile_edit_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobSeekerProfileEditPage extends StatefulWidget {
  const JobSeekerProfileEditPage({Key? key}) : super(key: key);

  @override
  State<JobSeekerProfileEditPage> createState() => _JobSeekerProfileEditPageState();
}

class _JobSeekerProfileEditPageState extends State<JobSeekerProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _preferredJobTitleController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _originalData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userData = userProvider.userData;
    
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
      _nameController.text = userData['personalName'] ?? '';
      _phoneController.text = userData['phoneNumber'] ?? '';
      _preferredJobTitleController.text = userData['preferredJobTitle'] ?? '';
      
      // Handle skills array
      if (userData['skills'] is List) {
        List<String> skills = List<String>.from(userData['skills'] as List);
        _skillsController.text = skills.join(', ');
      } else {
        _skillsController.text = userData['skills']?.toString() ?? '';
      }
      
      _experienceController.text = userData['workingExperience'] ?? '';
      _emailController.text = userData['email'] ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to update your profile');
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Parse skills from comma-separated string to list
      List<String> skills = _skillsController.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();
      
      Map<String, dynamic> userData = {
        'personalName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'preferredJobTitle': _preferredJobTitleController.text.trim(),
        'skills': skills,
        'workingExperience': _experienceController.text.trim(),
      };
      
      bool success = await userProvider.updateUserData(userData);

      if (!success) {
        throw Exception('Failed to update profile');
      }

      if (mounted) {
        await userProvider.fetchUserData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
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
    _phoneController.dispose();
    _preferredJobTitleController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    
                    // Profile Picture
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
                    
                    // Preferred Job Title
                    TextFormField(
                      controller: _preferredJobTitleController,
                      decoration: InputDecoration(
                        labelText: 'Preferred Job Title',
                        prefixIcon: const Icon(Icons.work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your preferred job title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Skills
                    TextFormField(
                      controller: _skillsController,
                      decoration: InputDecoration(
                        labelText: 'Skills (comma-separated)',
                        prefixIcon: const Icon(Icons.build),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'e.g., coding, SQL, Flutter',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter at least one skill';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Working Experience
                    TextFormField(
                      controller: _experienceController,
                      decoration: InputDecoration(
                        labelText: 'Working Experience (years)',
                        prefixIcon: const Icon(Icons.timeline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your working experience';
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
                      enabled: false,
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
                  ],
                ),
              ),
            ),
    );
  }
}