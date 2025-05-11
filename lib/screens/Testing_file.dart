// lib/screens/candidate_search_page.dart - Part 1
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/manage_jobs_page.dart';
import 'package:prototype_2/screens/update_status_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/widgets/employer_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/services/recommendation_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CandidateSearchPage extends StatefulWidget {
  const CandidateSearchPage({Key? key}) : super(key: key);

  @override
  State<CandidateSearchPage> createState() => _CandidateSearchPageState();
}

class _CandidateSearchPageState extends State<CandidateSearchPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 3; // Navigation index for candidate search
  bool _isLoading = true;
  List<Map<String, dynamic>> _employerJobs = [];
  String? _selectedJobId;
  List<JobMatch> _recommendedJobSeekers = [];
  
  // For manual search
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedSkills = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // For filtering
  String _sortCriteria = 'match'; // 'match', 'name', 'recentlyActive'
  
  // For tab controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEmployerJobs();
    
    // Add listener for tab changes
    _tabController.addListener(() {
      // Clear search when switching tabs
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchResults = [];
          _searchController.clear();
          _selectedSkills = [];
        });
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
Future<void> _fetchEmployerJobs() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Get current user ID
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("No user logged in");
    }
    
    // Fetch jobs from the user's jobs subcollection
    // Important: Use same sorting as Manage Jobs page (by post_date)
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobs')
        .where('status', isEqualTo: 'active')
        .orderBy('post_date', descending: true)
        .get();
    
    List<Map<String, dynamic>> jobs = [];
    
    // Add job number to each job
    int jobIndex = 0;
    for (var doc in snapshot.docs) {
      jobIndex++;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      jobs.add({
        'id': doc.id,
        'title': data['job_title'] ?? 'No Title',
        'company': data['company_name'] ?? 'Your Company',
        'location': data['job_location'] ?? 'No Location',
        'jobNumber': jobIndex, // Add job number
        'post_date': data['post_date'] ?? '',
        ...data,
      });
    }
    
    setState(() {
      _employerJobs = jobs;
      _isLoading = false;
      
      // Auto-select the first job if available
      if (jobs.isNotEmpty && _selectedJobId == null) {
        _selectedJobId = jobs[0]['id'];
        _fetchRecommendedJobSeekers();
      }
    });
  } catch (e) {
    print("Error fetching employer jobs: $e");
    setState(() {
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading jobs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  
  Future<void> _fetchRecommendedJobSeekers() async {
    if (_selectedJobId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matches = await RecommendationService.getRecommendedJobSeekersForJob(_selectedJobId!);
      
      // Sort based on selected criteria
      _sortMatches(matches);
      
      setState(() {
        _recommendedJobSeekers = matches;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching recommendations: $e");
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recommendations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Sort matches based on the selected criteria
  void _sortMatches(List<JobMatch> matches) {
    switch (_sortCriteria) {
      case 'match':
        // Default: already sorted by match percentage
        break;
      case 'name':
        matches.sort((a, b) => a.jobSeekerName.compareTo(b.jobSeekerName));
        break;
      case 'recentlyActive':
        // Sort by last activity (this would require adding 'lastActive' to your JobMatch model)
        // For now, we'll just leave the default sorting
        break;
    }
  }
  
  bool _hasSearched = false; // Track if a search has been performed

// Then modify the _performManualSearch method to set this flag:
Future<void> _performManualSearch() async {
  final searchTerm = _searchController.text.trim();
  
  if (searchTerm.isEmpty && _selectedSkills.isEmpty) {
    // Nothing to search for
    return;
  }
  
  setState(() {
    _isSearching = true;
    _hasSearched = true; // Set the flag when search is performed
  });
  
  try {
    final results = await RecommendationService.searchJobSeekers(
      searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
      requiredSkills: _selectedSkills.isNotEmpty ? _selectedSkills : null,
    );
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  } catch (e) {
    print("Error during manual search: $e");
    setState(() {
      _isSearching = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error performing search: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  
  void _addSkill(String skill) {
    if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
      setState(() {
        _selectedSkills.add(skill);
      });
      _searchController.clear();
    }
  }
  
  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }
  
  // Build the job selector dropdown
 Widget _buildJobSelector() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 1,
          offset: const Offset(0, 1),
        ),
      ],
    ),
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
                    'Select a Job Posting:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find candidates that match your job requirements',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Sort options dropdown
            PopupMenuButton<String>(
              icon: Icon(Icons.sort),
              tooltip: 'Sort Candidates',
              onSelected: (value) {
                setState(() {
                  _sortCriteria = value;
                  // Re-sort the current list
                  _sortMatches(_recommendedJobSeekers);
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'match',
                  child: Row(
                    children: [
                      Icon(
                        Icons.percent,
                        color: _sortCriteria == 'match' ? Theme.of(context).primaryColor : null,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Match Percentage',
                        style: TextStyle(
                          fontWeight: _sortCriteria == 'match' ? FontWeight.bold : FontWeight.normal,
                          color: _sortCriteria == 'match' ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name',
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_by_alpha,
                        color: _sortCriteria == 'name' ? Theme.of(context).primaryColor : null,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Name (A-Z)',
                        style: TextStyle(
                          fontWeight: _sortCriteria == 'name' ? FontWeight.bold : FontWeight.normal,
                          color: _sortCriteria == 'name' ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          value: _selectedJobId,
          items: _employerJobs.map((job) {
            return DropdownMenuItem<String>(
              value: job['id'],
              child: Text(
                "#${job['jobNumber']} - ${job['title']}",
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedJobId = value;
              });
              _fetchRecommendedJobSeekers();
            }
          },
        ),
      ],
    ),
  );
}
  
  // Build recommendations list
  Widget _buildRecommendationsList() {
    if (_recommendedJobSeekers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No matching candidates found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try selecting a different job posting or use the manual search tab to find candidates with specific skills.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _recommendedJobSeekers.length,
      itemBuilder: (context, index) {
        final match = _recommendedJobSeekers[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Text(
                        match.jobSeekerName.isNotEmpty 
                            ? match.jobSeekerName[0].toUpperCase() 
                            : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.jobSeekerName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            match.jobSeekerData['preferredJobTitle'] ?? 'Job Seeker',
                            style: TextStyle(
                              fontSize: 14,
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
                const SizedBox(height: 16),
                
                // Skills section
                Text(
                  'Skills:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: match.jobSeekerSkills.map((skill) {
                    final isMatchingSkill = match.jobRequiredSkills.any(
                      (reqSkill) => reqSkill.toLowerCase().contains(skill.toLowerCase()) || 
                                    skill.toLowerCase().contains(reqSkill.toLowerCase())
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
                
                // Experience section if available
                if (match.jobSeekerData.containsKey('workingExperience') && 
                    match.jobSeekerData['workingExperience'] != null &&
                    match.jobSeekerData['workingExperience'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Experience:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.jobSeekerData['workingExperience'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
                
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.email),
                      label: const Text('Contact'),
                      onPressed: () {
                        final email = match.jobSeekerData['email'];
                        if (email != null) {
                          _launchUrl('mailto:$email');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person),
                      label: const Text('View Profile'),
                      onPressed: () {
                        _showJobSeekerProfile(match);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Build manual search tab
 Widget _buildManualSearchTab() {
  return Column(
    children: [
      // Search bar with skills input
      Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Candidates',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Find candidates by name, job title, or specific skills',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or job title',
                prefixIcon: Icon(Icons.search,size:18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12), 
                isDense: true, 
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear,size:18),
                  onPressed: () {
                    _searchController.clear();
                  },
                   padding: EdgeInsets.zero,
                  constraints: BoxConstraints(maxHeight: 32, maxWidth: 32),
                ),
              ),
              onSubmitted: (_) => _performManualSearch(),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Required Skills:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            
            // Display selected skills as chips
            if (_selectedSkills.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: _selectedSkills.map((skill) {
                  return Chip(
                    label: Text(skill, style: TextStyle(fontSize: 12)),
                    deleteIcon: Icon(Icons.close, size: 14),
                    onDeleted: () => _removeSkill(skill),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: EdgeInsets.symmetric(horizontal: 4), 
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Add skill (e.g., Flutter, React)',
                      hintStyle: TextStyle(fontSize: 12),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14),
                    onSubmitted: (value) {
                      _addSkill(value.trim());
                    },
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _performManualSearch,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Smaller padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size(60, 36), // Smaller minimum size
                  ),
                  child: Text(
                    'Search',
                    style: TextStyle(fontSize: 13), // Smaller text
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      
      // Quick skill suggestions - only shown if user hasn't searched yet
      if (!_hasSearched)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Popular Skills:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  'coding','SQL', 'Flutter', 'Python', 'Java', 
                ].map((skill) => ActionChip(
                  label: Text(skill, style: TextStyle(fontSize: 14),),
                  onPressed: () => _addSkill(skill),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  visualDensity: VisualDensity(horizontal: -4, vertical: -4), // More compact
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                )).toList(),
              ),
            ],
          ),
        ),
      
      // Search results
      Expanded(
        child: _isSearching
            ? Center(child: CircularProgressIndicator())
            : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try different search terms or skills',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final jobSeeker = _searchResults[index];
                      
                      // Extract skills
                      List<String> skills = [];
                      if (jobSeeker.containsKey('skills')) {
                        if (jobSeeker['skills'] is List) {
                          skills = List<String>.from(
                              jobSeeker['skills'].map((skill) => skill.toString()));
                        } else if (jobSeeker['skills'] is String) {
                          String skillsText = jobSeeker['skills'];
                          skills = skillsText
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                        }
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    child: Text(
                                      jobSeeker['personalName'] != null && 
                                          jobSeeker['personalName'].toString().isNotEmpty
                                          ? jobSeeker['personalName'][0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          jobSeeker['personalName']?.toString() ?? 'Anonymous',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          jobSeeker['preferredJobTitle']?.toString() ?? 'Job Seeker',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Skills section
                              Text(
                                'Skills:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: skills.map((skill) {
                                  final isMatchingSkill = _selectedSkills.any(
                                    (reqSkill) => reqSkill.toLowerCase().contains(skill.toLowerCase()) ||
                                          skill.toLowerCase().contains(reqSkill.toLowerCase())
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
                              
                              // Experience section if available
                              if (jobSeeker.containsKey('workingExperience') &&
                                  jobSeeker['workingExperience'] != null &&
                                  jobSeeker['workingExperience'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Experience:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  jobSeeker['workingExperience'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: Icon(Icons.email),
                                    label: Text('Contact'),
                                    onPressed: () {
                                      final email = jobSeeker['email'];
                                      if (email != null) {
                                        _launchUrl('mailto:$email');
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.person),
                                    label: Text('View Profile'),
                                    onPressed: () {
                                      _showJobSeekerProfileFromSearch(jobSeeker);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ],
  );
}
  
  // Show job seeker profile dialog from recommendations
void _showJobSeekerProfile(JobMatch match) {
  // Find the job number based on the job ID
  int jobNumber = 0;
  for (var job in _employerJobs) {
    if (job['id'] == match.jobId) {
      jobNumber = job['jobNumber'];
      break;
    }
  }

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
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Text(
                    match.jobSeekerName.isNotEmpty 
                        ? match.jobSeekerName[0].toUpperCase() 
                        : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.jobSeekerName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        match.jobSeekerData['preferredJobTitle'] ?? 'Job Seeker',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                      if (match.jobSeekerData.containsKey('email') && 
                          match.jobSeekerData['email'] != null)
                        Text(
                          match.jobSeekerData['email'],
                          style: TextStyle(fontSize: 14),
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
                    // Skills section
                    Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: match.jobSeekerSkills.map((skill) {
                        final isMatchingSkill = match.jobRequiredSkills.any(
                          (reqSkill) => reqSkill.toLowerCase().contains(skill.toLowerCase()) || 
                                    skill.toLowerCase().contains(reqSkill.toLowerCase())
                        );
                        
                        return Chip(
                          label: Text(skill),
                          backgroundColor: isMatchingSkill 
                              ? Colors.green.withOpacity(0.2) 
                              : Colors.grey.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isMatchingSkill ? Colors.green[800] : Colors.black87,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Experience section
                    Text(
                      'Experience',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match.jobSeekerData['workingExperience']?.toString() ?? 'No experience information provided.',
                    ),
                    const SizedBox(height: 16),
                    
                    // Match details section - now with job number
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
                            Text('Matching for:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(jobNumber > 0 ? "#$jobNumber - ${match.jobTitle}" : match.jobTitle),
                            const SizedBox(height: 8),
                            Text('Required Skills:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(match.jobRequiredSkills.join(', ')),
                            const SizedBox(height: 8),
                            Text('Candidate Skills:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(match.jobSeekerSkills.join(', ')),
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
                  icon: Icon(Icons.email),
                  label: Text('Contact Candidate'),
                  onPressed: () {
                    final email = match.jobSeekerData['email'];
                    if (email != null) {
                      Navigator.pop(context);
                      _launchUrl('mailto:$email');
                    }
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
  
  // Show job seeker profile dialog from search results
  void _showJobSeekerProfileFromSearch(Map<String, dynamic> jobSeeker) {
    // Extract skills
    List<String> skills = [];
    if (jobSeeker.containsKey('skills')) {
      if (jobSeeker['skills'] is List) {
        skills = List<String>.from(
            jobSeeker['skills'].map((skill) => skill.toString()));
      } else if (jobSeeker['skills'] is String) {
        String skillsText = jobSeeker['skills'];
        skills = skillsText
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    
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
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      jobSeeker['personalName'] != null && 
                          jobSeeker['personalName'].toString().isNotEmpty
                          ? jobSeeker['personalName'][0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobSeeker['personalName']?.toString() ?? 'Anonymous',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          jobSeeker['preferredJobTitle']?.toString() ?? 'Job Seeker',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        if (jobSeeker.containsKey('email') && 
                            jobSeeker['email'] != null)
                          Text(
                            jobSeeker['email'],
                            style: TextStyle(fontSize: 14),
                          ),
                      ],
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
                      // Skills section
                      Text(
                        'Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills.map((skill) {
                          final isMatchingSkill = _selectedSkills.any(
                            (reqSkill) => reqSkill.toLowerCase().contains(skill.toLowerCase()) ||
                                  skill.toLowerCase().contains(reqSkill.toLowerCase())
                          );
                          
                          return Chip(
                            label: Text(skill),
                            backgroundColor: isMatchingSkill 
                                ? Colors.green.withOpacity(0.2) 
                                : Colors.grey.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isMatchingSkill ? Colors.green[800] : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Experience section
                      Text(
                        'Experience',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        jobSeeker['workingExperience']?.toString() ?? 'No experience information provided.',
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
                    icon: Icon(Icons.email),
                    label: Text('Contact Candidate'),
                    onPressed: () {
                      final email = jobSeeker['email'];
                      if (email != null) {
                        Navigator.pop(context);
                        _launchUrl('mailto:$email');
                      }
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
      title: 'Candidate Search',
      ),
      body: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'AI Recommendations'),
              Tab(text: 'Manual Search'),
            ],
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // AI Recommendations Tab
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _employerJobs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.work_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No active job postings found",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Please create a job posting first to see AI-recommended candidates",
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
                                    child: Text("Create Job Posting"),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              _buildJobSelector(),
                              Expanded(child: _buildRecommendationsList()),
                            ],
                          ),
                
                // Manual Search Tab
                _buildManualSearchTab(),
              ],
            ),
          ),
          
          // Bottom navigation
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
                case 3:
                  // Already on this page
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}