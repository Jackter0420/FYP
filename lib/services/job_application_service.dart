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
    String? selectedSlotId,
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

// NEW METHOD: Submit application with interview slot selection
  static Future<Map<String, dynamic>> submitApplicationWithInterview({
    required String jobId,
    required String coverLetter,
    String? resumeUrl,
    String? selectedSlotId,
  }) async {
    try {
      print("JobApplicationService: Submitting application with interview slot for job ID: $jobId");
      
      // First submit the regular application
      final result = await submitApplication(
        jobId: jobId,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
      );
      
      if (!result['success']) {
        return result;
      }
      
      final applicationId = result['applicationId'];
      
      // If interview slot is selected, book it
      if (selectedSlotId != null && selectedSlotId.isNotEmpty) {
        print("JobApplicationService: Booking interview slot: $selectedSlotId");
        
        final slotBooked = await bookInterviewSlot(
          jobId: jobId,
          applicationId: applicationId,
          slotId: selectedSlotId,
        );
        
        if (!slotBooked) {
          // Application was submitted but slot booking failed
          return {
            'success': true,
            'applicationId': applicationId,
            'message': 'Application submitted successfully, but interview slot booking failed.',
          };
        }
      }
      
      return {
        'success': true,
        'applicationId': applicationId,
        'message': selectedSlotId != null ? 
          'Application submitted with interview slot booked!' : 
          'Application submitted successfully',
      };
    } catch (e) {
      print("JobApplicationService: Error in submitApplicationWithInterview: $e");
      return {
        'success': false,
        'message': 'Error submitting application: ${e.toString()}',
      };
    }
  }

  // NEW METHOD: Book an interview slot
 static Future<bool> bookInterviewSlot({
  required String jobId,
  required String applicationId,
  required String slotId,
}) async {
  try {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print("JobApplicationService: Error - No user logged in");
      return false;
    }
    
    // Get job data
    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    if (!jobDoc.exists) {
      print("JobApplicationService: Error - Job not found");
      return false;
    }
    
    final jobData = jobDoc.data()!;
    final employerId = jobData['employer_id'] as String?;
    
    if (employerId == null) {
      print("JobApplicationService: Error - Employer ID not found");
      return false;
    }
    
    // Check if job is still active
    final deadline = jobData['deadline'] as String?;
    if (deadline != null && deadline.isNotEmpty) {
      try {
        final deadlineDate = DateTime.parse(deadline);
        final now = DateTime.now();
        
        if (now.isAfter(deadlineDate)) {
          print("JobApplicationService: Error - Job deadline has passed");
          return false;
        }
      } catch (e) {
        print("JobApplicationService: Error parsing deadline: $e");
      }
    }
    
    // Get interview slots
    final slots = jobData['interview_slots'] as List?;
    if (slots == null) {
      print("JobApplicationService: Error - No interview slots found");
      return false;
    }
    
    // Find and update the selected slot
    List<Map<String, dynamic>> updatedSlots = [];
    bool slotFound = false;
    
    for (var slotData in slots) {
      Map<String, dynamic> slotMap = Map<String, dynamic>.from(slotData);
      
      if (slotMap['id'] == slotId) {
        // Check if slot is already booked
        if (slotMap['is_booked'] == true) {
          print("JobApplicationService: Error - Selected slot is already booked");
          return false;
        }
        
        // Check if interview slot is before deadline
        final slotStartTime = slotMap['start_time'];
        if (deadline != null && deadline.isNotEmpty) {
          try {
            final slotDate = DateTime.parse(slotStartTime);
            final deadlineDate = DateTime.parse(deadline);
            
            if (slotDate.isAfter(deadlineDate)) {
              print("JobApplicationService: Error - Interview slot is after job deadline");
              return false;
            }
          } catch (e) {
            print("JobApplicationService: Error checking slot date: $e");
          }
        }
        
        // Mark this slot as booked
        slotMap['is_booked'] = true;
        slotMap['booked_by_job_seeker_id'] = currentUser.uid;
        slotMap['booked_by_job_seeker_name'] = currentUser.displayName ?? 'Job Seeker';
        
        slotFound = true;
        print("JobApplicationService: Slot $slotId marked as booked");
      }
      
      updatedSlots.add(slotMap);
    }
    
    if (!slotFound) {
      print("JobApplicationService: Error - Slot $slotId not found");
      return false;
    }
    
    // Update job with new slot status
    await _updateJobInterviewSlots(jobId, employerId, updatedSlots);
    
    // Update application with booked slot information
    await _updateApplicationWithSlot(applicationId, slotId, currentUser.uid, employerId);
    
    print("JobApplicationService: Interview slot booked successfully");
    return true;
  } catch (e) {
    print("JobApplicationService: Error booking interview slot: $e");
    return false;
  }
}

