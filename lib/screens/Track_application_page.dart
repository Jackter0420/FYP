// Enhanced Track_application_page.dart for job seekers
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/job_recommendations_page.dart';
import 'package:prototype_2/screens/jobseeker_chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/widgets/jobseeker_app_bar.dart';
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
  String _selectedFilter = 'all'; // Filter for application status

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
          "Are you sure you want to withdraw this application? This will allow you to reapply for this position."
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
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'reviewing':
      return Colors.blue;
    case 'pending':
    default:
      return Colors.amber;
  }
}

  // Get icon based on status
 IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return Icons.check_circle;
    case 'rejected':
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
  final filters = ['all', 'pending', 'reviewing', 'approved', 'rejected'];
  
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
  final approvedCount = _applications.where((app) => app.status.toLowerCase() == 'approved').length;
  final rejectedCount = _applications.where((app) => app.status.toLowerCase() == 'rejected').length;
  
  return Card(
    margin: const EdgeInsets.all(8.0),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Single row with all statuses in a more compact layout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactStatItem('Total', totalApplications, Colors.blue),
              _buildCompactStatItem('Pending', pendingCount, Colors.amber),
              _buildCompactStatItem('Reviewing', reviewingCount, Colors.blue),
              _buildCompactStatItem('Approved', approvedCount, Colors.green),
              _buildCompactStatItem('Rejected', rejectedCount, Colors.red),
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
      child: InkWell(
        onTap: () => _showApplicationDetails(application),
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
              
              // Action buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                    onPressed: () => _showApplicationDetails(application),
                  ),
                  if (application.status.toLowerCase() == 'pending')
                    TextButton.icon(
                      icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                      label: const Text('Withdraw', style: TextStyle(color: Colors.red)),
                      onPressed: () => _withdrawApplication(application.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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