// lib/services/job_application_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/services/firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

class JobApplicationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Submit a job application with optional resume
  static Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String coverLetter,
    String? resumeUrl,
  }) async {
    try {
      print("JobApplicationService: Submitting application for job ID: $jobId");
      print("JobApplicationService: Resume URL received: $resumeUrl");
      
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
      
      // Create application object with resume URL
      final application = {
        'id': applicationId,
        'job_id': jobId,
        'job_title': jobData['job_title'] ?? 'Unknown Job',
        'company_name': jobData['company_name'] ?? 'Unknown Company',
        'job_seeker_id': userId,
        'job_seeker_name': userData['personalName'] ?? 'Anonymous',
        'jobSeekerPhone': userData['phoneNumber'],
        'status': 'pending',
        'applied_date': DateTime.now().toIso8601String(),
        'cover_letter': coverLetter,
        'resume_url': resumeUrl, // Include resume URL if available
        'employer_id': employerId,
        'last_update_date': DateTime.now().toIso8601String(),
      };
      
      print("JobApplicationService: Application data prepared");
      
      // First, save to the job seeker's applications subcollection (this should always work)
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('applications')
            .doc(applicationId)
            .set(application);
        print("JobApplicationService: Saved to job seeker's subcollection");
      } catch (e) {
        print("JobApplicationService: Error saving to job seeker's subcollection: $e");
        throw e;
      }
      
      // Second, try to save to the main applications collection
      try {
        await _firestore
            .collection('applications')
            .doc(applicationId)
            .set(application);
        print("JobApplicationService: Saved to main applications collection");
      } catch (e) {
        print("JobApplicationService: Warning - Could not save to main applications collection: $e");
        // This is not critical, continue
      }
      
      // Third, try to save to employer's applications subcollection
      try {
        await _firestore
            .collection('users')
            .doc(employerId)
            .collection('applications')
            .doc(applicationId)
            .set(application);
        print("JobApplicationService: Saved to employer's subcollection");
      } catch (e) {
        print("JobApplicationService: Warning - Could not save to employer's subcollection: $e");
        // This is not critical, continue
      }
      
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
        'message': 'Error submitting application: ${e.toString()}',
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
      
      print("JobApplicationService: Found ${querySnapshot.docs.length} applications");
      
      return querySnapshot.docs
          .map((doc) => JobApplication.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("JobApplicationService: Error getting applications: $e");
      return [];
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
      final resumeUrl = appData['resume_url'] as String?;
      
      // Delete resume from Firebase Storage if it exists
      if (resumeUrl != null && resumeUrl.isNotEmpty) {
        try {
          print("JobApplicationService: Attempting to delete resume from Storage");
          
          // Extract the file path from the URL
          final ref = _storage.refFromURL(resumeUrl);
          
          // Delete the file
          await ref.delete();
          print("JobApplicationService: Resume deleted from Storage successfully");
        } catch (e) {
          print("JobApplicationService: Error deleting resume from Storage: $e");
          // Continue with application deletion even if resume deletion fails
          // This prevents the withdrawal from failing if there's an issue with storage
        }
      }
      
      // Delete the application from job seeker's subcollection
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('applications')
            .doc(applicationId)
            .delete();
        print("JobApplicationService: Deleted from job seeker's subcollection");
      } catch (e) {
        print("JobApplicationService: Error deleting from job seeker's subcollection: $e");
        throw e;
      }
      
      // Delete from main applications collection
      try {
        await _firestore
            .collection('applications')
            .doc(applicationId)
            .delete();
        print("JobApplicationService: Deleted from main applications collection");
      } catch (e) {
        print("JobApplicationService: Warning - Could not delete from main applications collection: $e");
        // Continue even if this fails
      }
      
      // Delete from employer's subcollection
      if (employerId != null) {
        try {
          await _firestore
              .collection('users')
              .doc(employerId)
              .collection('applications')
              .doc(applicationId)
              .delete();
          print("JobApplicationService: Deleted from employer's subcollection");
        } catch (e) {
          print("JobApplicationService: Warning - Could not delete from employer's subcollection: $e");
          // Continue even if this fails
        }
      }
      
      print("JobApplicationService: Application withdrawn (deleted) successfully");
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
}