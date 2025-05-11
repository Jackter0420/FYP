// lib/screens/jobseeker_recommendations_page.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/jobseeker_chat_page.dart';
import 'package:prototype_2/screens/Track_application_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/widgets/jobseeker_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/services/recommendation_service.dart';
import 'package:prototype_2/services/job_application_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class JobRecommendationPage extends StatefulWidget {
  const JobRecommendationPage({Key? key}) : super(key: key);

  @override
  State<JobRecommendationPage> createState() => _JobRecommendationPageState();
}

class _JobRecommendationPageState extends State<JobRecommendationPage> {
  int _currentIndex = 2; // New navigation index for recommendations
  bool _isLoading = true;
  List<JobMatch> _recommendedJobs = [];
  Map<String, bool> _applicationStatus = {}; // Tracks if user has applied to jobs

  @override
  void initState() {
    super.initState();
    _fetchRecommendedJobs();
    _loadAppliedJobs();
  }

 Future<void> _fetchRecommendedJobs() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // The RecommendationService now automatically filters out expired jobs
    final recommendations = await RecommendationService.getRecommendedJobsForJobSeeker();

    setState(() {
      _recommendedJobs = recommendations;
      _isLoading = false;
    });
  } catch (e) {
    print("Error fetching job recommendations: $e");
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<void> _loadAppliedJobs() async {
    try {
      final applications = await JobApplicationService.getMyApplications();
      
      Map<String, bool> appliedStatus = {};
      for (var app in applications) {
        appliedStatus[app.jobId] = true;
      }
      
      setState(() {
        _applicationStatus = appliedStatus;
      });
    } catch (e) {
      print("Error loading applied jobs: $e");
    }
  }

  Future<void> _applyForJob(JobMatch match) async {
    // Show application dialog
    showDialog(
      context: context,
      builder: (context) => _buildApplyDialog(match),
    );
  }

  Widget _buildApplyDialog(JobMatch match) {
    final TextEditingController coverLetterController = TextEditingController();
    File? selectedResume;
    String? resumeFileName;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Apply for ${match.jobTitle}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Company: ${match.companyName}'),
                const SizedBox(height: 4),
                Text('Match: ${match.matchPercentage.toInt()}%'),
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
                  match.jobId, 
                  coverLetterController.text,
                  selectedResume,
                  resumeFileName
                );
              },
            ),
          ],
        );
      }
    );
  }

  Future<void> _submitApplication(String jobId, String coverLetter, File? resume, String? resumeFileName) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );
      
      String? resumeUrl;
      
      // Upload resume if selected
      if (resume != null && resumeFileName != null) {
        try {
          // Verify Firebase Auth
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            throw Exception('User not authenticated');
          }
          
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
          
        } catch (e) {
          print('ERROR during resume upload: $e');
          
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
      
      // Submit application with or without resume URL
      final result = await JobApplicationService.submitApplication(
        jobId: jobId,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
      );
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (result['success']) {
        setState(() {
          // Update application status locally
          _applicationStatus[jobId] = true;
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
              content: Text(result['message'] ?? 'Failed to submit application.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print("Error submitting application: $e");
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
  
  Color _getMatchColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.blue;
    } else if (percentage >= 40) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
  
  // Show job details dialog
void _showJobDetailsDialog(JobMatch match) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.jobTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        match.companyName,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getMatchColor(match.matchPercentage),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${match.matchPercentage.toInt()}% Match',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    if (match.jobData.containsKey('job_location') && 
                        match.jobData['job_location'] != null) ...[
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              match.jobData['job_location'].toString(),
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Required Skills section
                    Text(
                      'Required Skills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: match.jobRequiredSkills.map((skill) {
                        final isMatchingSkill = match.jobSeekerSkills.any(
                          (seekerSkill) => seekerSkill.toLowerCase().contains(skill.toLowerCase()) || 
                                    skill.toLowerCase().contains(seekerSkill.toLowerCase())
                        );
                        
                        return Chip(
                          label: Text(skill),
                          backgroundColor: isMatchingSkill 
                              ? Colors.green.withOpacity(0.2) 
                              : Colors.red.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: isMatchingSkill ? Colors.green[800] : Colors.red[800],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description section
                    Text(
                      'Job Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match.jobData['job_description']?.toString() ?? 'No description provided.',
                    ),
                    const SizedBox(height: 16),
                    
                    // Post date
                    if (match.jobData.containsKey('post_date') && 
                        match.jobData['post_date'] != null && 
                        match.jobData['post_date'].toString().isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Posted: ${_formatDate(match.jobData['post_date'].toString())}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Match details section
                    Text(
                      'Match Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.grey[100],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Skills:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(match.jobSeekerSkills.join(', ')),
                            const SizedBox(height: 8),
                            Text('Job Skills:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(match.jobRequiredSkills.join(', ')),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: match.matchPercentage / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(_getMatchColor(match.matchPercentage)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${match.matchPercentage.toInt()}% Overall Match',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getMatchColor(match.matchPercentage),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(_applicationStatus[match.jobId] == true 
                            ? Icons.check 
                            : Icons.send),
                  label: Text(_applicationStatus[match.jobId] == true 
                            ? 'Applied' 
                            : 'Apply Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _applicationStatus[match.jobId] == true 
                                   ? Colors.green 
                                   : Theme.of(context).primaryColor,
                  ),
                  onPressed: _applicationStatus[match.jobId] == true 
                          ? null 
                          : () {
                              Navigator.pop(context);
                              _applyForJob(match);
                            },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFE7E7E7),
    appBar: JobSeekerAppBar(
      title: 'Recommended Jobs',
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            _fetchRecommendedJobs();
            _loadAppliedJobs();
          },
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _recommendedJobs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No job recommendations yet",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Complete your profile with more skills and job preferences to get recommendations",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
                          );
                        },
                        child: const Text("Search Jobs Manually"),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: _recommendedJobs.length,
                itemBuilder: (context, index) {
                  final match = _recommendedJobs[index];
                  final isApplied = _applicationStatus[match.jobId] == true;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _showJobDetailsDialog(match),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        match.jobTitle,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        match.companyName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Match percentage badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getMatchColor(match.matchPercentage),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${match.matchPercentage.toInt()}% Match',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            if (match.jobData.containsKey('job_location') && 
                                match.jobData['job_location'] != null)
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(match.jobData['job_location'].toString()),
                                ],
                              ),
                            const SizedBox(height: 8),
                            
                            Text(
                              'Required Skills:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: match.jobRequiredSkills.map((skill) {
                                final isMatchingSkill = match.jobSeekerSkills.any(
                                  (seekerSkill) => seekerSkill.toLowerCase().contains(skill.toLowerCase()) || 
                                            skill.toLowerCase().contains(seekerSkill.toLowerCase())
                                );
                                
                                return Chip(
                                  label: Text(skill),
                                  backgroundColor: isMatchingSkill 
                                      ? Colors.green.withOpacity(0.2) 
                                      : Colors.grey.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: isMatchingSkill ? Colors.green[800] : Colors.black87,
                                    fontSize: 12,
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity(horizontal: -2, vertical: -2),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            
                            // Job description preview
                            if (match.jobData.containsKey('job_description') && 
                                match.jobData['job_description'] != null &&
                                match.jobData['job_description'].toString().isNotEmpty)
                              Text(
                                match.jobData['job_description'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14),
                              ),
                            
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Post date
                                if (match.jobData.containsKey('post_date') && 
                                    match.jobData['post_date'] != null)
                                  Text(
                                    'Posted: ${_formatDate(match.jobData['post_date'].toString())}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                
                                // Action buttons
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('Details'),
                                      onPressed: () => _showJobDetailsDialog(match),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: Icon(isApplied ? Icons.check : Icons.send),
                                      label: Text(isApplied ? 'Applied' : 'Apply'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isApplied 
                                            ? Colors.green 
                                            : Theme.of(context).primaryColor,
                                      ),
                                      onPressed: isApplied ? null : () => _applyForJob(match),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
          label: 'Recommended Jobs',
        ),
      ],
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrackApplicationPage()),
            );
            break;
          case 2:
            // Already on this page
            break;
        }
      },
    ),
  );
}
}