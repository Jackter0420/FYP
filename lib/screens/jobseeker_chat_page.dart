// lib/screens/jobseeker_chat_page.dart - PART 1
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prototype_2/screens/job_recommendations_page.dart';
import 'package:prototype_2/widgets/jobseeker_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:prototype_2/screens/jobseeker_profile_edit_page.dart';
import 'package:prototype_2/services/rasa_chatbot_service.dart';
import 'package:prototype_2/services/job_application_service.dart';
import 'package:prototype_2/screens/Track_application_page.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'login.dart';

class JobSeekerChatPage extends StatefulWidget {
  const JobSeekerChatPage({Key? key}) : super(key: key);

  @override
  State<JobSeekerChatPage> createState() => _JobSeekerChatPageState();
}

class _JobSeekerChatPageState extends State<JobSeekerChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0; // Default to chat tab
  RasaChatbotService? _chatService;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initError;
  
  // Add state for tracking application status
  Map<String, bool> _applicationStatus = {};
  Set<String> _appliedJobIds = {}; // Track all applied job IDs
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChatService();
      _loadAppliedJobs();
    });
  }
  
@override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    if (_chatService != null) {
      _chatService!.removeListener(_onChatServiceUpdate);
    }
    super.dispose();
  }
    
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh applied jobs when app comes back to foreground
      _loadAppliedJobs();
    }
  }
  
  // Initialize chat service with improved error handling and better URL configuration

// Update the _initChatService method in jobseeker_chat_page.dart
Future<void> _initChatService() async {
  print("JobSeekerChatPage: Initializing chat service");
  if (_isInitializing) return;
  
  if (!mounted) return;
  
  setState(() {
    _isInitializing = true;
    _initError = null;
  });
  
  try {
    // Get the current user ID from Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    
    String userId;
    if (currentUser == null) {
      print("JobSeekerChatPage: No user logged in, using anonymous ID");
      userId = "anonymous_user_${DateTime.now().millisecondsSinceEpoch}";
    } else {
      userId = currentUser.uid;
      print("JobSeekerChatPage: Current user ID: $userId");
    }
    
    // Create or get chat service instance
    if (_chatService == null) {
      try {
        _chatService = Provider.of<RasaChatbotService>(context, listen: false);
        print("JobSeekerChatPage: Retrieved RasaChatbotService from Provider");
      } catch (e) {
        print("JobSeekerChatPage: Creating new RasaChatbotService instance");
        _chatService = RasaChatbotService(
          baseUrl: 'http://10.0.2.2:5006', 
          userId: userId,
          userType: "jobseeker"
        );
      }
      
      _chatService!.addListener(_onChatServiceUpdate);
    }
    
    print("JobSeekerChatPage: Initializing chat service with userId: $userId");
    
    // Initialize with error handling
    try {
      await _chatService!.initialize(
        userId: userId,
        userType: 'jobseeker',
      );
      print("JobSeekerChatPage: Chat service initialized successfully");
    } catch (e) {
      print("JobSeekerChatPage: Chat initialization failed: $e");
      // Continue anyway - the app should still be usable
    }
    
    if (!mounted) return;
    
    setState(() {
      _isInitialized = true;
      _isInitializing = false;
      _initError = null;
    });
    
  } catch (e) {
    print("JobSeekerChatPage: Error in _initChatService: $e");
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _isInitializing = false;
        _initError = e.toString();
      });
      
      // Show error but don't block the app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat service is offline. You can still use other features.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
  
// Chat service listener callback
  void _onChatServiceUpdate() {
    if (!mounted) return;
    
    _scrollToBottom();
    // Don't call _loadAppliedJobs here as it causes recursion
    setState(() {});
  }

  // Scroll to bottom of chat
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
  
  // Send message with error handling
  void _sendMessage([String? messageText]) {
    final message = messageText ?? _messageController.text.trim();
    if (message.isEmpty) return;
    
    if (_chatService != null) {
      try {
        _chatService!.sendMessage(message);
        if (messageText == null) _messageController.clear();
      } catch (e) {
        print("Error sending message: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Message could not be sent. Please try again.")),
        );
      }
    } else {
      _showNotReadyMessage();
    }
  }
  
  // Show error if chat service is not ready
  void _showNotReadyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_initError != null 
          ? 'Error: $_initError. Try reconnecting.'
          : 'Chat service not ready. Please wait...'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _initChatService,
        ),
      ),
    );
  }
  
  // Improved logout method
  void _logout(BuildContext context) async {
  try {
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
    
    if (confirm == true && mounted) {
      // Stop listening to chat service updates BEFORE navigation
      if (_chatService != null) {
        _chatService!.removeListener(_onChatServiceUpdate);
        _chatService!.reset();
      }
      
      // Get the user provider before navigation
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Navigate away immediately
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
      
      // Sign out after navigation is complete
      userProvider.signOut();
    }
  } catch (e) {
    print("Error during logout: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error logging out: $e")),
      );
    }
  }
}
  
  // Load previously applied jobs
