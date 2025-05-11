import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prototype_2/models/interview_slot.dart';
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/screens/candidate_search_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/update_status_page.dart';
import 'package:prototype_2/widgets/employer_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:prototype_2/widgets/interview_slot_selector.dart';
import 'package:prototype_2/models/interview_slot.dart';


class ManageJobsPage extends StatefulWidget {
  @override
  State<ManageJobsPage> createState() => _ManageJobsPageState();
}

class _ManageJobsPageState extends State<ManageJobsPage> {
  int _currentIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> jobs = [];
  
  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  // Helper function to format timestamp into readable format
  String formatJobTimestamp(String timestamp) {
    try {
      // Parse the ISO timestamp from Firestore
      DateTime postDate = DateTime.parse(timestamp);
      
      // Get the current time
      DateTime now = DateTime.now();
      
      // Calculate the difference
      Duration difference = now.difference(postDate);
      
      // Format based on how long ago the job was posted
      if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      print("Error formatting timestamp: $e");
      return 'Recently';
    }
  }
  
  // Format deadline date for display
  String formatDeadline(String deadlineStr) {
    try {
      if (deadlineStr.isEmpty) return 'No deadline';
      
      DateTime deadline = DateTime.parse(deadlineStr);
      return DateFormat('MMM d, yyyy').format(deadline);
    } catch (e) {
      print("Error formatting deadline: $e");
      return 'Invalid date';
    }
  }
  
  // Check if job is active based on deadline
  bool isJobActive(String deadlineStr) {
    try {
      if (deadlineStr.isEmpty) return true; // If no deadline, job is active
      
      DateTime deadline = DateTime.parse(deadlineStr);
      DateTime now = DateTime.now();
      
      return now.isBefore(deadline); // Job is active if current date is before deadline
    } catch (e) {
      print("Error checking job status: $e");
      return true; // Default to active if there's an error
    }
  }

  // New method to fetch application counts for all jobs
  Future<Map<String, int>> _fetchApplicationCounts() async {
    Map<String, int> counts = {};
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return counts;
      
      // Get all applications for the employer
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('applications')
          .get();
      
      // Count applications per job ID
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final jobId = data['job_id'] as String?;
        
        if (jobId != null) {
          counts[jobId] = (counts[jobId] ?? 0) + 1;
        }
      }
      
