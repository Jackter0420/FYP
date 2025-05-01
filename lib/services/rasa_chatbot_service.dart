// lib/services/rasa_chatbot_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? jsonData;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.jsonData,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error
}

class RasaChatbotService with ChangeNotifier {
  // Server URLs - Update these with your actual Rasa server address
  final String _baseUrl;
  
  // User data
  String? _userId;
  
  // State data
  List<ChatMessage> _messages = [];
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ConnectionStatus get connectionStatus => _connectionStatus;
  
  // Constructor with default base URL for Android emulator
  RasaChatbotService({
    String? baseUrl,
    String? userId,
  }) : _baseUrl = baseUrl ?? 'http://10.0.2.2:500',
       _userId = userId {
    print("RasaChatbotService created with baseUrl: $_baseUrl, userId: $_userId");
  }
  
  // Initialize the chat session
  Future<void> initialize({String? userId}) async {
    _setLoading(true);
    
    try {
      // Update userId if provided
      if (userId != null) {
        _userId = userId;
        print("RasaChatbotService: Setting userId to $_userId");
      }
      
      // Ensure we have a userId
      if (_userId == null) {
        throw Exception('User ID is required to initialize chat');
      }
      
      _setConnectionStatus(ConnectionStatus.connecting);
      
      // Add initial welcome message
      _addMessage(
        "Hello! I'm your job search assistant. How can I help you today?",
        isUser: false
      );
      
      // First test basic connection
      final pingSuccess = await testConnection();
      if (!pingSuccess) {
        print("Connection test failed, but will still try to set user ID");
      }
      
      // Then try to set user ID in Rasa
      await _setUserIdInRasa();
      
      _setConnectionStatus(ConnectionStatus.connected);
      print("Chat connection established successfully");
      
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _setErrorMessage('Failed to initialize chat: $e');
      _setConnectionStatus(ConnectionStatus.error);
    } finally {
      _setLoading(false);
    }
  }
  
  // Set the user ID in Rasa
  Future<bool> _setUserIdInRasa() async {
    if (_userId == null) {
      _setErrorMessage('No user ID available');
      return false;
    }
    
    try {
      print("Setting user ID in Rasa: $_userId");
      
      // Explicitly use the /set_user_id intent with the user ID
      final response = await http.post(
        Uri.parse('$_baseUrl/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId,
          'message': '/set_user_id{"user_id": "$_userId"}'
        }),
      );
      
      // Check the response
      if (response.statusCode == 200) {
        print("User ID set successfully in Rasa: $_userId");
        print("Rasa response: ${response.body}");
        return true;
      } else {
        print("Failed to set user ID in Rasa: HTTP ${response.statusCode}");
        print("Response: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error setting user ID in Rasa: $e");
      return false;
    }
  }
  
  // Send a message to the Rasa server
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _userId == null) return;
    
    // Add user message to chat immediately 
    _addMessage(text, isUser: true);
    _setLoading(true);
    _clearError();
    
    try {
      print("Sending message to Rasa: '$text' from user: $_userId");
      
      // Prepare the request
      final response = await http.post(
        Uri.parse('$_baseUrl/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId,
          'message': text,
        }),
      );
      
      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}: ${response.body}');
      }
      
      print("Received response from Rasa: ${response.body}");
      
      // Parse and process the response
      final List<dynamic> responseData = jsonDecode(response.body);
      
      if (responseData.isEmpty) {
        // If Rasa returns an empty response but we sent "search job"
        if (text.toLowerCase().contains("search") && text.toLowerCase().contains("job")) {
          _addMessage(
            "I can help you find jobs. What type of job are you looking for? You can search by job title, location, skills, or company.",
            isUser: false
          );
        } else {
          // Default message for empty responses
          _addMessage(
            "I'm not sure how to respond to that. Try asking about job searches or say 'help' for guidance.",
            isUser: false
          );
        }
      } else {
        // Process all response messages from Rasa
        for (var msg in responseData) {
          if (msg.containsKey('text')) {
            _addMessage(
              msg['text'],
              isUser: false,
              jsonData: msg.containsKey('json_message') ? msg['json_message'] : null
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error sending message to Rasa: $e');
      _setErrorMessage('Error communicating with the chatbot: $e');
      _addMessage(
        "Sorry, I'm having trouble connecting to the server. Please try again later.",
        isUser: false
      );
    } finally {
      _setLoading(false);
    }
  }
  
  // Test the connection to the Rasa server
  Future<bool> testConnection() async {
    if (_userId == null) return false;
    
    try {
      print("Testing connection to Rasa server");
      
      // Send a simple ping message
      final response = await http.post(
        Uri.parse('$_baseUrl/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId ?? 'test_user',
          'message': 'ping',
        }),
      );
      
      print("Connection test response: ${response.statusCode}");
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
  
  // Process job search results - helper method to extract jobs from messages
  List<Map<String, dynamic>> getJobSearchResults() {
    for (var message in _messages.reversed) {
      if (!message.isUser && message.jsonData != null) {
        final jsonData = message.jsonData!;
        
        // Check if this message contains job search results
        if (jsonData.containsKey('type') && 
            jsonData['type'] == 'job_search_results' &&
            jsonData.containsKey('jobs')) {
          
          try {
            final jobsList = jsonData['jobs'];
            if (jobsList is List) {
              return List<Map<String, dynamic>>.from(jobsList);
            }
          } catch (e) {
            debugPrint('Error parsing job results: $e');
          }
        }
      }
    }
    return [];
  }
  
  // Clear all messages
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
  
  // Private helper methods
  void _addMessage(String text, {required bool isUser, Map<String, dynamic>? jsonData}) {
    _messages.add(ChatMessage(
      text: text,
      isUser: isUser,
      jsonData: jsonData,
    ));
    print("Added message to chat: '$text' (isUser: $isUser)");
    notifyListeners();
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  void _setConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    notifyListeners();
  }
}