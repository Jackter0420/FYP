// lib/services/job_application_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prototype_2/models/job_application.dart';
import 'package:prototype_2/services/firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:prototype_2/models/interview_slot.dart';


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


// Helper method to get the user's display name
static Future<String> _getUserDisplayName(String userId) async {
  try {
    // First try to get from Firestore
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null) {
        // Try to get personalName first, then fall back to other fields
        String? name = userData['personalName'] as String?;
        if (name != null && name.isNotEmpty) {
          return name;
        }
        
        // Fall back to other potential name fields
        name = userData['displayName'] as String?;
        if (name != null && name.isNotEmpty) {
          return name;
        }
        
        name = userData['fullName'] as String?;
        if (name != null && name.isNotEmpty) {
          return name;
        }
        
        // If we have an email, use that as last resort
        final email = userData['email'] as String?;
        if (email != null && email.isNotEmpty) {
          return email.split('@')[0]; // Use part before @ as name
        }
      }
    }
    
    // Fall back to Firebase Auth display name
    final authUser = _auth.currentUser;
    if (authUser != null && authUser.displayName != null && authUser.displayName!.isNotEmpty) {
      return authUser.displayName!;
    }
    
    // If all else fails, just return 'Job Seeker'
    return 'Job Seeker';
  } catch (e) {
    print("Error getting user display name: $e");
    return 'Job Seeker';
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

static Future<Map<String, dynamic>> bookInterviewSlot(
    String applicationId,
    String jobId,
    String slotId,
  ) async {
    try {
      print("=== BOOKING INTERVIEW SLOT ===");
      print("Application ID: $applicationId");
      print("Job ID: $jobId");
      print("Slot ID: $slotId");
      
      // Ensure user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'You must be logged in to book an interview slot',
        };
      }
      
      final userId = currentUser.uid;
      print("User ID: $userId");
      
      // STEP 1: Get user name for booking record
      String userName = 'Job Seeker';
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['personalName'] ?? 'Job Seeker';
        }
      } catch (e) {
        print("Warning: Could not get user name: $e");
      }
      print("User name: $userName");
      
      // STEP 2: Get application data and employer ID from job seeker's subcollection
      DocumentSnapshot jobSeekerAppDoc;
      String? employerId;
      Map<String, dynamic>? fullApplicationData;
      
      try {
        jobSeekerAppDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('applications')
            .doc(applicationId)
            .get();
            
        if (!jobSeekerAppDoc.exists) {
          throw Exception('Application not found in your records');
        }
        
        fullApplicationData = jobSeekerAppDoc.data() as Map<String, dynamic>;
        employerId = fullApplicationData['employer_id'] as String?;
        
        if (employerId == null) {
          throw Exception('Could not find employer ID for this application');
        }
        
        print("Found employer ID: $employerId");
      } catch (e) {
        print("Error getting application data: $e");
        return {
          'success': false,
          'message': 'Could not find application data: $e',
        };
      }
      
      // STEP 3: Update the job document to mark slot as booked
      try {
        print("Updating job document...");
        
        final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
        if (!jobDoc.exists) {
          throw Exception('Job not found');
        }
        
        final jobData = jobDoc.data() as Map<String, dynamic>;
        final interviewSlots = jobData['interview_slots'] as List<dynamic>?;
        
        if (interviewSlots == null || interviewSlots.isEmpty) {
          throw Exception('No interview slots available for this job');
        }
        
        // Find and update the slot
        bool slotFound = false;
        List<dynamic> updatedSlots = [];
        
        for (var slotData in interviewSlots) {
          if (slotData['id'] == slotId) {
            // Check if slot is already booked
            if (slotData['is_booked'] == true) {
              throw Exception('This interview slot has already been booked');
            }
            
            // Update the slot
            slotData['is_booked'] = true;
            slotData['booked_by_job_seeker_id'] = userId;
            slotData['booked_by_job_seeker_name'] = userName;
            slotData['booking_timestamp'] = DateTime.now().toIso8601String();
            slotFound = true;
            print("Slot found and marked as booked");
          }
          updatedSlots.add(slotData);
        }
        
        if (!slotFound) {
          throw Exception('Interview slot not found');
        }
        
        // Update the job document
        await _firestore.collection('jobs').doc(jobId).update({
          'interview_slots': updatedSlots,
        });
        
        print("✅ Job document updated successfully");
      } catch (e) {
        print("❌ Error updating job document: $e");
        return {
          'success': false,
          'message': 'Failed to book interview slot: $e',
        };
      }
      
      // STEP 4: Prepare update data for applications
      final updateData = {
        'booked_interview_id': slotId,
        'interview_status': 'scheduled',
        'last_update_date': DateTime.now().toIso8601String(),
        'interview_booking_timestamp': DateTime.now().toIso8601String(),
      };
      
      print("Update data prepared: $updateData");
      
      // STEP 5: Update job seeker's application (CRITICAL)
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('applications')
            .doc(applicationId)
            .update(updateData);
        print("✅ Job seeker's application updated");
      } catch (e) {
        print("❌ CRITICAL: Failed to update job seeker's application: $e");
        // This is critical - if we can't update job seeker's view, rollback job update
        try {
          // Rollback the job slot booking
          final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
          if (jobDoc.exists) {
            final jobData = jobDoc.data() as Map<String, dynamic>;
            final slots = jobData['interview_slots'] as List<dynamic>;
            
            for (var slot in slots) {
              if (slot['id'] == slotId) {
                slot['is_booked'] = false;
                slot.remove('booked_by_job_seeker_id');
                slot.remove('booked_by_job_seeker_name');
                slot.remove('booking_timestamp');
                break;
              }
            }
            
            await _firestore.collection('jobs').doc(jobId).update({
              'interview_slots': slots,
            });
            print("Rolled back job slot booking due to application update failure");
          }
        } catch (rollbackError) {
          print("Failed to rollback job slot booking: $rollbackError");
        }
        
        return {
          'success': false,
          'message': 'Failed to update your application record',
        };
      }
      
      // STEP 6: Update employer's application subcollection (CRITICAL FOR EMPLOYER VIEW)
      try {
        print("Updating employer's subcollection...");
        
        // Check if document exists in employer's subcollection
        final employerAppDoc = await _firestore
            .collection('users')
            .doc(employerId)
            .collection('applications')
            .doc(applicationId)
            .get();
        
        if (employerAppDoc.exists) {
          // Document exists, just update it
          await _firestore
              .collection('users')
              .doc(employerId)
              .collection('applications')
              .doc(applicationId)
              .update(updateData);
          print("✅ Employer's existing application updated");
        } else {
          // Document doesn't exist, create it with full data
          print("Employer's application document doesn't exist, creating it...");
          
          // Use the full application data we retrieved earlier
          final completeAppData = Map<String, dynamic>.from(fullApplicationData!);
          completeAppData.addAll(updateData); // Add the interview booking data
          
          await _firestore
              .collection('users')
              .doc(employerId)
              .collection('applications')
              .doc(applicationId)
              .set(completeAppData);
          print("✅ Employer's application document created with booking data");
        }
      } catch (e) {
        print("❌ Warning: Failed to update employer's application: $e");
        // Don't fail the whole operation, but this is important for employer updates
      }
      
      // STEP 7: Update main applications collection (BACKUP)
      try {
        print("Updating main applications collection...");
        
        final mainAppDoc = await _firestore
            .collection('applications')
            .doc(applicationId)
            .get();
            
        if (mainAppDoc.exists) {
          await _firestore
              .collection('applications')
              .doc(applicationId)
              .update(updateData);
          print("✅ Main applications collection updated");
        } else {
          // Create the document if it doesn't exist
          final completeAppData = Map<String, dynamic>.from(fullApplicationData!);
          completeAppData.addAll(updateData);
          
          await _firestore
              .collection('applications')
              .doc(applicationId)
              .set(completeAppData);
          print("✅ Main applications collection document created");
        }
      } catch (e) {
        print("❌ Warning: Failed to update main applications collection: $e");
        // Non-critical, continue
      }
      
      print("=== INTERVIEW BOOKING COMPLETED SUCCESSFULLY ===");
      
      return {
        'success': true,
        'message': 'Interview scheduled successfully',
        'slot_id': slotId,
      };
      
    } catch (e) {
      print("❌ JobApplicationService: Error booking interview slot: $e");
      return {
        'success': false,
        'message': 'Error booking interview slot: $e',
      };
    }
  }
}