      print("Application counts: $counts");
      return counts;
    } catch (e) {
      print("Error fetching application counts: $e");
      return counts;
    }
  }

  Future<void> _fetchJobs() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First, check and disable interview slots for inactive jobs
      await _checkAndDisableInactiveJobInterviewSlots();

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      // Fetch jobs from the user's jobs subcollection
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('jobs')
          .orderBy('post_date', descending: true)
          .get();
      
      // Fetch application counts
      final applicationCounts = await _fetchApplicationCounts();
      
      List<Map<String, dynamic>> fetchedJobs = [];
      
      // Add job number to each job
      int jobIndex = 0;
      for (var doc in snapshot.docs) {
        jobIndex++;
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String postDate = data['post_date'] ?? '';
        String formattedDate = postDate.isNotEmpty ? formatJobTimestamp(postDate) : 'Recently';
        
        // Get deadline date (new field)
        String deadline = data['deadline'] ?? '';
        bool isActive = isJobActive(deadline);
        
        // Get application count for this job
        int applicationCount = applicationCounts[doc.id] ?? 0;
        
        // Process skills - handle all possible formats
        String skillsText;
        List<dynamic> skillsList = [];
        
        // First try to get the skills array
        var skillsData = data['job_skills'];
        
        if (skillsData is List && skillsData.isNotEmpty) {
          // Use the array format
          skillsList = skillsData;
          skillsText = skillsList.join(', ');
        } else if (data['job_skills_text'] != null && data['job_skills_text'].toString().trim().isNotEmpty) {
          // Use the text version and convert to list
          skillsText = data['job_skills_text'].toString();
          if (skillsText.toLowerCase() != "not specified") {
            // Split by comma to create a list
            skillsList = skillsText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
        } else {
          // Default fallback
          skillsText = "Not specified";
          skillsList = ["Not specified"];
        }
        
        // Final check - if skills are empty, use "Not specified"
        if (skillsList.isEmpty) {
          skillsList = ["Not specified"];
          skillsText = "Not specified";
        }
        
        fetchedJobs.add({
          'id': doc.id,
          'title': data['job_title'] ?? 'No Title',
          'company': data['company_name'] ?? 'Your Company',
          'location': data['job_location'] ?? 'No Location',
          'skills': skillsText,
          'skills_list': skillsList,
          'description': data['job_description'] ?? '',
          'status': isActive ? 'active' : 'inactive', // Set status based on deadline
          'posted': formattedDate,
          'raw_date': postDate,
          'deadline': deadline,
          'formatted_deadline': formatDeadline(deadline),
          'is_active': isActive,
          'jobNumber': jobIndex, // Add job number here
          'applicationCount': applicationCount, // Add application count here
        });
      }
      
      // Make sure to sort by the actual date, not the formatted string
      if (fetchedJobs.isNotEmpty) {
        fetchedJobs.sort((a, b) {
          if (a['raw_date'].isEmpty) return 1;
          if (b['raw_date'].isEmpty) return -1;
          try {
            return DateTime.parse(b['raw_date']).compareTo(DateTime.parse(a['raw_date']));
          } catch (e) {
            print("Error sorting dates: $e");
            return 0;
          }
        });
        
        // Re-number after sorting to maintain consistency
        for (int i = 0; i < fetchedJobs.length; i++) {
          fetchedJobs[i]['jobNumber'] = i + 1;
        }
      }
      
      if (mounted) {
        setState(() {
          jobs = fetchedJobs;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print("Error fetching jobs: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Updated build method to include job numbering and application count in the listing
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: EmployerAppBar(
        title: 'Manage Jobs',
      ),
      body: Column(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : jobs.isEmpty
              ? Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.work_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            "No job posts yet",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Go to the chatbot and say 'post job' to create your first job listing",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const EmployerChatPage()),
                                (route) => false,
                              );
                            },
                            child: const Text("Go to Chatbot"),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Job listing UI elements with job number and status badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "#${job['jobNumber']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  job['title'],
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              // Status badge
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                margin: EdgeInsets.only(left: 8),
                                                decoration: BoxDecoration(
                                                  color: job['is_active'] ? Colors.green.shade100 : Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: job['is_active'] ? Colors.green : Colors.red,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  job['is_active'] ? 'Active' : 'Inactive',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: job['is_active'] ? Colors.green.shade800 : Colors.red.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Edit/Delete popup menu
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: Row(
                                          children: const [
                                            Icon(Icons.edit, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit Description'),
                                          ],
                                        ),
                                        onTap: () {
                                          // Add navigation to edit job description
                                          Future.delayed(
                                            const Duration(seconds: 0),
                                            () => _showEditDescriptionDialog(job),
                                          );
                                        },
                                      ),
                                      PopupMenuItem(
                                        child: Row(
                                          children: const [
                                            Icon(Icons.calendar_today, color: Colors.purple),
                                            SizedBox(width: 8),
                                            Text('Set Deadline'),
                                          ],
                                        ),
                                        onTap: () {
                                          // Show set deadline dialog
                                          Future.delayed(
                                            const Duration(seconds: 0),
                                            () => _showSetDeadlineDialog(job),
                                          );
                                        },
                                      ),
                                          if (job['is_active'])
                                            PopupMenuItem(
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.schedule, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Set Interview Slots'),
                                                ],
                                              ),
                                              onTap: () {
                                                Future.delayed(
                                                  const Duration(seconds: 0),
                                                  () => _showInterviewSlotDialog(job),
                                                );
                                              },
                                            )
                                          else if (job['interview_slots_disabled'] == true)
                                            PopupMenuItem(
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.schedule_send, color: Colors.grey),
                                                  SizedBox(width: 8),
                                                  Text('Interview Slots (Disabled)'),
                                                ],
                                              ),
                                              onTap: null,
                                            ),
                                      PopupMenuItem(
                                        child: Row(
                                          children: const [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                        onTap: () {
                                          // Show delete confirmation dialog
                                          Future.delayed(
                                            const Duration(seconds: 0),
                                            () => _showDeleteConfirmation(job),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Other job details
                              const SizedBox(height: 8),
                              Text(
                                job['company'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              
                              // Application count - NEW SECTION
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: Colors.indigo),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Applications: ${job['applicationCount']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: job['applicationCount'] > 0 ? Colors.indigo : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Text(job['location']),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Deadline info
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Deadline: ${job['formatted_deadline']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: job['is_active'] ? Colors.black87 : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Posted time
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Posted ${job['posted']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.build_circle, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        // Check if there are skills in the list
                                        bool hasSkills = job['skills_list'] != null && 
                                                        (job['skills_list'] as List).isNotEmpty && 
                                                        !((job['skills_list'] as List).length == 1 && 
                                                          (job['skills_list'] as List)[0] == "Not specified");
                                        
                                        // If skills exist, show them as chips
                                        if (hasSkills) {
                                          return Wrap(
                                            spacing: 4,
                                            children: (job['skills_list'] as List).map<Widget>((skill) {
                                              return Chip(
                                                label: Text(
                                                  skill.toString(),
                                                  style: TextStyle(fontSize: 10),
                                                ),
                                                backgroundColor: Colors.blue.shade100,
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                              );
                                            }).toList(),
                                          );
                                        } 
                                        // If no skills, show "Not specified" gray chip
                                        else {
                                          return Wrap(
                                            spacing: 4,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  "Not specified",
                                                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                                ),
                                                backgroundColor: Colors.grey[300],
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                              )
                                            ],
                                          );
                                        }
                                      }
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (job['description'].isNotEmpty) 
                                Text(
                                  job['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  "No description added. Click 'Edit Description' to add one.",
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showSelectedLabels: true,
        showUnselectedLabels: true,
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
              //existing page
              break;
            case 1:
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => EmployerChatPage()),
                  (route) => false,
                );
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
  }


  void _showEditDescriptionDialog(Map<String, dynamic> job) {
    final TextEditingController descriptionController = TextEditingController();
    descriptionController.text = job['description'] ?? '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Job Description'),
          content: TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              hintText: 'Enter job description',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    // Update in main jobs collection
                    await FirebaseFirestore.instance
                        .collection('jobs')
                        .doc(job['id'])
                        .update({'job_description': descriptionController.text});
                    
                    // Update in user's jobs subcollection
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('jobs')
                        .doc(job['id'])
                        .update({'job_description': descriptionController.text});
                    
                    _fetchJobs(); // Refresh jobs list
                  }
                } catch (e) {
                  print("Error updating job description: $e");
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // New method to show set deadline dialog
  // Update the _showSetDeadlineDialog method in your ManageJobsPage class
void _showSetDeadlineDialog(Map<String, dynamic> job) {
  // Parse existing deadline if available, otherwise use today's date
  DateTime now = DateTime.now();
  DateTime selectedDate = now.add(Duration(days: 30)); // Default 30 days from now
  
  if (job['deadline'] != null && job['deadline'].toString().isNotEmpty) {
    try {
      DateTime oldDeadline = DateTime.parse(job['deadline']);
      // Check if old deadline is after today, only then use it
      if (oldDeadline.isAfter(now)) {
        selectedDate = oldDeadline;
      }
      // If deadline is in the past, we'll use the default (now + 30 days)
    } catch (e) {
      print("Error parsing existing deadline: $e");
    }
  }
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Set Job Deadline'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current deadline: ${job['formatted_deadline']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('Select new deadline date:'),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(selectedDate),
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: now, // Use current date as first date
                            lastDate: now.add(Duration(days: 365)),
                          );
                          if (picked != null && picked != selectedDate) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Note: When the deadline passes, the job will be automatically marked as inactive and hidden from job seekers.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Remove Deadline'),
                onPressed: () async {
                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      // Update in main jobs collection and user's subcollection
                      await _updateJobDeadline(currentUser.uid, job['id'], '');
                      _fetchJobs(); // Refresh jobs list
                    }
                  } catch (e) {
                    print("Error removing deadline: $e");
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('Save'),
                onPressed: () async {
                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      // Format the date to ISO string
                      String deadlineStr = selectedDate.toIso8601String();
                      
                      // Update in main jobs collection and user's subcollection
                      await _updateJobDeadline(currentUser.uid, job['id'], deadlineStr);
                      _fetchJobs(); // Refresh jobs list
                    }
                  } catch (e) {
                    print("Error setting deadline: $e");
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
  // Helper method to update deadline in both collections
  Future<void> _updateJobDeadline(String userId, String jobId, String deadline) async {
    try {
      // Calculate new status based on deadline
      bool isActive = isJobActive(deadline);
      String status = isActive ? 'active' : 'inactive';
      
      // Update in main jobs collection
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .update({
            'deadline': deadline,
            'status': status,
          });
      
      // Update in user's jobs subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('jobs')
          .doc(jobId)
          .update({
            'deadline': deadline,
            'status': status,
          });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deadline.isEmpty 
              ? 'Deadline removed' 
              : 'Deadline updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error updating job deadline: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating deadline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Job Post'),
          content: const Text(
            'Are you sure you want to delete this job post? This will also delete all applications for this job.'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                // Close the dialog first
                Navigator.of(dialogContext).pop();
                
                if (!mounted) return;
                
                setState(() {
                  _isLoading = true;
                });

                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    print("Current user ID: ${currentUser.uid}");
                    print("Job ID to delete: ${job['id']}");
                    
                    // First, let's check the job document to see its employer_id
                    try {
                      final jobDoc = await FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(job['id'])
                          .get();
                      
                      if (jobDoc.exists) {
                        final jobData = jobDoc.data() as Map<String, dynamic>;
                        print("Job employer_id: ${jobData['employer_id']}");
                        print("Does employer_id match current user? ${jobData['employer_id'] == currentUser.uid}");
                      } else {
                        print("Job document doesn't exist in main collection");
                      }
                    } catch (e) {
                      print("Error checking job document: $e");
                    }
                    
                    // Try to delete from user's jobs subcollection first
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('jobs')
                          .doc(job['id'])
                          .delete();
                      print("Successfully deleted from user's subcollection");
                    } catch (e) {
                      print("Error deleting from user's subcollection: $e");
                    }
                    
                    // Then try to delete from main jobs collection
                    try {
                      await FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(job['id'])
                          .delete();
                      print("Successfully deleted from main jobs collection");
                    } catch (e) {
                      print("Error deleting from main jobs collection: $e");
                    }
                    
                    // Also delete all applications for this job
                    try {
                      // Get all applications for this job
                      final QuerySnapshot appSnapshot = await FirebaseFirestore.instance
                          .collection('applications')
                          .where('job_id', isEqualTo: job['id'])
                          .get();
                          
                      // Delete each application
                      for (var appDoc in appSnapshot.docs) {
                        final appData = appDoc.data() as Map<String, dynamic>;
                        final jobSeekerId = appData['job_seeker_id'];
                        
                        // Delete from main applications collection
                        await appDoc.reference.delete();
                        
                        // Delete from job seeker's subcollection if job seeker ID is available
                        if (jobSeekerId != null) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(jobSeekerId)
                                .collection('applications')
                                .doc(appDoc.id)
                                .delete();
                          } catch (e) {
                            print("Error deleting from job seeker's subcollection: $e");
                          }
                        }
                      }
                      
                      print("Deleted ${appSnapshot.docs.length} applications for this job");
                    } catch (e) {
                      print("Error deleting applications: $e");
                    }
                    
                    // Refresh the jobs list
                    if (mounted) {
                      await _fetchJobs();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Job post deleted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print("Error in delete process: $e");
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
void _showInterviewSlotDialog(Map<String, dynamic> job) {
  // Check if job is active
  bool isActive = isJobActive(job['deadline'] ?? '');
  
  if (!isActive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cannot Set Interview Slots'),
          content: Text('This job has passed its deadline and cannot have interview slots set.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    return;
  }
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // Parse the deadline date
      DateTime? jobDeadline;
      if (job['deadline'] != null && job['deadline'].toString().isNotEmpty) {
        try {
          jobDeadline = DateTime.parse(job['deadline']);
        } catch (e) {
          print('Error parsing deadline: $e');
        }
      }
      
      return AlertDialog(
        title: Text('Set Interview Slots for ${job['title']}'),
        content: SingleChildScrollView(
          child: InterviewSlotSelector(
            jobDeadline: jobDeadline, // Pass the deadline
            onSlotsSelected: (slots) async {
              // Update job with interview slots
              await _updateJobWithInterviewSlots(job['id'], slots);
              Navigator.of(context).pop(); // Close the dialog after successful update
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      );
    },
  );
}

// Add a method to check and disable interview slots when job becomes inactive
Future<void> _checkAndDisableInactiveJobInterviewSlots() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Get all jobs
    final allJobsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobs')
        .get();
    
    for (var jobDoc in allJobsSnapshot.docs) {
      final jobData = jobDoc.data();
      final deadline = jobData['deadline'] ?? '';
      final hasInterviewSlots = jobData['has_interview_slots'] ?? false;
      
      // Check if the job has become inactive
      if (!isJobActive(deadline) && hasInterviewSlots) {
        // Disable interview slots for this job
        await _disableInterviewSlots(jobDoc.id);
      }
    }
  } catch (e) {
    print('Error checking inactive job interview slots: $e');
  }
}

// Method to disable interview slots for inactive jobs
Future<void> _disableInterviewSlots(String jobId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final updateData = {
      'interview_slots': [],  // Clear interview slots
      'has_interview_slots': false,  // Set to false
      'interview_slots_disabled': true,  // Add flag to indicate they were disabled
      'interview_slots_disabled_date': DateTime.now().toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    // Update in both main collection and subcollection
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .update(updateData);
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobs')
        .doc(jobId)
        .update(updateData);
    
    print('Interview slots disabled for job: $jobId');
  } catch (e) {
    print('Error disabling interview slots: $e');
  }
}
Future<void> _updateJobWithInterviewSlots(String jobId, List<InterviewSlot> slots) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Check if job is still active before updating
    final jobDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobs')
        .doc(jobId)
        .get();
    
    if (jobDoc.exists) {
      final jobData = jobDoc.data()!;
      final deadline = jobData['deadline'] ?? '';
      
      if (!isJobActive(deadline)) {
        throw Exception('Cannot set interview slots for inactive jobs');
      }
    }
    
    final updateData = {
      'interview_slots': slots.map((slot) => slot.toMap()).toList(),
      'has_interview_slots': true,
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    // Update in both main collection and subcollection
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .update(updateData);
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobs')
        .doc(jobId)
        .update(updateData);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Interview slots added successfully')),
    );
    
    _fetchJobs(); // Refresh the list
  } catch (e) {
    print('Error updating job with interview slots: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}



}