Future<void> _loadAppliedJobs() async {
  try {
    final applications = await JobApplicationService.getMyApplications();
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    
    setState(() {
      _appliedJobIds = applications.map((app) => app.jobId).toSet();
      // Update application status map
      _applicationStatus.clear();
      for (var jobId in _appliedJobIds) {
        _applicationStatus[jobId] = true;
      }
    });
  } catch (e) {
    print('Error loading applied jobs: $e');
  }
}
  
  // Build chat message or job card based on message type
  Widget _buildMessageOrJobCard(ChatMessage message) {
    // Debug: Print message data
    print("=== BUILDING MESSAGE/JOB CARD ===");
    print("Message text: ${message.text}");
    print("Is user: ${message.isUser}");
    print("Has JSON data: ${message.jsonData != null}");
    
    if (message.jsonData != null) {
      print("JSON data type: ${message.jsonData!['type']}");
      print("JSON data total_results: ${message.jsonData!['total_results']}");
      print("JSON data jobs count: ${(message.jsonData!['jobs'] as List?)?.length ?? 0}");
    }
    
    // Check if this is a job search results message
    if (!message.isUser && message.jsonData != null && 
        message.jsonData!['type'] == 'job_search_results') {
      print("Building job search results card");
      return _buildJobSearchResultsCard(message.jsonData!);
    }
    
    // Regular chat message
    print("Building regular chat message");
    return _buildChatMessage(message);
  }

