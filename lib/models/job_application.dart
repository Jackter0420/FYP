// Complete job_application.dart model

import 'package:intl/intl.dart';
import 'package:prototype_2/models/interview_slot.dart';

class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String companyName;
  final String jobSeekerId;
  final String jobSeekerName;
  final String? jobSeekerPhone;
  final String status;
  final DateTime appliedDate;
  final DateTime? lastUpdateDate;
  final String? coverLetter;
  final String? resumeUrl;

  // Interview related fields
  final List<InterviewSlot>? interviewSlots; // Slots provided by employer
  final String? bookedInterviewId; // Slot selected by job seeker
  final String? interviewStatus; // Status of the interview (scheduled, completed, etc.)

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
    required this.jobSeekerId,
    required this.jobSeekerName,
    this.jobSeekerPhone,
    required this.status,
    required this.appliedDate,
    this.lastUpdateDate,
    this.coverLetter,
    this.resumeUrl,
    this.interviewSlots,
    this.bookedInterviewId,
    this.interviewStatus,
  });

  // Create from Firestore data
  factory JobApplication.fromMap(Map<String, dynamic> data, String id) {
    // Parse interview slots if they exist
    List<InterviewSlot>? slots;
    if (data['interview_slots'] != null) {
      slots = (data['interview_slots'] as List)
          .map((slotData) => InterviewSlot.fromMap(slotData))
          .toList();
    }

    return JobApplication(
      id: id,
      jobId: data['job_id'] ?? '',
      jobTitle: data['job_title'] ?? 'Unknown Job',
      companyName: data['company_name'] ?? 'Unknown Company',
      jobSeekerId: data['job_seeker_id'] ?? '',
      jobSeekerName: data['job_seeker_name'] ?? 'Anonymous',
      jobSeekerPhone: data['job_seeker_phone'] ?? data['jobSeekerPhone'], // Support both field names
      status: data['status'] ?? 'pending',
      appliedDate: data['applied_date'] != null 
          ? (data['applied_date'] is DateTime 
              ? data['applied_date'] 
              : DateTime.parse(data['applied_date']))
          : DateTime.now(),
      lastUpdateDate: data['last_update_date'] != null 
          ? (data['last_update_date'] is DateTime 
              ? data['last_update_date'] 
              : DateTime.parse(data['last_update_date']))
          : null,
      coverLetter: data['cover_letter'],
      resumeUrl: data['resume_url'],
      interviewSlots: slots,
      bookedInterviewId: data['booked_interview_id'],
      interviewStatus: data['interview_status'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'job_id': jobId,
      'job_title': jobTitle,
      'company_name': companyName,
      'job_seeker_id': jobSeekerId,
      'job_seeker_name': jobSeekerName,
      'job_seeker_phone': jobSeekerPhone,
      'status': status,
      'applied_date': appliedDate.toIso8601String(),
      'last_update_date': lastUpdateDate?.toIso8601String(),
      'cover_letter': coverLetter,
      'resume_url': resumeUrl,
      'interview_slots': interviewSlots?.map((slot) => slot.toMap()).toList(),
      'booked_interview_id': bookedInterviewId,
      'interview_status': interviewStatus,
    };
  }
}