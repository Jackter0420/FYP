// lib/widgets/employer_app_bar.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prototype_2/screens/update_status_page.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/screens/profile_edit_page.dart';
import 'package:prototype_2/screens/login.dart';
import 'package:prototype_2/screens/debug_login.dart';

class EmployerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title; // Can be String or Widget
  final List<Widget>? additionalActions;
  
  const EmployerAppBar({
    Key? key, 
    required this.title,
    this.additionalActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Convert String to Text widget if title is a String
      title: title is String ? Text(title) : title,
      backgroundColor: Theme.of(context).primaryColor,
      actions: [
        // Additional actions specific to the page
        if (additionalActions != null) ...additionalActions!,
        FutureBuilder<int>(
        future: _checkUnconfirmedInterviews(),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mail),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdateStatusPage(),
                    ),
                  );
                },
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
        // Profile button
        IconButton(
          icon: const Icon(Icons.account_circle),
          tooltip: 'Profile',
          onPressed: () {
            _showProfileOptions(context, Provider.of<UserProvider>(context, listen: false).userData);
          },
        ),
        
        // Logout button
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => _showLogoutDialog(context),
        ),
      ],
    );
  }
  
  // Profile options dialog
  void _showProfileOptions(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profile Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Profile Option
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _showProfileDialog(context, userData); // Show profile details
                },
              ),
              // Edit Profile Option
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditPage(),
                    ),
                  );
                },
              ),
              // Debug Option - only in debug mode
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Debug User Data'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugLoginPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showProfileDialog(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Your Profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Name'),
                  subtitle: Text(userData['personalName'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Company'),
                  subtitle: Text(userData['companyName'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: Text(userData['phoneNumber'] ?? 'Not provided'),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(userData['email'] ?? 'Not provided'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Logout"),
              onPressed: () {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                
                // Navigate away first to avoid problems with context
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
                
                // Then sign out
                userProvider.signOut();
              },
            ),
          ],
        );
      },
    );
  }
Future<int> _checkUnconfirmedInterviews() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 0;
    
    // Use fields that actually exist in your Firebase structure
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('applications')
        .where('booked_interview_id', isNull: false)  // ← This field EXISTS
        .get();
    
    int unconfirmedCount = 0;
    
    // Filter in code to avoid compound query index requirement
    for (var doc in querySnapshot.docs) {
      final appData = doc.data();
      
      // Count interviews that are scheduled but not yet confirmed/completed
      final interviewStatus = appData['interview_status'] ?? '';
      
      // Show badge for scheduled interviews awaiting employer action
      if (interviewStatus == 'scheduled') {
        unconfirmedCount++;
      }
    }
    
    return unconfirmedCount;
  } catch (e) {
    print('Error checking unconfirmed interviews: $e');
    return 0;
  }
}
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}