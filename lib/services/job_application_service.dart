// lib/services/job_application_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/services/firebase_service.dart';

class JobApplicationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a job application
  static Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String coverLetter,
  }) async {
    try {
      print("JobApplicationService: Submitting application for job ID: $jobId");
      
      // Ensure user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("JobApplicationService: Error - No user logged in");
        return {
          'success': false,
          'message': 'You must be logged in to apply for jobs',
        };
      }
      
      final userId = currentUser.uid;
      
      // Get job details
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) {
        print("JobApplicationService: Error - Job not found");
        return {
          'success': false,
          'message': 'Job not found',
        };
      }
      
      final jobData = jobDoc.data()!;
      final employerId = jobData['employer_id'] as String?;
      
      if (employerId == null) {
        print("JobApplicationService: Error - Employer ID not found in job data");
        return {
          'success': false,
          'message': 'Unable to determine employer for this job',
        };
      }
      
      // Get job seeker details
      final userData = await FirebaseService.getUserData(userId);
      if (userData == null) {
        print("JobApplicationService: Error - User data not found");
        return {
          'success': false,
          'message': 'Unable to retrieve your profile information',
        };
      }
      
      // Create a unique ID for the application
      final applicationId = _firestore.collection('applications').doc().id;
      
      // Create application object
      final application = JobApplication(
        id: applicationId,
        jobId: jobId,
        jobTitle: jobData['job_title'] ?? 'Unknown Job',
        companyName: jobData['company_name'] ?? 'Unknown Company',
        jobSeekerId: userId,
        jobSeekerName: userData['personalName'] ?? 'Anonymous',
        status: 'pending',
        appliedDate: DateTime.now(),
        coverLetter: coverLetter,
      );
      
      // Save to Firestore in three places:
      // 1. Main applications collection
      await _firestore
          .collection('applications')
          .doc(applicationId)
          .set(application.toMap());
      
      // 2. In the job seeker's applications subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .doc(applicationId)
          .set(application.toMap());
      
      // 3. In the employer's applications subcollection
      await _firestore
          .collection('users')
          .doc(employerId)
          .collection('applications')
          .doc(applicationId)
          .set(application.toMap());
      
      print("JobApplicationService: Application submitted successfully");
      return {
        'success': true,
        'message': 'Application submitted successfully',
        'applicationId': applicationId,
      };
    } catch (e) {
      print("JobApplicationService: Error submitting application: $e");
      return {
        'success': false,
        'message': 'Error submitting application: $e',
      };
    }
  }

  // Get all applications for the current job seeker
  static Future<List<JobApplication>> getMyApplications() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("JobApplicationService: Error - No user logged in");
        return [];
      }
      
      final userId = currentUser.uid;
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .orderBy('applied_date', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => JobApplication.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("JobApplicationService: Error getting applications: $e");
      return [];
    }
  }

  // Withdraw an application
  static Future<Map<String, dynamic>> withdrawApplication(String applicationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("JobApplicationService: Error - No user logged in");
        return {
          'success': false,
          'message': 'You must be logged in to withdraw applications',
        };
      }
      
      final userId = currentUser.uid;
      
      // Get the application to verify ownership and get related data
      final appDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .doc(applicationId)
          .get();
          
      if (!appDoc.exists) {
        print("JobApplicationService: Error - Application not found");
        return {
          'success': false,
          'message': 'Application not found',
        };
      }
      
      final appData = appDoc.data()!;
      final employerId = appData['employer_id'];
      
      // Update application status to 'withdrawn' in all three locations
      final updateData = {
        'status': 'withdrawn',
        'last_update_date': DateTime.now().toIso8601String(),
      };
      
      // 1. Main applications collection
      await _firestore
          .collection('applications')
          .doc(applicationId)
          .update(updateData);
      
      // 2. In the job seeker's applications subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .doc(applicationId)
          .update(updateData);
      
      // 3. In the employer's applications subcollection
      if (employerId != null) {
        await _firestore
            .collection('users')
            .doc(employerId)
            .collection('applications')
            .doc(applicationId)
            .update(updateData);
      }
      
      print("JobApplicationService: Application withdrawn successfully");
      return {
        'success': true,
        'message': 'Application withdrawn successfully',
      };
    } catch (e) {
      print("JobApplicationService: Error withdrawing application: $e");
      return {
        'success': false,
        'message': 'Error withdrawing application: $e',
      };
    }
  }
  
  // Check if the user has already applied for a job
  static Future<bool> hasApplied(String jobId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }
      
      final userId = currentUser.uid;
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .where('job_id', isEqualTo: jobId)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("JobApplicationService: Error checking application status: $e");
      return false;
    }
  }
  
  // Get application status for a specific job
  static Future<String?> getApplicationStatus(String jobId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return null;
      }
      
      final userId = currentUser.uid;
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .where('job_id', isEqualTo: jobId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      return querySnapshot.docs.first.data()['status'] as String?;
    } catch (e) {
      print("JobApplicationService: Error getting application status: $e");
      return null;
    }
  }
}