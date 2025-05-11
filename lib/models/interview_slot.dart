// lib/models/interview_slot.dart
import 'package:intl/intl.dart';

class InterviewSlot {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String? meetingLink;
  final bool isBooked;
  final String? notes;
  final String? bookedByJobSeekerId;
  final String? bookedByJobSeekerName;

  InterviewSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.meetingLink,
    this.isBooked = false,
    this.notes,
    this.bookedByJobSeekerId,
    this.bookedByJobSeekerName,
  });

  // Create from map (from Firestore)
  factory InterviewSlot.fromMap(Map<String, dynamic> data) {
    return InterviewSlot(
      id: data['id'] ?? '',
      startTime: data['start_time'] != null 
        ? (data['start_time'] is DateTime 
            ? data['start_time'] 
            : DateTime.parse(data['start_time']))
        : DateTime.now(),
      endTime: data['end_time'] != null 
        ? (data['end_time'] is DateTime 
            ? data['end_time'] 
            : DateTime.parse(data['end_time']))
        : DateTime.now(),
      meetingLink: data['meeting_link'],
      isBooked: data['is_booked'] ?? false,
      notes: data['notes'],
      bookedByJobSeekerId: data['booked_by_job_seeker_id'],
      bookedByJobSeekerName: data['booked_by_job_seeker_name'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'meeting_link': meetingLink,
      'is_booked': isBooked,
      'notes': notes,
      'booked_by_job_seeker_id': bookedByJobSeekerId,
      'booked_by_job_seeker_name': bookedByJobSeekerName,
    };
  }
  
  // Format the time slot for display
  String formatTimeSlot() {
    // Format: "May 10, 2025 • 10:00 AM - 11:00 AM"
    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');
    
    final String date = dateFormat.format(startTime);
    final String startFormatted = timeFormat.format(startTime);
    final String endFormatted = timeFormat.format(endTime);
    
    return "$date • $startFormatted - $endFormatted";
  }
}