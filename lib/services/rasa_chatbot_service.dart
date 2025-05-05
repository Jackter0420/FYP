// lib/services/rasa_chatbot_service.dart
import 'dart:async';
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
  String? _userType;
  
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

    
  // Add these missing properties
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastInitializedUserId;
  
  // Constructor with default base URL for Android emulator
  RasaChatbotService({
    String? baseUrl,
    String? userId,
    String? userType,
  }) : _baseUrl = baseUrl ?? 'http://10.0.2.2:5006',
       _userId = userId,
       _userType = userType {
    print("RasaChatbotService created with baseUrl: $_baseUrl, userId: $_userId, userType: $_userType");
  }
  
  
void resetChat() {
    _messages = [];
    _errorMessage = null;
    
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hello! I'm your job search assistant. How can I help you today?",
      isUser: false,
    ));
    
    notifyListeners();
  }

// lib/services/rasa_chatbot_service.dart
void reset() {
  _messages = [];
  _connectionStatus = ConnectionStatus.disconnected;
  _isLoading = false;
  _errorMessage = null;
  _userId = null;
  _userType = null;
  
  // Only notify listeners if there are any and we haven't been disposed
  try {
    if (hasListeners) {
      notifyListeners();
    }
  } catch (e) {
    print('Error notifying listeners during reset: $e');
  }
}
  // Initialize the chat session
