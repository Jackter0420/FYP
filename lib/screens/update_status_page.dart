// update_status_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:prototype_2/models/interview_slot.dart';
import 'package:prototype_2/services/job_application_service.dart';
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
  
  // Stats for application summary
  int _totalApplications = 0;
  int _pendingCount = 0;
  int _reviewingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _offeredCount = 0;
  
  // For filtering applications
  String _selectedFilter = 'all';
  
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
      
      // Reset counters
      _pendingCount = 0;
      _reviewingCount = 0;
      _approvedCount = 0;
      _rejectedCount = 0;
      _offeredCount = 0;
      
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
        
        // Update counters based on status
        String status = (data['status'] ?? 'pending').toLowerCase();
        switch (status) {
          case 'pending':
            _pendingCount++;
            break;
          case 'reviewing':
            _reviewingCount++;
            break;
          case 'shortlisted':
            _approvedCount++;
            break;
          case 'offered':
            _offeredCount++;
            break;
          case 'declined':
            _rejectedCount++;
            break;
        }
      }

      setState(() {
        _applications = applications;
        _totalApplications = applications.length;
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
    
    // Create update data map
    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'last_update_date': updateTime,
    };
    
    // NEW CODE: If changing to shortlisted, add a flag to indicate interview slots can be selected
    if (newStatus.toLowerCase() == 'shortlisted') {
      updateData['can_select_interview_slot'] = true;
    }
    
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
    
    // NEW CODE: Show appropriate success message based on status
    if (newStatus.toLowerCase() == 'shortlisted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status updated. Job seeker can now select an interview slot.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Original success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
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

  // Get filtered applications based on selected status
  List<Map<String, dynamic>> _getFilteredApplications() {
    if (_selectedFilter == 'all') {
      return _applications;
    }
    
    return _applications.where((app) {
      final status = app['applicationData']['status']?.toString().toLowerCase() ?? 'pending';
      return status == _selectedFilter;
    }).toList();
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
  
  // Build compact stat item for application summary
  Widget _buildCompactStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  // Build application summary card
  Widget _buildApplicationSummary() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            children: [
              Text(
                'Application Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              // Total chip beside the title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  'Total: $_totalApplications',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
            const SizedBox(height: 8),
            // Single row with all statuses in a more compact layout
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // _buildCompactStatItem('Total', _totalApplications, Colors.blue),
                _buildCompactStatItem('Pending', _pendingCount, Colors.amber),
                _buildCompactStatItem('Reviewing', _reviewingCount, Colors.blue),
                _buildCompactStatItem('Shortlisted', _approvedCount, const Color.fromARGB(255, 1, 109, 98)),
                _buildCompactStatItem('Offered', _offeredCount, Colors.green),
                _buildCompactStatItem('Declined', _rejectedCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build filter chips
  Widget _buildFilterChips() {
    final filters = ['all', 'pending', 'reviewing', 'shortlisted', 'offered', 'declined'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: filters.map((filter) {
          // Get count for this filter
          int count = 0;
          switch (filter) {
            case 'all':
              count = _totalApplications;
              break;
            case 'pending':
              count = _pendingCount;
              break;
            case 'reviewing':
              count = _reviewingCount;
              break;
            case 'shortlisted':
              count = _approvedCount;
              break;
            case 'offered':
              count = _offeredCount;
            break;
            case 'declined':
              count = _rejectedCount;
              break;
          }
          
          // Get color for this filter
          Color chipColor;
          switch (filter) {
            case 'pending':
              chipColor = Colors.amber;
              break;
            case 'reviewing':
              chipColor = Colors.blue;
              break;
            case 'shortlisted':
              chipColor = const Color.fromARGB(255, 1, 109, 98);
              break;
            case 'offered':
              chipColor= Colors.green;
              break;
            case 'declined':
              chipColor = Colors.red;
              break;
            case 'all':
            default:
              chipColor = Colors.grey;
              break;
          }
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FilterChip(
              label: Text('${filter.toUpperCase()} ($count)'),
              selected: _selectedFilter == filter,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter : 'all';
                });
              },
              selectedColor: chipColor.withOpacity(0.3),
              backgroundColor: Colors.white,
              checkmarkColor: chipColor,
              labelStyle: TextStyle(
                fontWeight: _selectedFilter == filter ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


Future<bool> _hasAvailableInterviewSlots(String jobId) async {
  try {
    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
        
    if (!jobDoc.exists) return false;
    
    final interviewSlotsData = jobDoc.data()?['interview_slots'] as List?;
    if (interviewSlotsData == null || interviewSlotsData.isEmpty) {
      return false;
    }
    
    // Check if there are any unbooked slots
    for (var slotData in interviewSlotsData) {
      if (slotData['is_booked'] != true) {
        return true;
      }
    }
    
    return false; // No available slots found
  } catch (e) {
    print("Error checking interview slots: $e");
    return false;
  }
}

Future<InterviewSlot?> _getBookedInterviewDetails(Map<String, dynamic> appData) async {
  try {
    if (!appData.containsKey('booked_interview_id') || appData['booked_interview_id'] == null) {
      print('No booked interview ID found in application');
      return null;
    }
    
    print('Looking for booked interview ID: ${appData['booked_interview_id']}');
    
    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(appData['job_id'])
        .get();
    
    if (!jobDoc.exists) {
      print('Job document not found');
      return null;
    }
    
    final slotsData = jobDoc.data()?['interview_slots'] as List?;
    if (slotsData == null) {
      print('No interview_slots array found in job document');
      return null;
    }
    
    // Find the matching slot with the booked ID
    Map<String, dynamic>? matchingSlot;
    for (var slot in slotsData) {
      if (slot['id'] == appData['booked_interview_id']) {
        matchingSlot = Map<String, dynamic>.from(slot);
        break;
      }
    }
    
    if (matchingSlot == null) {
      print('Matching slot not found in job document');
      return null;
    }
    
    print('Found matching slot: $matchingSlot');
    return InterviewSlot.fromMap(matchingSlot);
  } catch (e) {
    print("Error getting interview details: $e");
    return null;
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
        // Add application summary at the top
        if (!_isLoading && _applications.isNotEmpty)
          _buildApplicationSummary(),
        
        // Add filter chips below the summary
        if (!_isLoading && _applications.isNotEmpty)
          _buildFilterChips(),
        
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
              itemCount: _getFilteredApplications().length,
              itemBuilder: (context, index) {
                final application = _getFilteredApplications()[index];
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
                            
                            // ADD INTERVIEW SECTION HERE
                            if (appData['status']?.toString().toLowerCase() == 'shortlisted') ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Interview Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Check if interview is already booked
                              if (appData['booked_interview_id'] != null) 
                                // Show booked interview details
                                FutureBuilder<InterviewSlot?>(
                                  future: _getBookedInterviewDetails(appData),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const CircularProgressIndicator();
                                    }
                                    
                                    if (snapshot.hasData && snapshot.data != null) {
                                      final slot = snapshot.data!;
                                      return Card(
                                        color: Colors.green.shade50,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Interview Scheduled',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today, size: 16, color: Colors.green.shade700),
                                                  const SizedBox(width: 8),
                                                  Text('Date: ${DateFormat('MMM d, yyyy').format(slot.startTime)}'),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
                                                  const SizedBox(width: 8),
                                                  Text('Time: ${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}'),
                                                ],
                                              ),
                                              if (slot.meetingLink != null && slot.meetingLink!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.link, size: 16, color: Colors.green.shade700),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: InkWell(
                                                        onTap: () => _launchUrl(slot.meetingLink!),
                                                        child: Text(
                                                          'Join Meeting',
                                                          style: TextStyle(
                                                            color: Colors.blue,
                                                            decoration: TextDecoration.underline,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                )
                              else
                                // Show waiting for job seeker to select interview slot
                                FutureBuilder<bool>(
                                  future: _hasAvailableInterviewSlots(appData['job_id']),
                                  builder: (context, snapshot) {
                                    final hasSlots = snapshot.data ?? false;
                                    
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('Checking interview slots...'),
                                          ],
                                        ),
                                      );
                                    }
                                    
                                    if (hasSlots) {
                                      // There are available slots, waiting for job seeker to choose
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.orange.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  color: Colors.orange.shade700,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Pending Interview Selection',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'The candidate has been shortlisted and can now select an interview time slot.',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: Colors.orange.shade600,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Waiting for ${appData['job_seeker_name'] ?? 'job seeker'} to choose an available interview slot.',
                                                    style: TextStyle(
                                                      color: Colors.orange.shade600,
                                                      fontSize: 12,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      // No available slots - need to set interview slots first
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.warning,
                                                  color: Colors.red.shade700,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'No Interview Slots Available',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'The candidate has been shortlisted, but no interview slots are available.',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: Colors.red.shade600,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Please set interview slots for this job in the Manage Jobs section.',
                                                    style: TextStyle(
                                                      color: Colors.red.shade600,
                                                      fontSize: 12,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                            
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
                                      'shortlisted',
                                      'offered',
                                      'declined',
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