// lib/screens/debug_login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prototype_2/services/firebase_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';

class DebugLoginPage extends StatefulWidget {
  const DebugLoginPage({Key? key}) : super(key: key);

  @override
  State<DebugLoginPage> createState() => _DebugLoginPageState();
}

class _DebugLoginPageState extends State<DebugLoginPage> {
  // Server URL for Rasa
  final String _rasaEndpoint = 'http://10.0.2.2:5005/webhooks/rest/webhook';
  // For iOS simulator use: 'http://localhost:5005/webhooks/rest/webhook'
  
  bool _isLoading = false;
  String _result = '';
  String _userId = '';
  String _userEmail = '';
  String _authToken = '';
  
  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }
  
  Future<void> _checkCurrentUser() async {
    setState(() {
      _isLoading = true;
      _result = 'Checking current user...';
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        setState(() {
          _userId = user.uid;
          _userEmail = user.email ?? 'No email';
          _result += '\nUser is logged in: ${user.uid}';
        });
        
        // Get token
        try {
          final token = await user.getIdToken();
          setState(() {
            _authToken = token ?? ''; // Use empty string if token is null
            // Safe handling of token
            if (token != null && token.isNotEmpty) {
              _result += '\nAuth token: ${token.substring(0, min(20, token.length))}...';
            } else {
              _result += '\nAuth token: [empty token]';
            }
          });
        } catch (e) {
          setState(() {
            _result += '\nError getting token: $e';
          });
        }
      } else {
        setState(() {
          _result += '\nNo user is logged in';
        });
      }
    } catch (e) {
      setState(() {
        _result += '\nError checking auth state: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing Firebase connection...';
    });
    
    try {
      // Test Firebase Auth
      final authInfo = await FirebaseAuth.instance.fetchSignInMethodsForEmail('test@example.com');
      setState(() {
        _result += '\nFirebase Auth response: $authInfo';
      });
      
      // Test Firestore
      try {
        final testDoc = await FirebaseFirestore.instance.collection('test').doc('test').get();
        setState(() {
          _result += '\nFirestore response: ${testDoc.exists ? 'Success' : 'Doc not found but API works'}';
        });
      } catch (e) {
        setState(() {
          _result += '\nFirestore error: $e';
        });
      }
    } catch (e) {
      setState(() {
        _result += '\nFirebase Auth error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _testRasaConnection() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing Rasa connection...';
    });
    
    try {
      final response = await http.post(
        Uri.parse(_rasaEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': 'debug_tester',
          'message': '/set_user_id{"user_id": "debugtest123"}'
        }),
      );
      
      setState(() {
        _result += '\nResponse status: ${response.statusCode}';
        _result += '\nResponse body: ${response.body}';
      });
      
      if (response.statusCode == 200) {
        setState(() {
          _result += '\nRasa connection successful!';
        });
      } else {
        setState(() {
          _result += '\nError connecting to Rasa server';
        });
      }
    } catch (e) {
      setState(() {
        _result += '\nException: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _sendUserIdToRasa() async {
    setState(() {
      _isLoading = true;
      _result = 'Sending user ID to Rasa...';
    });
    
    if (_userId.isEmpty) {
      setState(() {
        _result += '\nNo user ID available to send';
        _isLoading = false;
      });
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse(_rasaEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId,
          'message': '/set_user_id{"user_id": "$_userId"}'
        }),
      );
      
      setState(() {
        _result += '\nResponse status: ${response.statusCode}';
        _result += '\nResponse body: ${response.body}';
      });
      
      if (response.statusCode == 200) {
        setState(() {
          _result += '\nSuccessfully sent user ID to Rasa!';
        });
      } else {
        setState(() {
          _result += '\nError sending user ID';
        });
      }
    } catch (e) {
      setState(() {
        _result += '\nException: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _getUserData() async {
    setState(() {
      _isLoading = true;
      _result = 'Getting user data from UserProvider...';
    });
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.fetchUserData();
      
      setState(() {
        _result += '\nUserProvider data:';
        _result += '\nUser: ${userProvider.user?.uid ?? 'No user'}';
        _result += '\nIs logged in: ${userProvider.isLoggedIn}';
        _result += '\nIs initialized: ${userProvider.isInitialized}';
        
        // Print all user data
        _result += '\n\nAll user data:';
        userProvider.userData.forEach((key, value) {
          _result += '\n$key: $value';
        });
      });
    } catch (e) {
      setState(() {
        _result += '\nError getting user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Login'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auth status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auth Status',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('User ID: $_userId'),
                    Text('Email: $_userEmail'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkCurrentUser,
                      child: const Text('Refresh Auth Status'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test buttons section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Actions',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _testFirebaseConnection,
                          child: const Text('Test Firebase'),
                        ),
                        ElevatedButton(
                          onPressed: _testRasaConnection,
                          child: const Text('Test Rasa'),
                        ),
                        ElevatedButton(
                          onPressed: _sendUserIdToRasa,
                          child: const Text('Send User ID to Rasa'),
                        ),
                        ElevatedButton(
                          onPressed: _getUserData,
                          child: const Text('Get User Data'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Results section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_copy),
                          onPressed: () {
                            // Copy results to clipboard
                            final scaffold = ScaffoldMessenger.of(context);
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          },
                          tooltip: 'Copy to clipboard',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SelectableText(
                            _result,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}