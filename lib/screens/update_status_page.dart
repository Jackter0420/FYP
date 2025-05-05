// update_status_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:prototype_2/widgets/employer_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/manage_jobs_page.dart';
import 'package:prototype_2/screens/candidate_search_page.dart';


class UpdateStatusPage extends StatefulWidget {
  @override
  State<UpdateStatusPage> createState() => _UpdateStatusPageState();
}

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  int _currentIndex = 2;
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];
  
  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Fetch applications from the employer's subcollection
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('applications')
          .orderBy('applied_date', descending: true)
          .get();

      List<Map<String, dynamic>> applications = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Fetch job seeker details
        String jobSeekerId = data['job_seeker_id'] ?? '';
        Map<String, dynamic> jobSeekerData = {};
        
        if (jobSeekerId.isNotEmpty) {
          try {
            DocumentSnapshot jobSeekerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(jobSeekerId)
                .get();
                
            if (jobSeekerDoc.exists) {
              jobSeekerData = jobSeekerDoc.data() as Map<String, dynamic>;
            }
          } catch (e) {
            print('Error fetching job seeker data: $e');
          }
        }
        
        applications.add({
          'id': doc.id,
          'applicationData': data,
          'jobSeekerData': jobSeekerData,
        });
      }

      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching applications: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $e')),
      );
    }
  }

 Future<void> _updateApplicationStatus(String applicationId, String newStatus) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    // Get the application data first to get jobSeekerId
    final appDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('applications')
        .doc(applicationId)
        .get();
    
    if (!appDoc.exists) {
      throw Exception('Application not found');
    }
    
    final appData = appDoc.data();
    final jobSeekerId = appData?['job_seeker_id'];
    
    if (jobSeekerId == null) {
      throw Exception('Job seeker ID not found in application data');
    }
    
    // Update timestamp
    final updateTime = DateTime.now().toIso8601String();
    final updateData = {
      'status': newStatus,
      'last_update_date': updateTime,
    };
    
    // 1. Update in employer's subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('applications')
        .doc(applicationId)
        .update(updateData);
    
    // 2. Update in main applications collection
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(applicationId)
          .update(updateData);
    } catch (e) {
      print('Warning: Could not update main applications collection: $e');
      // Continue anyway since it's not critical
    }
    
    // 3. Update in job seeker's subcollection
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(jobSeekerId)
          .collection('applications')
          .doc(applicationId)
          .update(updateData);
    } catch (e) {
      print('Warning: Could not update job seeker subcollection: $e');
      // Continue anyway since employer data is updated
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Application status updated to ${newStatus.toUpperCase()}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Refresh the list
    await _fetchApplications();
  } catch (e) {
    print('Error updating status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating status: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _launchUrl(String url) async {
  try {
    final Uri uri = Uri.parse(url);
    
    // Check if the URL can be launched
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in external browser
      );
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    print('Error launching URL: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening URL: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: EmployerAppBar(
      title: 'Update Application Status',
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchApplications,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_applications.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No applications found'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _applications.length,
                itemBuilder: (context, index) {
                  final application = _applications[index];
                  final appData = application['applicationData'];
                  final jobSeekerData = application['jobSeekerData'];
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ExpansionTile(
                      title: Text(
                        appData['job_seeker_name'] ?? 'Unknown Applicant',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(
                        appData['job_title'] ?? 'Unknown Position',
                        style: const TextStyle(color: Colors.blue),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Applicant Details Section
                              const Text(
                                'Applicant Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                Icons.person,
                                appData['job_seeker_name'] ?? 'N/A',
                              ),
                              _buildDetailRow(
                                Icons.email,
                                jobSeekerData['email'] ?? 'N/A',
                              ),
                              _buildDetailRow(
                                Icons.phone,
                                jobSeekerData['phoneNumber'] ?? 'N/A',
                              ),
                              _buildDetailRow(
                                Icons.calendar_today,
                                'Applied: ${_formatDate(appData['applied_date'])}',
                              ),
                              if (appData['last_update_date'] != null)
                                _buildDetailRow(
                                  Icons.update,
                                  'Updated: ${_formatDate(appData['last_update_date'])}',
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Cover Letter Section
                              if (appData['cover_letter'] != null && 
                                  appData['cover_letter'].toString().isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cover Letter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        appData['cover_letter'],
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Status Update Section
                              const Text(
                                'Application Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: appData['status'] ?? 'pending',
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      items: [
                                        'pending',
                                        'reviewing',
                                        'approved',
                                        'rejected',
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            appData['status'] = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Update Status'),
                                            content: Text(
                                              'Update status to ${appData['status'].toString().toUpperCase()}?'
                                            ),
                                            actions: [
                                              TextButton(
                                                child: const Text('Cancel'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                child: const Text('Update'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _updateApplicationStatus(
                                                    application['id'],
                                                    appData['status'],
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: const Text('Update'),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Document Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (appData['resume_url'] != null)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.description),
                                      label: const Text('View Resume'),
                                      onPressed: () async {
                                        final resumeUrl = appData['resume_url'];
                                        if (resumeUrl != null && resumeUrl.toString().isNotEmpty) {
                                          // Check if it's a valid URL
                                          try {
                                            final uri = Uri.parse(resumeUrl);
                                            if (uri.hasScheme) {
                                              await _launchUrl(resumeUrl);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Invalid resume URL'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error with resume URL: ${e.toString()}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('No resume URL available'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  else
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.description),
                                      label: const Text('No Resume'),
                                      onPressed: null,
                                    ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.mail),
                                    label: const Text('Contact'),
                                    onPressed: () {
                                      final email = jobSeekerData['email'];
                                      if (email != null) {
                                        _launchUrl('mailto:$email');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          BottomNavigationBar(
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
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => EmployerChatPage()),
                    (route) => false,
                  );
                  break;
                case 2:
                  // Already on UpdateStatus page
                  break;

                case 3:
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CandidateSearchPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}