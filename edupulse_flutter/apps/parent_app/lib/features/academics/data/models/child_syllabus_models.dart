class ChildTopicProgress {
  final String topicId;
  final String chapterName;
  final String topicName;
  final String status; // COMPLETED, IN_PROGRESS, UPCOMING
  final DateTime? completedAt;
  final int orderIndex;

  const ChildTopicProgress({
    required this.topicId,
    required this.chapterName,
    required this.topicName,
    required this.status,
    this.completedAt,
    required this.orderIndex,
  });

  factory ChildTopicProgress.fromJson(Map<String, dynamic> json) {
    return ChildTopicProgress(
      topicId: json['topic_id'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? 'General',
      topicName: json['topic_name'] as String? ?? 'Topic',
      status: (json['status'] as String? ?? 'UPCOMING').toUpperCase(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isUpcoming => status == 'UPCOMING';
}

class ChildSubjectProgress {
  final String subjectId;
  final String subjectName;
  final String? teacherName;
  final int totalTopics;
  final int completedTopics;
  final int inProgressTopics;
  final double completionPercentage;
  final DateTime? targetCompletionDate;
  final DateTime? forecastCompletionDate;
  final String statusBadge; // "On schedule", "Slightly behind", "Recovery plan active"
  final List<ChildTopicProgress> topics;

  const ChildSubjectProgress({
    required this.subjectId,
    required this.subjectName,
    this.teacherName,
    required this.totalTopics,
    required this.completedTopics,
    required this.inProgressTopics,
    required this.completionPercentage,
    this.targetCompletionDate,
    this.forecastCompletionDate,
    required this.statusBadge,
    required this.topics,
  });

  factory ChildSubjectProgress.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'] as List<dynamic>? ?? [];
    return ChildSubjectProgress(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      teacherName: json['teacher_name'] as String?,
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      completedTopics: (json['completed_topics'] as num?)?.toInt() ?? 0,
      inProgressTopics: (json['in_progress_topics'] as num?)?.toInt() ?? 0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      targetCompletionDate: json['target_completion_date'] != null
          ? DateTime.tryParse(json['target_completion_date'] as String)
          : null,
      forecastCompletionDate: json['forecast_completion_date'] != null
          ? DateTime.tryParse(json['forecast_completion_date'] as String)
          : null,
      statusBadge: json['status_badge'] as String? ?? 'On schedule',
      topics: rawTopics.map((t) => ChildTopicProgress.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

class ChildSyllabusProgressResponse {
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final double overallCompletionPercentage;
  final List<ChildSubjectProgress> subjects;

  const ChildSyllabusProgressResponse({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.overallCompletionPercentage,
    required this.subjects,
  });

  factory ChildSyllabusProgressResponse.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['subjects'] as List<dynamic>? ?? [];
    return ChildSyllabusProgressResponse(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? 'Student',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      overallCompletionPercentage: (json['overall_completion_percentage'] as num?)?.toDouble() ?? 0.0,
      subjects: rawSubjects.map((s) => ChildSubjectProgress.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
