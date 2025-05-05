// lib/screens/employer_chat_page.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/candidate_search_page.dart';
import 'package:prototype_2/screens/manage_jobs_page.dart';
import 'package:prototype_2/screens/update_status_page.dart';
import 'package:prototype_2/screens/profile_edit_page.dart';
import 'package:prototype_2/screens/debug_login.dart'; // Import the debug page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/widgets/employer_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text, 
    required this.isUser, 
    DateTime? timestamp
  }) : timestamp = timestamp ?? DateTime.now();
}

class EmployerChatPage extends StatefulWidget {
  const EmployerChatPage({Key? key}) : super(key: key);

  @override
  State<EmployerChatPage> createState() => _EmployerChatPageState();
}

class _EmployerChatPageState extends State<EmployerChatPage> {
  int _currentIndex = 1;
  final TextEditingController _messageController = TextEditingController();
  String? _currentCompanyName;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _userId;
  String? _userEmail;
  
  // Rasa server URL - update this to your Rasa server address
  final String _rasaEndpoint = 'http://10.0.2.2:5005/webhooks/rest/webhook'; // Use this for Android emulator
  // final String _rasaEndpoint = 'http://localhost:5005/webhooks/rest/webhook'; // Use this for iOS simulator
  // final String _rasaEndpoint = 'https://your-rasa-server.com/webhooks/rest/webhook'; // Production URL

  // Define the conversation messages
  final List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    print("EmployerChatPage initState called");
    _fetchUserData();
  }
  
  // Modified to set company name in state and initialize Rasa connection
Future<void> _fetchUserData() async {
  try {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Get current Firebase user
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Verify auth status
    if (currentUser == null) {
      print("Warning: No user logged in when fetching data in EmployerChatPage");
      return;
    }
    
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _userId = currentUser.uid;
      _userEmail = currentUser.email;
    });
    
    await userProvider.fetchUserData();
    
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _currentCompanyName = userProvider.companyName;
    });
    
    // Initialize chat with Rasa and send user ID automatically
    if (!_isInitialized && _userId != null && mounted) {
      _initializeRasaChat();
    }
  } catch (e) {
    print("Error fetching user data in employer chat: $e");
  }
}
  
  // Initialize Rasa chat and send user ID
Future<void> _initializeRasaChat() async {
  if (_userId == null) return;
  
  // Add mounted check before setState
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      messages.add(ChatMessage(
        text: "Hello! I'm your job posting assistant. Type 'post job' to get started.",
        isUser: false
      ));
    });
    
    // FIXED: Explicitly format the user_id command with proper JSON format
    final userIdCommand = '/set_user_id{"user_id": "$_userId"}';
    print('Sending user ID command to Rasa: $userIdCommand');
    
    // Automatically send the user ID to Rasa
    final response = await http.post(
      Uri.parse(_rasaEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': _userId,
        'message': userIdCommand
      }),
    );

    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isInitialized = true;
    });
    print('Chat initialized with user ID: $_userId');
    print('Rasa response: ${response.body}');
  } catch (e) {
    print('Error initializing Rasa chat: $e');
    
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      messages.add(ChatMessage(
        text: "I'm having trouble connecting to the server. Please check your internet connection.",
        isUser: false
      ));
    });
  } finally {
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
  }
}

// Method 3: Update _testRasaConnection
Future<void> _testRasaConnection() async {
  try {
    // Check if we have a user ID
    if (_userId == null) {
      print("Cannot test Rasa: No user ID available");
      
      // Add mounted check before setState
      if (!mounted) return;
      
      setState(() {
        messages.add(ChatMessage(
          text: "Error: No user ID available. Please log in again.",
          isUser: false
        ));
      });
      return;
    }
    
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      messages.add(ChatMessage(
        text: "Testing connection to Rasa server...",
        isUser: false
      ));
    });
    
    // Send a test ping to Rasa
    final response = await http.post(
      Uri.parse(_rasaEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': _userId,
        'message': '/ping'
      }),
    );
    
    // Add mounted check before setState
    if (!mounted) return;
    
    if (response.statusCode == 200) {
      setState(() {
        messages.add(ChatMessage(
          text: "Rasa connection successful! Response: ${response.body}",
          isUser: false
        ));
      });
      
      // Now try to explicitly set the user ID
      final userIdResponse = await http.post(
        Uri.parse(_rasaEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId,
          'message': '/set_user_id{"user_id": "$_userId"}'
        }),
      );
      
      // Add mounted check before setState
      if (!mounted) return;
      
      setState(() {
        messages.add(ChatMessage(
          text: "Set User ID response: ${userIdResponse.body}",
          isUser: false
        ));
      });
      
    } else {
      // Add mounted check before setState
      if (!mounted) return;
      
      setState(() {
        messages.add(ChatMessage(
          text: "Failed to connect to Rasa: ${response.statusCode}\n${response.body}",
          isUser: false
        ));
      });
    }
  } catch (e) {
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      messages.add(ChatMessage(
        text: "Error connecting to Rasa: $e",
        isUser: false
      ));
    });
  } finally {
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
  }
}