// Helper method to update job with interview slots
static Future<void> _updateJobInterviewSlots(
  String jobId, 
  String employerId, 
  List<Map<String, dynamic>> updatedSlots
) async {
  // Update in main jobs collection
  await _firestore.collection('jobs').doc(jobId).update({
    'interview_slots': updatedSlots,
  });
  
  // Update in employer's subcollection
  await _firestore
      .collection('users')
      .doc(employerId)
      .collection('jobs')
      .doc(jobId)
      .update({
    'interview_slots': updatedSlots,
  });
}

// Helper method to update application with booked slot
static Future<void> _updateApplicationWithSlot(
  String applicationId, 
  String slotId, 
  String jobSeekerId, 
  String employerId
) async {
  final updateData = {
    'booked_interview_id': slotId,
    'interview_status': 'scheduled',
    'last_update_date': DateTime.now().toIso8601String(),
  };
  
  // Update application in main collection
  await _firestore.collection('applications').doc(applicationId).update(updateData);
  
  // Update application in job seeker's subcollection
  await _firestore
      .collection('users')
      .doc(jobSeekerId)
      .collection('applications')
      .doc(applicationId)
      .update(updateData);
  
  // Update application in employer's subcollection
  await _firestore
      .collection('users')
      .doc(employerId)
      .collection('applications')
      .doc(applicationId)
      .update(updateData);
}

// Add a method to check and remove expired interview slots
static Future<void> checkAndRemoveExpiredInterviewSlots() async {
  try {
    final now = DateTime.now();
    
    // Get all jobs with interview slots
    final jobsSnapshot = await _firestore
        .collection('jobs')
        .where('has_interview_slots', isEqualTo: true)
        .get();
    
    for (var jobDoc in jobsSnapshot.docs) {
      final jobData = jobDoc.data();
      final deadline = jobData['deadline'] as String?;
      
      if (deadline != null && deadline.isNotEmpty) {
        try {
          final deadlineDate = DateTime.parse(deadline);
          
          // If deadline has passed, disable interview slots
          if (now.isAfter(deadlineDate)) {
            await _disableJobInterviewSlots(jobDoc.id, jobData['employer_id']);
          }
        } catch (e) {
          print("Error checking job deadline: $e");
        }
      }
    }
  } catch (e) {
    print("Error checking expired interview slots: $e");
  }
}

// Helper method to disable interview slots for expired jobs
static Future<void> _disableJobInterviewSlots(String jobId, String employerId) async {
  try {
    final updateData = {
      'interview_slots': [],
      'has_interview_slots': false,
      'interview_slots_disabled': true,
      'interview_slots_disabled_date': DateTime.now().toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    // Update in main jobs collection
    await _firestore.collection('jobs').doc(jobId).update(updateData);
    
    // Update in employer's subcollection
    if (employerId != null) {
      await _firestore
          .collection('users')
          .doc(employerId)
          .collection('jobs')
          .doc(jobId)
          .update(updateData);
    }
    
    print("Disabled interview slots for expired job: $jobId");
  } catch (e) {
    print("Error disabling interview slots: $e");
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