// lib/screens/Track_application_page.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/jobseeker_chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'login.dart';

// Import job application model and service
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/services/job_application_service.dart';

class TrackApplicationPage extends StatefulWidget {
  const TrackApplicationPage({Key? key}) : super(key: key);

  @override
  State<TrackApplicationPage> createState() => _TrackApplicationPageState();
}

class _TrackApplicationPageState extends State<TrackApplicationPage> {
  int _currentIndex = 1; // Default to application tracking tab
  bool _isLoading = true;
  List<JobApplication> _applications = [];

  @override
  void initState() {
    super.initState();
    _fetchApplications();
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
      });
    } catch (e) {
      print("Error fetching applications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Withdraw an application
  Future<void> _withdrawApplication(String applicationId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await JobApplicationService.withdrawApplication(applicationId);
      
      if (result['success']) {
        // Re-fetch applications to update the list
        await _fetchApplications();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Application withdrawn successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      print("Error withdrawing application: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error withdrawing application: $e')),
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
      case 'approved':
      case 'accepted':
        return Colors.green;
      case 'rejected':
      case 'declined':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      case 'in review':
      case 'interviewing':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  // Format a date string
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, yyyy').format(dateTime);
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
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: AppBar(
        title: Text('Track Applications'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchApplications,
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationList(),
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => JobSeekerChatPage()),
                (route) => false,
              );
              break;
            case 1:
              // Already on TrackApplicationPage
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
          Icon(Icons.work_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No Job Applications Yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Search for jobs in the chat and apply to see them here",
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => JobSeekerChatPage()),
                (route) => false,
              );
            },
            child: Text("Search Jobs"),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final application = _applications[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ExpansionTile(
            title: Text(
              application.jobTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  application.companyName,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(application.status)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(application.status),
                        ),
                      ),
                      child: Text(
                        application.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(application.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Applied Date',
                      _formatDate(application.appliedDate),
                      Icons.calendar_today,
                    ),
                    if (application.lastUpdateDate != null)
                      _buildDetailRow(
                        'Last Updated',
                        _formatDate(application.lastUpdateDate),
                        Icons.update,
                      ),
                    if (application.coverLetter != null && application.coverLetter!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.message, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                'Cover Letter:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(application.coverLetter!),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Action buttons
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
                            onPressed: () => _showWithdrawConfirmation(application),
                          ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: const Text('Search More Jobs'),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => JobSeekerChatPage()),
                              (route) => false,
                            );
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
    );
  }

  void _showWithdrawConfirmation(JobApplication application) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Withdraw Application?"),
          content: Text(
            "Are you sure you want to withdraw your application for ${application.jobTitle} at ${application.companyName}? This action cannot be undone."
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                "Withdraw",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _withdrawApplication(application.id);
              },
            ),
          ],
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