// lib/screens/jobseeker_chat_page.dart - PART 2
  // Build job search results as a card with job listings
  Widget _buildJobSearchResultsCard(Map<String, dynamic> jsonData) {
    final jobs = List<Map<String, dynamic>>.from(jsonData['jobs'] ?? []);
    final totalResults = jsonData['total_results'] ?? 0;
    final currentPage = jsonData['current_page'] ?? 1;
    final totalPages = jsonData['total_pages'] ?? 1;
    final searchCriteria = jsonData['search_criteria'] ?? 'your search';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found $totalResults jobs matching $searchCriteria',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Page $currentPage of $totalPages',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 20),
            
            ...jobs.map((job) => _buildJobCard(job)).toList(),
            
            if (totalPages > 1) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentPage > 1)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      onPressed: () => _sendMessage('previous'),
                    ),
                  if (currentPage < totalPages)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                      onPressed: () => _sendMessage('next'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Build individual job card
  Widget _buildJobCard(Map<String, dynamic> job) {
    final jobId = job['id'] ?? '';
    final jobTitle = job['job_title'] ?? 'No Title';
    final companyName = job['company_name'] ?? 'Unknown Company';
    final location = job['job_location'] ?? 'No Location';
    final skills = job['job_skills'] ?? 'Not specified';
    final description = job['job_description'] ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildApplyButton(jobId, jobTitle, companyName),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(location),
              ],
            ),
            const SizedBox(height: 4),
            
            Row(
              children: [
                const Icon(Icons.build, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    skills,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showJobDetailsDialog(job),
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build apply button with status tracking
  Widget _buildApplyButton(String jobId, String jobTitle, String companyName) {
    final isApplied = _applicationStatus[jobId] ?? _appliedJobIds.contains(jobId);
    
    if (isApplied) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Applied'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          disabledBackgroundColor: Colors.green,
          disabledForegroundColor: Colors.white,
        ),
        onPressed: null, // Disabled
      );
    }
    
    return ElevatedButton.icon(
      icon: const Icon(Icons.send),
      label: const Text('Apply'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
      ),
      onPressed: () => _showApplyDialog(jobId, jobTitle, companyName),
    );
  }
  
  // Show job details dialog
  void _showJobDetailsDialog(Map<String, dynamic> job) {
    final jobId = job['id'] ?? '';
    final jobTitle = job['job_title'] ?? 'No Title';
    final companyName = job['company_name'] ?? 'Unknown Company';
    final location = job['job_location'] ?? 'No Location';
    final skills = job['job_skills'] ?? 'Not specified';
    final description = job['job_description'] ?? 'No description available';
    final postDate = job['post_date'] ?? '';
    
    String formattedDate = 'Recently';
    if (postDate.isNotEmpty) {
      try {
        final date = DateTime.parse(postDate);
        formattedDate = DateFormat('MMMM d, yyyy').format(date);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }
    
    final isApplied = _applicationStatus[jobId] ?? _appliedJobIds.contains(jobId);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(jobTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Company', companyName),
                const SizedBox(height: 8),
                _buildDetailRow('Location', location),
                const SizedBox(height: 8),
                _buildDetailRow('Required Skills', skills),
                const SizedBox(height: 8),
                _buildDetailRow('Posted', formattedDate),
                const SizedBox(height: 16),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (!isApplied)
              ElevatedButton(
                child: const Text('Apply Now'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showApplyDialog(jobId, jobTitle, companyName);
                },
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Applied'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.green,
                  disabledForegroundColor: Colors.white,
                ),
                onPressed: null,
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
  
  // Show apply dialog with cover letter input and resume upload
  void _showApplyDialog(String jobId, String jobTitle, String companyName) {
    final coverLetterController = TextEditingController();
    File? selectedResume;
    String? resumeFileName;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Apply for $jobTitle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Company: $companyName'),
                    const SizedBox(height: 16),
                    
                    // Cover Letter Input
                    TextField(
                      controller: coverLetterController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Cover Letter',
                        hintText: 'Write a brief cover letter...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Resume Upload Section
                    const Text(
                      'Resume (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Show selected file or upload button
                    if (selectedResume != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                resumeFileName ?? 'resume.pdf',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  selectedResume = null;
                                  resumeFileName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Resume (PDF)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: () async {
                          try {
                            FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                            
                            if (result != null) {
                              setState(() {
                                selectedResume = File(result.files.single.path!);
                                resumeFileName = result.files.single.name;
                              });
                            }
                          } catch (e) {
                            print('Error picking file: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error selecting file: $e')),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Submit Application'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _submitApplication(
                      jobId,
                      coverLetterController.text,
                      selectedResume,
                      resumeFileName,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Submit job application with resume upload
// Enhanced resume upload method with better error handling

Future<void> _submitApplication(String jobId, String coverLetter, File? resume, String? resumeFileName) async {
  try {
    print('=== STARTING APPLICATION SUBMISSION ===');
    print('Job ID: $jobId');
    print('Has Resume File: ${resume != null}');
    print('Resume Filename: $resumeFileName');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
    
    String? resumeUrl;
    
    // Check if we have a resume to upload
    if (resume != null && resumeFileName != null) {
      print('=== STARTING RESUME UPLOAD ===');
      
      try {
        // Verify Firebase Auth
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }
        print('Current User ID: ${currentUser.uid}');
        
        // Verify file exists and is accessible
        if (!await resume.exists()) {
          throw Exception('Resume file does not exist at path: ${resume.path}');
        }
        
        // Get file info for debugging
        final fileSize = await resume.length();
        print('Resume file path: ${resume.path}');
        print('Resume file size: $fileSize bytes');
        
        if (fileSize == 0) {
          throw Exception('Resume file is empty');
        }
        
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Resume file exceeds 10MB limit');
        }
        
        // Create filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final sanitizedFileName = resumeFileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final fileName = '${currentUser.uid}_${timestamp}_$sanitizedFileName';
        
        // Create storage reference
        final storageRef = FirebaseStorage.instance.ref();
        final resumeRef = storageRef.child('resumes').child(fileName);
        print('Storage path: resumes/$fileName');
        
        // Set metadata
        final metadata = SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'jobId': jobId,
          },
        );
        
        try {
          // Attempt upload with putFile
          print('Attempting upload with putFile...');
          final uploadTask = resumeRef.putFile(resume, metadata);
          
          // Monitor upload
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              double progress = snapshot.bytesTransferred / snapshot.totalBytes;
              print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            },
            onError: (error) {
              print('Upload stream error: $error');
            },
          );
          
          // Wait for completion
          final snapshot = await uploadTask;
          
          if (snapshot.state == TaskState.success) {
            resumeUrl = await snapshot.ref.getDownloadURL();
            print('Upload successful! URL: $resumeUrl');
          } else {
            throw Exception('Upload failed with state: ${snapshot.state}');
          }
          
        } catch (putFileError) {
          print('putFile failed: $putFileError');
          
          // Try alternative upload method
          try {
            print('Attempting alternative upload with putData...');
            final bytes = await resume.readAsBytes();
            print('Read ${bytes.length} bytes');
            
            final uploadTask = resumeRef.putData(bytes, metadata);
            final snapshot = await uploadTask;
            
            if (snapshot.state == TaskState.success) {
              resumeUrl = await snapshot.ref.getDownloadURL();
              print('Alternative upload successful! URL: $resumeUrl');
            } else {
              throw Exception('Alternative upload also failed');
            }
          } catch (putDataError) {
            print('putData also failed: $putDataError');
            throw putDataError;
          }
        }
        
      } catch (e, stackTrace) {
        print('ERROR during resume upload: $e');
        print('Stack trace: $stackTrace');
        
        // Show warning but continue with application submission
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume upload failed. Submitting application without resume.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
    
    // Submit application even if resume upload failed
    print('=== SUBMITTING APPLICATION DATA ===');
    print('Resume URL: ${resumeUrl ?? "none"}');
    
    final result = await JobApplicationService.submitApplication(
      jobId: jobId,
      coverLetter: coverLetter,
      resumeUrl: resumeUrl,
    );
    
    print('Application submission result: $result');
    
    // Close loading dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    if (result['success']) {
      if (!mounted) return;
      
      setState(() {
        _applicationStatus[jobId] = true;
        _appliedJobIds.add(jobId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resumeUrl != null 
              ? 'Application submitted with resume!' 
              : 'Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit application'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
  } catch (e, stackTrace) {
    print('ERROR in _submitApplication: $e');
    print('Stack trace: $stackTrace');
    
    // Close loading dialog if still open
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  
  // Build regular chat message
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
  
  // Build empty chat state or welcome message
  Widget _buildWelcomeMessage() {
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
              "Ask me to find jobs by title, location, or skills. Try saying 'Find developer jobs in KL' or tap search button below.",
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
              } else {
                _showNotReadyMessage();
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


Future<void> _refreshChat() async {
  if (_isInitializing) {
    print("JobSeekerChatPage: Already initializing, skipping refresh...");
    return;
  }
  
  print("JobSeekerChatPage: Refreshing chat...");
  
  try {
    // Simply reset the chat if service exists
    if (_chatService != null) {
      _chatService!.resetChat();
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat refreshed'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    print("JobSeekerChatPage: Error refreshing chat: $e");
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh chat'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
  
  @override
  Widget build(BuildContext context) {
    bool hasMessages = _chatService != null && 
                      _chatService!.messages.isNotEmpty;
    
    return Scaffold(
      appBar: JobSeekerAppBar(
      title: 'Job Search Assistant',
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Chat',
          onPressed: _isInitializing ? null : _refreshChat,
        ),
      ],
      ),
      body: Column(
        children: [
          // Connection status indicator (only show when there's a problem)
          if (_chatService != null && 
              _chatService!.connectionStatus != ConnectionStatus.connected && 
              !_isInitializing)
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
                          : 'Connection error. Tap to retry.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    onPressed: _initChatService,
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
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chatService!.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          // Chat messages area or welcome message
          Expanded(
            child: _isInitializing && !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : !hasMessages
                    ? _buildWelcomeMessage()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _chatService!.messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageOrJobCard(_chatService!.messages[index]);
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
                        borderSide: const BorderSide(color: Colors.blue),
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
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.blue,
                    onPressed: () => _sendMessage(),
                  ),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend),
            label: 'Job Matches',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              // Already on chat page
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TrackApplicationPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const JobRecommendationPage()),
              );
              break;
          }
        },
      ),
    );
  }
}