Future<void> initialize({String? userId, String? userType}) async {
  _setLoading(true);
  
  try {
    if (userId != null) {
      _userId = userId;
    }
    
    if (userType != null) {
      _userType = userType;
    }
    
    if (_userId == null) {
      throw Exception('User ID is required to initialize chat');
    }
    
    _setConnectionStatus(ConnectionStatus.connecting);
    
    int attempts = 0;
    const maxAttempts = 2;  // Reduced from 3 to 2
    bool connected = false;
    
    while (attempts < maxAttempts && !connected) {
      try {
        attempts++;
        print("Connection attempt $attempts of $maxAttempts");
        
        // Test connection with timeout
        final pingSuccess = await testConnection().timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
        
        if (!pingSuccess) {
          if (attempts < maxAttempts) {
            print("Connection failed, waiting before retry...");
            await Future.delayed(const Duration(seconds: 1));
            continue;
          } else {
            throw Exception('Could not connect to chat server');
          }
        }
        
        connected = true;
        print("Connection established successfully");
        
        // Send user ID to Rasa (also with timeout)
        await _sendUserIdToRasa().timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
        
      } catch (e) {
        print("Connection attempt $attempts failed: $e");
        if (attempts >= maxAttempts) {
          throw Exception('Failed to connect after $maxAttempts attempts');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    // Add initial welcome message only if not already present
    if (_messages.isEmpty) {
      _addMessage(
        "Hello! I'm your job search assistant. How can I help you today?",
        isUser: false
      );
    }
    
    _setConnectionStatus(ConnectionStatus.connected);
    
  } catch (e) {
    debugPrint('Error initializing chat: $e');
    _setErrorMessage('Connection error: Unable to reach the chat server');
    _setConnectionStatus(ConnectionStatus.error);
    
    // Add offline message
    if (_messages.isEmpty) {
      _addMessage(
        "I'm having trouble connecting to the server. You can still browse the app, but chat features may be limited.",
        isUser: false
      );
    }
  } finally {
    _setLoading(false);
  }
}
  // Set the user ID in Rasa
  Future<bool> _sendUserIdToRasa() async {
    if (_userId == null) {
      _setErrorMessage('No user ID available');
      return false;
    }
    
    try {
      print("Setting user ID in Rasa: $_userId");
      
      // Explicitly format the set_user_id command with proper JSON format
      final setUserIdCommand = '/set_user_id{"user_id": "$_userId"' + 
        (_userType != null ? ', "user_type": "$_userType"' : '') + '}';
      
      print('Sending user ID command to Rasa: $setUserIdCommand');
      
      // Send the command with metadata
      final response = await http.post(
        Uri.parse('$_baseUrl/webhooks/rest/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _userId,
          'message': setUserIdCommand,
          'metadata': {
            'user_id': _userId,
            'user_type': _userType,
          }
        }),
      );
      
      print('User ID command response: ${response.statusCode} - ${response.body}');
      
      // Check if command was successful
      return response.statusCode == 200;
    } catch (e) {
      print("Error sending user ID to Rasa: $e");
      return false;
    }
  }
  
  // Send a message to the Rasa server with improved error handling and duplicate prevention
// In rasa_chatbot_service.dart - Fix the message processing to handle custom data properly

  // Send a message to the Rasa server with improved error handling and duplicate prevention
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _userId == null) return;
    
    // Add user message to chat immediately 
    _addMessage(text, isUser: true);
    _setLoading(true);
    _clearError();
    
    // Maximum number of retries
    const maxRetries = 2;
    int retryCount = 0;
    bool success = false;
    
    while (retryCount <= maxRetries && !success) {
      try {
        // Check connection status before sending
        if (_connectionStatus != ConnectionStatus.connected && 
            _connectionStatus != ConnectionStatus.connecting) {
          await testConnection();
        }
        
        // Prepare the request with metadata
        final response = await http.post(
          Uri.parse('$_baseUrl/webhooks/rest/webhook'),  // Make sure this is the correct URL
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sender': _userId,
            'message': text,
            'metadata': {
              'user_id': _userId,
              'user_type': _userType,
            }
          }),
        ).timeout(const Duration(seconds: 10));
        
        // Check for HTTP errors
        if (response.statusCode != 200) {
          throw Exception('HTTP error ${response.statusCode}: ${response.body}');
        }
        
        // Parse and process the response
        final List<dynamic> responseData = jsonDecode(response.body);
        
        print("=== RASA RESPONSE DATA ===");
        print("Response count: ${responseData.length}");
        
        if (responseData.isEmpty) {
          // If Rasa returns an empty response
          _addMessage(
            "I'm not sure how to respond to that. Try asking about job searches or say 'help' for guidance.",
            isUser: false
          );
        } else {
          // Process all response messages from Rasa
          for (var msg in responseData) {
            print("Processing message: ${json.encode(msg)}");
            
            // Check if this is a message with only custom data
            if (!msg.containsKey('text') && msg.containsKey('custom')) {
              // Handle messages that only have custom data
              Map<String, dynamic>? customData = msg['custom'] as Map<String, dynamic>?;
              
              if (customData != null && customData['type'] == 'job_search_results') {
                // For job search results, we use the search criteria as the text
                String messageText = "Job search results";
                _addMessage(
                  messageText,
                  isUser: false,
                  jsonData: customData
                );
                print("Added job search results message with custom data");
              }
              continue;
            }
            
            // Handle regular messages with text
            if (msg.containsKey('text')) {
              String messageText = msg['text'];
              
              // Check if message has custom data
              Map<String, dynamic>? jsonData;
              if (msg.containsKey('custom')) {
                jsonData = msg['custom'] as Map<String, dynamic>?;
                print("Found custom data: $jsonData");
              }
              
              _addMessage(
                messageText,
                isUser: false,
                jsonData: jsonData
              );
            }
          }
        }
        
        success = true;
      } catch (e) {
        debugPrint('Error sending message to Rasa (attempt ${retryCount + 1}): $e');
        retryCount++;
        
        if (retryCount > maxRetries) {
          _setErrorMessage('Error communicating with the chatbot: $e');
          _addMessage(
            "Sorry, I'm having trouble connecting to the server. Please try again later.",
            isUser: false
          );
        } else {
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      } finally {
        _setLoading(false);
      }
    }
  }
  
  // Test the connection to the Rasa server with improved error handling
 Future<bool> testConnection() async {
  if (_userId == null) return false;
  
  try {
    _setConnectionStatus(ConnectionStatus.connecting);
    print("Testing connection to Rasa server at $_baseUrl");
    
    // Send a simple ping message with a shorter timeout
    final response = await http.post(
      Uri.parse('$_baseUrl/webhooks/rest/webhook'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': _userId ?? 'test_user',
        'message': '/ping',  // Changed from 'ping' to '/ping' to ensure it's recognized
      }),
    ).timeout(
      const Duration(seconds: 3),  // Reduced from 5 to 3 seconds
      onTimeout: () {
        throw TimeoutException('Connection test timed out');
      },
    );
    
    print("Connection test response: ${response.statusCode}");
    
    if (response.statusCode == 200) {
      _setConnectionStatus(ConnectionStatus.connected);
      return true;
    } else {
      _setConnectionStatus(ConnectionStatus.error);
      return false;
    }
  } catch (e) {
    print('Connection test failed: $e');
    _setConnectionStatus(ConnectionStatus.error);
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
  
  // Reconnect to the chatbot service
  Future<bool> reconnect() async {
    _setConnectionStatus(ConnectionStatus.connecting);
    _clearError();
    
    try {
      // Try to send user ID again
      final success = await _sendUserIdToRasa();
      if (success) {
        _setConnectionStatus(ConnectionStatus.connected);
        return true;
      } else {
        _setConnectionStatus(ConnectionStatus.error);
        return false;
      }
    } catch (e) {
      debugPrint('Error reconnecting: $e');
      _setConnectionStatus(ConnectionStatus.error);
      return false;
    }
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