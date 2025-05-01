import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/update_status_page.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:intl/intl.dart'; // Import for date formatting

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

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in");
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Fetch jobs from the user's jobs subcollection
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('jobs')
          .orderBy('post_date', descending: true)
          .get();
      
      List<Map<String, dynamic>> fetchedJobs = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String postDate = data['post_date'] ?? '';
        String formattedDate = postDate.isNotEmpty ? formatJobTimestamp(postDate) : 'Recently';
        
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
          'status': data['status'] ?? 'active',
          'posted': formattedDate,
          'raw_date': postDate,
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
      }
      
      setState(() {
        jobs = fetchedJobs;
        _isLoading = false;
      });
      
    } catch (e) {
      print("Error fetching jobs: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: AppBar(
        title: const Text('Manage Jobs'),
        backgroundColor: Theme.of(context).primaryColor,
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
                            // Job listing UI elements
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                // Posted time
                                Text(
                                  'Posted ${job['posted']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16),
                                const SizedBox(width: 4),
                                Text(job['location']),
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
          // Bottom Navigation Bar
          BottomNavigationBar(
            backgroundColor: Theme.of(context).primaryColor,
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
            ],
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              
              switch (index) {
                case 0:
                  // Already on ManageJobs page
                  break;
                case 1:
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployerChatPage()),
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
              }
            },
          ),
        ],
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

  void _showDeleteConfirmation(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Job Post'),
          content: const Text(
            'Are you sure you want to delete this job post?'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    // Delete from main jobs collection
                    await FirebaseFirestore.instance
                        .collection('jobs')
                        .doc(job['id'])
                        .delete();
                    
                    // Delete from user's jobs subcollection
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('jobs')
                        .doc(job['id'])
                        .delete();
                    
                    _fetchJobs(); // Refresh jobs list
                  }
                } catch (e) {
                  print("Error deleting job: $e");
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}