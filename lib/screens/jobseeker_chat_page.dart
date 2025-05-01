// lib/screens/jobseeker_chat_page.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/services/rasa_chatbot_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/screens/Track_application_page.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'login.dart';

class JobSeekerChatPage extends StatefulWidget {
  const JobSeekerChatPage({Key? key}) : super(key: key);

  @override
  State<JobSeekerChatPage> createState() => _JobSeekerChatPageState();
}

class _JobSeekerChatPageState extends State<JobSeekerChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0; // Default to chat tab
  RasaChatbotService? _chatService;
  
  @override
  void initState() {
    super.initState();
    print("JobSeekerChatPage: initState called");
    
    // Initialize chat service with a delay to avoid build issues
    Future.delayed(Duration.zero, () {
      _initChatService();
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _initChatService() async {
    print("JobSeekerChatPage: Initializing chat service");
    
    try {
      // Get the current user ID from Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("No user logged in");
      }
      
      final userId = currentUser.uid;
      print("JobSeekerChatPage: Current user ID: $userId");
      
      // Create new instance of chatbot service
      _chatService = RasaChatbotService(userId: userId);
      
      // Add listener to scroll to bottom when new messages arrive
      _chatService!.addListener(() {
        _scrollToBottom();
      });
      
      // Initialize the chat service with user ID
      await _chatService!.initialize(userId: userId);
      
      print("JobSeekerChatPage: Chat service initialized successfully");
      
      // Force rebuild of the widget
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("JobSeekerChatPage: Error initializing chat service: $e");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to chat service: $e')),
        );
      }
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
  
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    if (_chatService != null) {
      _chatService!.sendMessage(message);
      _messageController.clear();
      // Force UI update
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat service not ready. Please wait...')),
      );
    }
  }
  
  // Improved logout method
  Future<void> _logout(BuildContext context) async {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Search Assistant'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Connection',
            onPressed: _initChatService,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status indicator (only show when not connected)
          if (_chatService != null && _chatService!.connectionStatus != ConnectionStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: _chatService!.connectionStatus == ConnectionStatus.connecting
                  ? Colors.orange
                  : Colors.red,
              child: Row(
                children: [
                  Icon(
                    _chatService!.connectionStatus == ConnectionStatus.connecting
                        ? Icons.sync
                        : Icons.error_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chatService!.connectionStatus == ConnectionStatus.connecting
                          ? 'Connecting to chat service...'
                          : 'Connection error. Tap the refresh button to retry.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          // Error message if any
          if (_chatService != null && _chatService!.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chatService!.errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          // Chat messages area
          Expanded(
            child: _chatService == null 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Connecting to chat service..."),
                  ],
                ),
              )
            : _chatService!.messages.isEmpty
              ? _buildEmptyChatState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _chatService!.messages.length,
                  itemBuilder: (context, index) {
                    return _buildChatMessage(_chatService!.messages[index]);
                  },
                ),
          ),
          
          // Loading indicator
          if (_chatService != null && _chatService!.isLoading)
            const LinearProgressIndicator(),
          
          // Message input area
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: const Offset(0, -1),
                  blurRadius: 3,
                )
              ],
            ),
            child: Column(
              children: [
                // Suggestion chips (when chat is empty)
                if (_chatService != null && _chatService!.messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildSearchSuggestionChips(),
                  ),
                  
                // Text input and send button
                Row(
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
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.white,
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes),
            label: 'Track Applications',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              // Already on JobSeekerChatPage
              break;
            case 1:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const TrackApplicationPage()),
                (route) => false,
              );
              break;
          }
        },
      ),
    );
  }
  
  Widget _buildChatMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: message.isUser ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchSuggestionChips() {
    return Wrap(
      spacing: 8.0,
      children: [
        _buildSuggestionChip('Find developer jobs'),
        _buildSuggestionChip('Jobs in KL'),
        _buildSuggestionChip('Python skills'),
        _buildSuggestionChip('Marketing jobs in PJ'),
      ],
    );
  }
  
  Widget _buildSuggestionChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.blue.shade100,
      onPressed: () {
        _messageController.text = label;
        _sendMessage();
      },
    );
  }
  
  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            "Welcome to JobBot!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "Ask me to find jobs by title, location, or skills. Try saying 'Find developer jobs in KL' or tap one of the suggestions below.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text("Search for Jobs"),
            onPressed: () {
              if (_chatService != null) {
                _chatService!.sendMessage("search for jobs");
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}