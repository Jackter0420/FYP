// lib/widgets/jobseeker_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/screens/jobseeker_profile_edit_page.dart';
import 'package:prototype_2/screens/login.dart';

class JobSeekerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? additionalActions;
  
  const JobSeekerAppBar({
    Key? key, 
    required this.title,
    this.additionalActions,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // Improved logout method
  Future<void> _logout(BuildContext context) async {
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
        // Get the provider to avoid context issues after async operations
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // Navigate to login page with a new route that clears the stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        
        // Sign out user after navigation
        await userProvider.signOut();
      }
    } catch (e) {
      print("Error during logout: $e");
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error logging out: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Theme.of(context).primaryColor,
      actions: [
        // Add any additional action buttons passed in
        if (additionalActions != null) ...additionalActions!,
        
        // Profile button
        IconButton(
          icon: const Icon(Icons.account_circle),
          tooltip: 'Edit Profile',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const JobSeekerProfileEditPage()),
            );
          },
        ),
        
        // Logout button
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}