// Method 4: Update _sendMessageToRasa
Future<void> _sendMessageToRasa(String messageText) async {
  if (messageText.trim().isEmpty || _userId == null) return;
  
  // Add mounted check before setState
  if (!mounted) return;
  
  setState(() {
    messages.add(ChatMessage(
      text: messageText,
      isUser: true
    ));
    _isLoading = true;
  });
  
  try {
    // Send message to Rasa
    final response = await http.post(
      Uri.parse(_rasaEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': _userId,
        'message': messageText
      }),
    );
    
    // Add mounted check before setState
    if (!mounted) return;
    
    if (response.statusCode == 200) {
      final List<dynamic> responseData = jsonDecode(response.body);
      
      if (responseData.isEmpty) {
        // If Rasa returns an empty response
        setState(() {
          messages.add(ChatMessage(
            text: "I'm not sure how to respond to that. Try saying 'post job' to start the job posting process.",
            isUser: false
          ));
        });
      } else {
        // Add all response messages from Rasa
        for (var msg in responseData) {
          setState(() {
            messages.add(ChatMessage(
              text: msg['text'],
              isUser: false
            ));
          });
        }
      }
    } else {
      // Handle error response
      setState(() {
        messages.add(ChatMessage(
          text: "Sorry, I encountered an error. Please try again.",
          isUser: false
        ));
      });
      print("Error from Rasa: ${response.body}");
    }
  } catch (e) {
    print("Error sending message to Rasa: $e");
    
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      messages.add(ChatMessage(
        text: "Connection error. Please check your internet connection.",
        isUser: false
      ));
    });
  } finally {
    // Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
  }
}
  // Show profile options dialog
  void _showProfileOptions(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profile Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Profile Option
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _showProfileDialog(context, userData); // Show profile details
                },
              ),
              // Edit Profile Option
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditPage(),
                    ),
                  ).then((_) {
                    // Refresh user data when returning from edit page
                    _fetchUserData();
                  });
                },
              ),
              // Debug Option - only in debug mode
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Debug User Data'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugLoginPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Your Profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Name'),
                  subtitle: Text(userData['personalName'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Company'),
                  subtitle: Text(userData['companyName'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: Text(userData['phoneNumber'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(userData['email'] ?? 'Not provided'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Improved logout method
  void _logout(BuildContext context) async {
    try {
      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text("Logout"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );
      
      // Check if user confirmed logout
      if (confirm == true) {
        // First get the provider to avoid context issues after async operations
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // Sign out user
        await userProvider.signOut();
        
        // Check if widget is still mounted before navigating
        if (!mounted) return;
        
        // Navigate to login page with a new route that clears the stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Error during logout: $e");
      // Show error to user if mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging out: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("EmployerChatPage build method starting");
    
    // Get user data from provider
    final userProvider = Provider.of<UserProvider>(context);
    final userData = userProvider.userData;
    
    // Verify current authentication state directly from Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    print("Current Firebase auth state - User: ${currentUser?.uid ?? 'Not logged in'}");
    
    // First try to get company name from state, then fallback to provider
    // This avoids the "Your Company" default when data isn't loaded yet
    final companyName = _currentCompanyName ?? 
                       userProvider.companyName ?? 
                       userData['companyName'] ?? 
                       'Your Company';
    
    print("Building EmployerChatPage with company name: $companyName");
    
    try {
          return Scaffold(
            backgroundColor: const Color(0xFFE7E7E7),
            appBar: EmployerAppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employer Chat'),
                  Text(
                    companyName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              additionalActions: [
                // Debug button
                IconButton(
                  icon: const Icon(Icons.bug_report),
                  tooltip: 'Debug',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DebugLoginPage()),
                    ).then((_) {
                      // Refresh data when returning from debug page
                      _fetchUserData();
                    });
                  },
                ),
              ],
            ),
        body: SafeArea(
          child: Column(
            children: [
              // Messages List
              Expanded(
                child: messages.isEmpty 
                ? Center(
                    child: _isLoading 
                      ? CircularProgressIndicator() 
                      : Text("Type 'post job' to start creating a job listing"),
                  )
                : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? Colors.blue
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.isUser
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Loading indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
              
              // Message Input Area
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          fillColor: Colors.blue[50],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, 
                            vertical: 10.0
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.blue.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.blue.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendMessageToRasa(value);
                            _messageController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      onPressed: () {
                        final message = _messageController.text.trim();
                        if (message.isNotEmpty) {
                          _sendMessageToRasa(message);
                          _messageController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Theme.of(context).primaryColor,
          // Make sure items are visible
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black54,
          // Ensure labels are shown
          showSelectedLabels: true,
          showUnselectedLabels: true,
          // Increase the visibility
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.work),
              label: 'Manage Jobs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.update),
              label: 'Update Application',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Candidates',
            ),
          ],
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            
            switch (index) {
              case 0:
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => ManageJobsPage()),
                  (route) => false,
                );
                break;
              case 1:
                // Already on EmployerChatPage
                break;
              case 2:
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => UpdateStatusPage()),
                  (route) => false,
                );
                break;
              case 3:
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CandidateSearchPage()),
                  (route) => false,
                );
                break;
            }
          },
        ),
      );
    } catch (e, stackTrace) {
      print("ERROR IN EMPLOYER CHAT PAGE BUILD: $e");
      print("Stack trace: $stackTrace");
      return Scaffold(
        backgroundColor: Colors.red[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red[900], size: 48),
              const SizedBox(height: 16),
              Text(
                "Error building page",
                style: TextStyle(
                  color: Colors.red[900],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  e.toString(),
                  style: TextStyle(color: Colors.red[900]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}