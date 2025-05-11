// In lib/models/job.dart, add the field for interview dates

class Job {
  final String id;
  final String jobTitle;
  final String companyName;
  final String jobLocation;
  final String jobSkills;
  final String jobDescription;
  final String employerId;
  final String status;
  final DateTime postDate;
  final List<DateTime>? interviewDates; // New field for available interview dates

  Job({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.jobLocation,
    required this.jobSkills,
    required this.jobDescription,
    required this.employerId,
    required this.status,
    required this.postDate,
    this.interviewDates,
  });

  // Create from Firestore data
  factory Job.fromMap(Map<String, dynamic> data, String id) {
    // Parse interview dates if they exist
    List<DateTime>? dates;
    if (data['interview_dates'] != null) {
      dates = (data['interview_dates'] as List)
          .map((dateStr) => DateTime.parse(dateStr.toString()))
          .toList();
    }
    
    return Job(
      id: id,
      jobTitle: data['job_title'] ?? 'No Title',
      companyName: data['company_name'] ?? 'Unknown Company',
      jobLocation: data['job_location'] ?? 'No Location',
      jobSkills: data['job_skills'] ?? 'Not specified',
      jobDescription: data['job_description'] ?? '',
      employerId: data['employer_id'] ?? '',
      status: data['status'] ?? 'active',
      postDate: data['post_date'] != null 
          ? (data['post_date'] is DateTime 
              ? data['post_date'] 
              : DateTime.parse(data['post_date']))
          : DateTime.now(),
      interviewDates: dates,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'job_title': jobTitle,
      'company_name': companyName,
      'job_location': jobLocation,
      'job_skills': jobSkills,
      'job_description': jobDescription,
      'employer_id': employerId,
      'status': status,
      'post_date': postDate.toIso8601String(),
      'interview_dates': interviewDates?.map((date) => date.toIso8601String()).toList(),
    };
  }
}