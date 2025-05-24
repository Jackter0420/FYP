// Updated Track_application_page.dart with interview functionality integration
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:prototype_2/screens/job_recommendations_page.dart';
import 'package:prototype_2/screens/jobseeker_chat_page.dart';
import 'package:prototype_2/widgets/jobseeker_app_bar.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/services/job_application_service.dart';
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/models/interview_slot.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;

class TrackApplicationPage extends StatefulWidget {
  const TrackApplicationPage({Key? key}) : super(key: key);

  @override
  State<TrackApplicationPage> createState() => _TrackApplicationPageState();
}

class _TrackApplicationPageState extends State<TrackApplicationPage> {
  int _currentIndex = 1; // Default to application tracking tab
  bool _isLoading = true;
  List<JobApplication> _applications = [];
  String _selectedFilter = 'all'; // Filter for application status

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening URL: $e')),
        );
      }
    }
  }

// Add this method to show available interview slots
Future<void> _showInterviewSlotSelectionDialog(JobApplication application) async {
  // Fetch available interview slots from the job document
  final jobDoc = await FirebaseFirestore.instance
      .collection('jobs')
      .doc(application.jobId)
      .get();
      
  if (!jobDoc.exists || !jobDoc.data()!.containsKey('interview_slots')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No interview slots available for this job')),
    );
    return;
  }
  
  final interviewSlotsData = jobDoc.data()!['interview_slots'] as List?;
  if (interviewSlotsData == null || interviewSlotsData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No interview slots available for this job')),
    );
    return;
  }
  
  // Convert to InterviewSlot objects
  List<InterviewSlot> availableSlots = [];
  for (var slotData in interviewSlotsData) {
    try {
      final slot = InterviewSlot.fromMap(slotData);
      // Only include slots that haven't been booked yet
      if (!slot.isBooked) {
        availableSlots.add(slot);
      }
    } catch (e) {
      print("Error parsing interview slot: $e");
    }
  }
  
  // Show dialog to select a slot
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Interview Slot',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a time slot for your interview:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: availableSlots.isEmpty
                ? Center(child: Text('No available slots'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableSlots.length,
                    itemBuilder: (context, index) {
                      final slot = availableSlots[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(DateFormat('EEEE, MMM d, yyyy').format(slot.startTime)),
                          subtitle: Text('${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}'),
                          onTap: () async {
                            Navigator.pop(context);
                            await _bookInterviewSlot(application, slot);
                          },
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Add this method to book the selected interview slot
Future<void> _bookInterviewSlot(JobApplication application, InterviewSlot selectedSlot) async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Use the service method instead of manual Firestore updates
    final result = await JobApplicationService.bookInterviewSlot(
      application.id,
      application.jobId,
      selectedSlot.id,
    );
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interview slot booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the applications list
      await _fetchApplications();
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    print("Error booking interview slot: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error booking slot: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Add this method to get the booked interview details
Future<InterviewSlot?> _getBookedInterviewDetails(JobApplication application) async {
  try {
    if (application.bookedInterviewId == null) {
      print('No booked interview ID found in application');
      return null;
    }
    
    print('Looking for booked interview ID: ${application.bookedInterviewId}');
    
    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(application.jobId)
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
      if (slot['id'] == application.bookedInterviewId) {
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

  // Fetch job applications for the current user
  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final applications = await JobApplicationService.getMyApplications();
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching applications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get filtered applications based on selected status
  List<JobApplication> _getFilteredApplications() {
    if (_selectedFilter == 'all') {
      return _applications;
    }
    return _applications.where((app) => 
      app.status.toLowerCase() == _selectedFilter.toLowerCase()
    ).toList();
  }

  // Withdraw an application
  Future<void> _withdrawApplication(String applicationId) async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Withdraw Application?"),
          content: const Text(
            "Are you sure you want to withdraw this application? This will cancel any scheduled interviews."
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                "Withdraw",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await JobApplicationService.withdrawApplication(applicationId);
      
      if (result['success']) {
        // Remove the application from the local list immediately
        setState(() {
          _applications.removeWhere((app) => app.id == applicationId);
        });
        
        // Re-fetch applications to ensure sync with database
        await _fetchApplications();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application withdrawn successfully. You can now reapply for this position.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error withdrawing application: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error withdrawing application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'offered':
        return Colors.green;
      case 'shortlisted':
        return const Color.fromARGB(255, 1, 109, 98);
      case 'declined':
        return Colors.red;
      case 'reviewing':
        return Colors.blue;
      case 'pending':
        return Colors.amber;
      case 'all':
      default:
        return Colors.grey;
      
    }
  }

  // Get icon based on status
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'offered':
       return Icons.check_circle;
      case 'shortlisted':
        return Icons.how_to_reg;
      case 'declined':
        return Icons.cancel;
      case 'reviewing':
        return Icons.visibility;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  // Format a date string
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  // Build filter chips
  Widget _buildFilterChips() {
    final filters = ['all', 'pending', 'reviewing', 'shortlisted', 'offered','declined'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: filters.map((filter) {
          final count = filter == 'all' 
              ? _applications.length 
              : _applications.where((app) => app.status.toLowerCase() == filter).length;
          
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
              selectedColor: _getStatusColor(filter).withOpacity(0.3),
              checkmarkColor: _getStatusColor(filter),
            ),
          );
        }).toList(),
      ),
    );
  }

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

  // Build summary statistics
  Widget _buildSummaryCard() {
    final totalApplications = _applications.length;
    final pendingCount = _applications.where((app) => app.status.toLowerCase() == 'pending').length;
    final reviewingCount = _applications.where((app) => app.status.toLowerCase() == 'reviewing').length;
    final approvedCount = _applications.where((app) => app.status.toLowerCase() == 'shortlisted').length;
    final rejectedCount = _applications.where((app) => app.status.toLowerCase() == 'declined').length;
    final offeredCount = _applications.where((app) => app.status.toLowerCase() == 'offered').length;
    
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
                  'Total: $totalApplications',
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
                //_buildCompactStatItem('Total', totalApplications, Colors.blue),
                _buildCompactStatItem('Pending', pendingCount, Colors.amber),
                _buildCompactStatItem('Reviewing', reviewingCount, Colors.blue),
                _buildCompactStatItem('Shortlisted', approvedCount, const Color.fromARGB(255, 1, 109, 98)),
                _buildCompactStatItem('Offered', offeredCount, Colors.green),
                _buildCompactStatItem('Declined', rejectedCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
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
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.signOut();
        
        if (!mounted) return;
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: JobSeekerAppBar(
        title: 'My Applications',
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                _buildFilterChips(),
                Expanded(
                  child: _getFilteredApplications().isEmpty
                      ? _buildEmptyState()
                      : _buildApplicationList(),
                ),
              ],
            ),
      // In Track_application_page.dart, update the bottom navigation
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
              // Use pushReplacement instead of push to avoid stacking pages
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
              );
              break;

            case 1:
              // Already on TrackApplicationPage
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter == 'all' ? Icons.work_off : Icons.filter_list_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all' 
                ? "No Job Applications Yet"
                : "No ${_selectedFilter.toUpperCase()} Applications",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? "Search for jobs in the chat and apply to see them here"
                : "You don't have any applications with status '${_selectedFilter}'",
            textAlign: TextAlign.center,
          ),
          if (_selectedFilter == 'all') ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
                  (route) => false,
                );
              },
              child: const Text("Search Jobs"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationList() {
    final filteredApplications = _getFilteredApplications();
    
    return RefreshIndicator(
      onRefresh: _fetchApplications,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: filteredApplications.length,
        itemBuilder: (context, index) {
          final application = filteredApplications[index];
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  Widget _buildApplicationCard(JobApplication application) {
    final statusColor = _getStatusColor(application.status);
    final statusIcon = _getStatusIcon(application.status);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job title and company row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.jobTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application.companyName,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          application.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Application date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Applied: ${_formatDate(application.appliedDate)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Last update date if available
              if (application.lastUpdateDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.update, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Updated: ${_formatDate(application.lastUpdateDate)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Interview indicator if applicable
              if (application.bookedInterviewId != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event_available, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Interview Scheduled',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Action buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // View Details button first
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                    onPressed: () => _showApplicationDetails(application),
                  ),
                  // Show interview indicator if one is scheduled (moved to the right side)
                  if (application.bookedInterviewId != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0), // Changed from right to left padding
                      child: Chip(
                        label: const Text('Interview Scheduled'),
                        backgroundColor: Colors.green.shade100,
                        labelStyle: TextStyle(color: Colors.green.shade800, fontSize: 12),
                        avatar: Icon(Icons.event_available, size: 16, color: Colors.green.shade800),
                      ),
                    ),
                  // Show "Select Interview" button if application is shortlisted and no interview is scheduled yet
                  if (application.status.toLowerCase() == 'shortlisted' && application.bookedInterviewId == null)
                    FutureBuilder<bool>(
                      future: _hasAvailableInterviewSlots(application.jobId),
                      builder: (context, snapshot) {
                        final hasSlots = snapshot.data ?? false;
                        
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SizedBox.shrink(); // Don't show anything while loading
                        }
                        
                        if (hasSlots) {
                          return TextButton.icon(
                            icon: const Icon(Icons.schedule, size: 18, color: Colors.green),
                            label: const Text('Schedule Interview', style: TextStyle(color: Colors.green)),
                            onPressed: () => _showInterviewSlotSelectionDialog(application),
                          );
                        } else {
                          // Make this a non-clickable Container instead of a button
                          return Chip(
                            label: const Text('No Interview Slots'),
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            avatar: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  // Updated to include interview information
void _showApplicationDetails(JobApplication application) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Application Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                
                // Job information
                const SizedBox(height: 8),
                _buildDetailRow('Position', application.jobTitle, Icons.work),
                _buildDetailRow('Company', application.companyName, Icons.business),
                _buildDetailRow('Applied Date', _formatDate(application.appliedDate), Icons.calendar_today),
                
                if (application.lastUpdateDate != null)
                  _buildDetailRow('Last Updated', _formatDate(application.lastUpdateDate), Icons.update),
                
                const SizedBox(height: 16),
                
                // Status section
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(application.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(application.status),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(application.status),
                        color: _getStatusColor(application.status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        application.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(application.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Interview Information Section - NEW
                if (application.status.toLowerCase() == 'shortlisted') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Interview Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // If interview is already booked, show details
                  application.bookedInterviewId != null
                      ? FutureBuilder<InterviewSlot?>(
                          future: _getBookedInterviewDetails(application),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            
                            // Add error handling if the snapshot has an error
                            if (snapshot.hasError) {
                              print("Error loading interview details: ${snapshot.error}");
                              return const Text('Error loading interview details');
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
                                          Text('Date: ${DateFormat('EEEE, MMM d, yyyy').format(slot.startTime)}'),
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
                            
                            return const Text('No interview details available');
                          },
                        )
                      // Show button to select interview slot if not already booked
                      : FutureBuilder<bool>(
                        future: _hasAvailableInterviewSlots(application.jobId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          
                          final hasSlots = snapshot.data ?? false;
                          
                          if (hasSlots) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You have been shortlisted for an interview',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.schedule),
                                  label: const Text('Select Interview Slot'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context); // Close the details dialog
                                    _showInterviewSlotSelectionDialog(application);
                                  },
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You have been shortlisted for an interview',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No interview slots available. Please wait for an email from the employer.',
                                          style: TextStyle(color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                ],
                
                // Cover letter section
                if (application.coverLetter != null && application.coverLetter!.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                      application.coverLetter!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
                
                // Action buttons
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (application.status.toLowerCase() == 'pending')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Withdraw'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _withdrawApplication(application.id);
                        },
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Find More Jobs'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const JobSeekerChatPage()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}