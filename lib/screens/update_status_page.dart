// update_status_page.dart
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/employer_chat_page.dart';
import 'package:prototype_2/screens/manage_jobs_page.dart';

class UpdateStatusPage extends StatefulWidget {
  @override
  State<UpdateStatusPage> createState() => _UpdateStatusPageState();
}

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  int _currentIndex = 2;
  @override
  Widget build(BuildContext context) {
    // Sample applications data - in real app, this would come from a database
    final List<Map<String, dynamic>> applications = [
      {
        'applicant': {
          'name': 'John Doe',
          'email': 'john.doe@email.com',
          'phone': '0135508970',
        },
        'job': {
          'title': 'Senior Flutter Developer',
          'company': 'Tech Solutions Inc.',
        },
        'status': 'Under Review',
        'appliedDate': '2024-01-15',
        'resume': 'john_doe_resume.pdf',
        'coverLetter': 'I am writing to express my interest...',
      },
      {
        'applicant': {
          'name': 'Jane Smith',
          'email': 'jane.smith@email.com',
          'phone': '0137787786',
        },
        'job': {
          'title': 'Mobile App Developer',
          'company': 'Digital Innovations',
        },
        'status': 'Under Review',
        'appliedDate': '2024-01-18',
        'resume': 'jane_smith_resume.pdf',
        'coverLetter': 'With five years of mobile development experience...',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      appBar: AppBar(
        title: const Text('Update Application Status'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final application = applications[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ExpansionTile(
                    title: Text(
                      application['applicant']['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      application['job']['title'],
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
                              Icons.email,
                              application['applicant']['email'],
                            ),
                            _buildDetailRow(
                              Icons.phone,
                              application['applicant']['phone'],
                            ),
                            _buildDetailRow(
                              Icons.calendar_today,
                              'Applied on: ${application['appliedDate']}',
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Cover Letter Preview
                            const Text(
                              'Cover Letter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              application['coverLetter'],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
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
                                    value: application['status'],
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: [
                                      'Under Review',
                                      'Approved',
                                      'Rejected',
                                    ].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      // Implement status update logic
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    // Implement update confirmation
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('Update Status'),
                                          content: const Text(
                                            'Do you want to update the application status?'
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
                                                // Implement status update
                                                Navigator.of(context).pop();
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
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.description),
                                  label: const Text('View Form and Resume'),
                                  onPressed: () {
                                    // Implement resume view logic
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.mail),
                                  label: const Text('Contact'),
                                  onPressed: () {
                                    // Implement contact logic
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