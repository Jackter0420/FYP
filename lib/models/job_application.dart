// lib/models/job_application.dart
class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String companyName;
  final String jobSeekerId;
  final String jobSeekerName;
  final String status;
  final DateTime appliedDate;
  final DateTime? lastUpdateDate;
  final String? coverLetter;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
    required this.jobSeekerId,
    required this.jobSeekerName,
    required this.status,
    required this.appliedDate,
    this.lastUpdateDate,
    this.coverLetter,
  });

  // Create from Firestore data
  factory JobApplication.fromMap(Map<String, dynamic> data, String id) {
    return JobApplication(
      id: id,
      jobId: data['job_id'] ?? '',
      jobTitle: data['job_title'] ?? 'Unknown Job',
      companyName: data['company_name'] ?? 'Unknown Company',
      jobSeekerId: data['job_seeker_id'] ?? '',
      jobSeekerName: data['job_seeker_name'] ?? 'Anonymous',
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
      'status': status,
      'applied_date': appliedDate.toIso8601String(),
      'last_update_date': lastUpdateDate?.toIso8601String(),
      'cover_letter': coverLetter,
    };
  }
}