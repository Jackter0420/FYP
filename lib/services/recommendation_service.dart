// lib/services/recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class JobMatch {
  final String jobSeekerId;
  final String jobId;
  final String jobSeekerName;
  final String jobTitle;
  final String companyName;
  final List<String> jobSeekerSkills;
  final List<String> jobRequiredSkills;
  final double matchPercentage;
  final Map<String, dynamic> jobSeekerData;
  final Map<String, dynamic> jobData;

  JobMatch({
    required this.jobSeekerId,
    required this.jobId,
    required this.jobSeekerName,
    required this.jobTitle,
    required this.companyName,
    required this.jobSeekerSkills,
    required this.jobRequiredSkills,
    required this.matchPercentage,
    required this.jobSeekerData,
    required this.jobData,
  });
}

class RecommendationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get recommended job seekers for a specific job
  static Future<List<JobMatch>> getRecommendedJobSeekersForJob(String jobId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      // 1. Get the job details
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) {
        return [];
      }

      final jobData = jobDoc.data()!;
      final jobTitle = jobData['job_title'] as String? ?? '';
      final companyName = jobData['company_name'] as String? ?? '';
      
      // Extract job skills
      List<String> jobSkills = [];
      
      // Try to get skills from both formats (array and string)
      if (jobData.containsKey('job_skills') && jobData['job_skills'] is List) {
        jobSkills = List<String>.from(jobData['job_skills'].map((skill) => skill.toString().toLowerCase()));
      } else if (jobData.containsKey('job_skills_text') && jobData['job_skills_text'] is String) {
        String skillsText = jobData['job_skills_text'];
        if (skillsText.toLowerCase() != "not specified") {
          jobSkills = skillsText.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
        }
      }

      // 2. Get all job seekers
      final jobSeekerSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jobSeeker')
          .get();

      List<JobMatch> matches = [];

      // 3. Calculate match percentage for each job seeker
      for (var doc in jobSeekerSnapshot.docs) {
        final jobSeekerData = doc.data();
        final jobSeekerId = doc.id;
        final jobSeekerName = jobSeekerData['personalName'] as String? ?? 'Anonymous';
        final preferredJobTitle = jobSeekerData['preferredJobTitle'] as String? ?? '';

        // Extract job seeker skills
        List<String> jobSeekerSkills = [];
        
        if (jobSeekerData.containsKey('skills') && jobSeekerData['skills'] is List) {
          jobSeekerSkills = List<String>.from(jobSeekerData['skills'].map((skill) => skill.toString().toLowerCase()));
        } else if (jobSeekerData.containsKey('skills') && jobSeekerData['skills'] is String) {
          String skillsText = jobSeekerData['skills'];
          jobSeekerSkills = skillsText.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
        }

        // Calculate match percentage
        double matchPercentage = _calculateMatchPercentage(
          jobTitle: jobTitle,
          preferredJobTitle: preferredJobTitle,
          jobSkills: jobSkills,
          jobSeekerSkills: jobSeekerSkills,
        );

        // Only include matches above a certain threshold (e.g., 30%)
        if (matchPercentage >= 30) {
          matches.add(JobMatch(
            jobSeekerId: jobSeekerId,
            jobId: jobId,
            jobSeekerName: jobSeekerName,
            jobTitle: jobTitle,
            companyName: companyName,
            jobSeekerSkills: jobSeekerSkills,
            jobRequiredSkills: jobSkills,
            matchPercentage: matchPercentage,
            jobSeekerData: jobSeekerData,
            jobData: jobData,
          ));
        }
      }

      // Sort by match percentage (highest first)
      matches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      return matches;
    } catch (e) {
      print('Error getting recommended job seekers: $e');
      return [];
    }
  }

  // Get recommended jobs for a specific job seeker
  static Future<List<JobMatch>> getRecommendedJobsForJobSeeker() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      // 1. Get the job seeker details
      final jobSeekerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!jobSeekerDoc.exists) {
        return [];
      }

      final jobSeekerData = jobSeekerDoc.data()!;
      final jobSeekerName = jobSeekerData['personalName'] as String? ?? 'Anonymous';
      final preferredJobTitle = jobSeekerData['preferredJobTitle'] as String? ?? '';

      // Extract job seeker skills
      List<String> jobSeekerSkills = [];
      
      if (jobSeekerData.containsKey('skills') && jobSeekerData['skills'] is List) {
        jobSeekerSkills = List<String>.from(jobSeekerData['skills'].map((skill) => skill.toString().toLowerCase()));
      } else if (jobSeekerData.containsKey('skills') && jobSeekerData['skills'] is String) {
        String skillsText = jobSeekerData['skills'];
        jobSeekerSkills = skillsText.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      }

      // 2. Get active jobs
      final jobsSnapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'active')
          .get();

      List<JobMatch> matches = [];

      // 3. Calculate match percentage for each job
      for (var doc in jobsSnapshot.docs) {
        final jobData = doc.data();
        final jobId = doc.id;
        final jobTitle = jobData['job_title'] as String? ?? '';
        final companyName = jobData['company_name'] as String? ?? '';

        // Extract job skills
        List<String> jobSkills = [];
        
        if (jobData.containsKey('job_skills') && jobData['job_skills'] is List) {
          jobSkills = List<String>.from(jobData['job_skills'].map((skill) => skill.toString().toLowerCase()));
        } else if (jobData.containsKey('job_skills_text') && jobData['job_skills_text'] is String) {
          String skillsText = jobData['job_skills_text'];
          if (skillsText.toLowerCase() != "not specified") {
            jobSkills = skillsText.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
          }
        }

        // Calculate match percentage
        double matchPercentage = _calculateMatchPercentage(
          jobTitle: jobTitle,
          preferredJobTitle: preferredJobTitle,
          jobSkills: jobSkills,
          jobSeekerSkills: jobSeekerSkills,
        );

        // Only include matches above a certain threshold (e.g., 30%)
        if (matchPercentage >= 30) {
          matches.add(JobMatch(
            jobSeekerId: currentUser.uid,
            jobId: jobId,
            jobSeekerName: jobSeekerName,
            jobTitle: jobTitle,
            companyName: companyName,
            jobSeekerSkills: jobSeekerSkills,
            jobRequiredSkills: jobSkills,
            matchPercentage: matchPercentage,
            jobSeekerData: jobSeekerData,
            jobData: jobData,
          ));
        }
      }

      // Sort by match percentage (highest first)
      matches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      return matches;
    } catch (e) {
      print('Error getting recommended jobs: $e');
      return [];
    }
  }

  // Search for job seekers based on criteria
  static Future<List<Map<String, dynamic>>> searchJobSeekers({
    String? searchTerm, 
    List<String>? requiredSkills,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      // Get all job seekers
      final querySnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jobSeeker')
          .get();

      List<Map<String, dynamic>> filteredResults = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        bool matches = true;

        // Check if search term matches name or preferred job title
        if (searchTerm != null && searchTerm.isNotEmpty) {
          final personalName = (data['personalName'] as String? ?? '').toLowerCase();
          final preferredJobTitle = (data['preferredJobTitle'] as String? ?? '').toLowerCase();
          final searchTermLower = searchTerm.toLowerCase();

          if (!personalName.contains(searchTermLower) && !preferredJobTitle.contains(searchTermLower)) {
            matches = false;
          }
        }

        // Check if job seeker has all required skills
        if (requiredSkills != null && requiredSkills.isNotEmpty) {
          List<String> jobSeekerSkills = [];
          
          if (data.containsKey('skills') && data['skills'] is List) {
            jobSeekerSkills = List<String>.from(data['skills'].map((skill) => skill.toString().toLowerCase()));
          } else if (data.containsKey('skills') && data['skills'] is String) {
            String skillsText = data['skills'];
            jobSeekerSkills = skillsText.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
          }

          // Convert required skills to lowercase for case-insensitive comparison
          List<String> requiredSkillsLower = requiredSkills.map((s) => s.toLowerCase()).toList();

          // Check if job seeker has at least one of the required skills
          bool hasAtLeastOneSkill = false;
          for (var skill in requiredSkillsLower) {
            if (jobSeekerSkills.any((s) => s.contains(skill) || skill.contains(s))) {
              hasAtLeastOneSkill = true;
              break;
            }
          }

          if (!hasAtLeastOneSkill) {
            matches = false;
          }
        }

        // Add matching job seeker to results
        if (matches) {
          final Map<String, dynamic> result = {
            'id': doc.id,
            ...data,
          };
          filteredResults.add(result);
        }
      }

      return filteredResults;
    } catch (e) {
      print('Error searching job seekers: $e');
      return [];
    }
  }

  // Calculate match percentage between job and job seeker
  static double _calculateMatchPercentage({
    required String jobTitle,
    required String preferredJobTitle,
    required List<String> jobSkills,
    required List<String> jobSeekerSkills,
  }) {
    // 1. Title match (40% of total score)
    double titleMatchScore = 0.0;
    if (jobTitle.isNotEmpty && preferredJobTitle.isNotEmpty) {
      // Check for partial matches or similar job titles
      final jobTitleLower = jobTitle.toLowerCase();
      final preferredJobTitleLower = preferredJobTitle.toLowerCase();

      if (jobTitleLower == preferredJobTitleLower) {
        // Perfect match
        titleMatchScore = 1.0;
      } else if (jobTitleLower.contains(preferredJobTitleLower) || 
                 preferredJobTitleLower.contains(jobTitleLower)) {
        // Partial match
        titleMatchScore = 0.7;
      } else {
        // Check for related job titles (could be expanded with a more sophisticated algorithm)
        // For example: "Frontend Developer" and "Web Developer" might be related
        List<List<String>> relatedJobTitles = [
          // Software Development
          ["developer", "programmer", "coder", "engineer", "software engineer", "software developer", "application developer"],
          
          // Web Development
          ["frontend", "frontend developer", "web developer", "web designer", "ui developer", "javascript developer", "react developer", "angular developer"],
          
          // Backend Development
          ["backend", "backend developer", "api developer", "java developer", "python developer", "node developer", "php developer", "ruby developer"],
          
          // Mobile Development
          ["mobile", "mobile developer", "ios developer", "android developer", "flutter developer", "react native developer", "app developer"],
          
          // Data Science & Analysis
          ["data scientist", "data analyst", "data engineer", "machine learning", "ml engineer", "ai engineer", "business intelligence", "bi developer"],
          
          // Database
          ["database", "database administrator", "dba", "sql developer", "database engineer", "data architect"],
          
          // DevOps & Infrastructure
          ["devops", "sre", "site reliability", "infrastructure", "cloud engineer", "system administrator", "sysadmin", "network administrator", "ops engineer"],
          
          // Cloud Computing
          ["cloud", "cloud architect", "aws", "azure", "gcp", "cloud engineer", "solutions architect"],
          
          // Security
          ["security", "cybersecurity", "security analyst", "security engineer", "penetration tester", "ethical hacker", "information security"],
          
          // QA & Testing
          ["qa", "quality", "tester", "test engineer", "qa engineer", "quality assurance", "automation tester", "manual tester"],
          
          // Design
          ["designer", "ui designer", "ux designer", "ui/ux", "visual designer", "graphic designer", "product designer", "web designer"],
          
          // Management & Leadership
          ["manager", "lead", "supervisor", "coordinator", "director", "vp", "head", "chief", "cto", "cio"],
          
          // Project Management
          ["project manager", "product manager", "program manager", "scrum master", "agile coach", "delivery manager"],
          
          // Support & Customer Service
          ["support", "help desk", "customer service", "technical support", "desktop support", "it support"],
        ];

        for (var relatedGroup in relatedJobTitles) {
          bool jobTitleInGroup = relatedGroup.any((term) => jobTitleLower.contains(term));
          bool preferredTitleInGroup = relatedGroup.any((term) => preferredJobTitleLower.contains(term));
          
          if (jobTitleInGroup && preferredTitleInGroup) {
            titleMatchScore = 0.5;
            break;
          }
        }
      }
    }

    // 2. Skills match (60% of total score)
    double skillsMatchScore = 0.0;
    if (jobSkills.isNotEmpty && jobSeekerSkills.isNotEmpty) {
      int skillMatches = 0;
      
      // Count how many job skills match with job seeker skills
      for (var jobSkill in jobSkills) {
        for (var seekerSkill in jobSeekerSkills) {
          if (jobSkill.contains(seekerSkill) || seekerSkill.contains(jobSkill)) {
            skillMatches++;
            break;
          }
        }
      }
      
      // Calculate skills match score
      skillsMatchScore = jobSkills.isEmpty ? 0 : skillMatches / jobSkills.length;
    }

    // 3. Calculate total match percentage
    double totalMatchScore = (titleMatchScore * 0.4) + (skillsMatchScore * 0.6);
    
    // Convert to percentage
    return totalMatchScore * 100;
  }
}