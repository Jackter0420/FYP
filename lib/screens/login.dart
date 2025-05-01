// lib/screens/login.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'register_type_select.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/jobseeker_chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Updated _signIn method with improved error handling
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[LOGIN] Attempting to sign in with email: ${_emailController.text.trim()}');
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Try sign in with Firebase Auth directly
      UserCredential? userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (authError) {
        print('[LOGIN] Firebase Auth direct login error: $authError');
        // We'll continue with the FirebaseService method which might handle things differently
      }
      
      // Now use FirebaseService to get extra user data and save to preferences
      final result = await FirebaseService.signInUser(
        email,
        password,
      );
      
      if (!result['success']) {
        // If FirebaseService call failed but direct auth worked, try to continue
        if (userCredential?.user != null) {
          print('[LOGIN] Direct auth worked but FirebaseService failed: ${result['message']}');
        } else {
          // Both methods failed, throw an error
          throw Exception(result['message']);
        }
      }
      
      // Verify authentication status
      final currentUser = FirebaseAuth.instance.currentUser;
      print('[LOGIN] Authentication status check - User: ${currentUser != null ? 'logged in' : 'not logged in'}');
      if (currentUser != null) {
        print('[LOGIN] User ID: ${currentUser.uid}');
        print('[LOGIN] User email: ${currentUser.email}');
      } else {
        throw Exception('Login process completed but user is not logged in');
      }
      
      // Get user type from result, fallback to 'jobSeeker' if not available to ensure the app doesn't crash
      final userType = result['userType'] as String? ?? 'jobSeeker';
      print('[LOGIN] Sign in successful. User type: $userType');
      
      // Update UserProvider with the retrieved data
      if (result.containsKey('userData')) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUserData();
        
        // Debug output of user data after login
        print('[LOGIN] User data loaded in provider:');
        userProvider.userData.forEach((key, value) {
          print('  $key: $value');
        });
        
        // Double check isLoggedIn after fetching
        print('[LOGIN] UserProvider.isLoggedIn: ${userProvider.isLoggedIn}');
      }
      
      if (!mounted) return;
      
      // Navigate based on user type with better error handling
      try {
        if (userType.toLowerCase() == 'employer') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const EmployerChatPage()),
            (route) => false,
          );
        } else { // Default to jobseeker for any other type to avoid crashes
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
            (route) => false,
          );
        }
      } catch (navError) {
        print('[LOGIN] Navigation error: $navError');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening app page. Please restart the app.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      print('[LOGIN] Firebase Auth error: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = e.message ?? 'Authentication failed';
        _isLoading = false;
      });
    } catch (e) {
      print('[LOGIN] Login error: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Password reset function
  Future<void> _resetPassword() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email address for password reset.";
      });
      return;
    }

    try {
      // Using Firebase service for password reset
      final response = await FirebaseService.resetPassword(email);
      
      if (!response['success']) {
        throw Exception(response['message']);
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent. Check your inbox."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to send reset email: ${e.toString()}";
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFAADDEC),
    body: Stack(
      children: [
        // Logo and Log In text in upper left
        Positioned(
          left: 20,
          top: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 85,
                width: 266,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/logo_word.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        // Center login form
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E7E7),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterTypeSelect()),
                            );
                          },
                          child: const Text(
                            'Create an Account',
                            style: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _resetPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Direct access buttons for testing/convenience
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EmployerChatPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5DC),
                          minimumSize: const Size(150, 40),
                        ),
                        child: const Text(
                          'Employer Chat',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5DC),
                          minimumSize: const Size(150, 40),
                        ),
                        child: const Text(
                          'Job Seeker Chat',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}