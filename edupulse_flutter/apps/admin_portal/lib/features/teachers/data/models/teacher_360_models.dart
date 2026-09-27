import 'teachers_models.dart';

/// Models representing Teacher 360 operational analytics directly from backend.
/// Strictly typed to avoid fallback or fabricated data.

class Teacher360Overview {
  final int totalClasses;
  final int totalSections;
  final int weeklyPeriods;
  final List<String> primarySubjects;
  final List<String> classTeacherOf;
  final double syllabusCompletionRate;
  final double expectedSyllabusRate;
  final double syllabusPaceVariance;
  final String syllabusPaceStatus;
  final double marksSubmissionRate;
  final double? attendanceRate;
  final int activeStudentsTaught;

  const Teacher360Overview({
    required this.totalClasses,
    required this.totalSections,
    required this.weeklyPeriods,
    required this.primarySubjects,
    required this.classTeacherOf,
    required this.syllabusCompletionRate,
    required this.expectedSyllabusRate,
    required this.syllabusPaceVariance,
    required this.syllabusPaceStatus,
    required this.marksSubmissionRate,
    this.attendanceRate,
    required this.activeStudentsTaught,
  });

  factory Teacher360Overview.fromJson(Map<String, dynamic> json) {
    return Teacher360Overview(
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      totalSections: (json['total_sections'] as num?)?.toInt() ?? 0,
      weeklyPeriods: (json['weekly_periods'] as num?)?.toInt() ?? 0,
      primarySubjects: (json['primary_subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      classTeacherOf: (json['class_teacher_of'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      syllabusCompletionRate:
          (json['syllabus_completion_rate'] as num?)?.toDouble() ?? 0.0,
      expectedSyllabusRate:
          (json['expected_syllabus_rate'] as num?)?.toDouble() ?? 0.0,
      syllabusPaceVariance:
          (json['syllabus_pace_variance'] as num?)?.toDouble() ?? 0.0,
      syllabusPaceStatus: json['syllabus_pace_status']?.toString() ?? 'ON_TRACK',
      marksSubmissionRate:
          (json['marks_submission_rate'] as num?)?.toDouble() ?? 0.0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble(),
      activeStudentsTaught:
          (json['active_students_taught'] as num?)?.toInt() ?? 0,
    );
  }
}

class TeacherClassAssignmentItem {
  final String assignmentId;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String assignmentType;
  final int weeklyPeriods;
  final double workloadPercentage;
  final int studentCount;
  final bool isClassTeacher;
  final String? roomNumber;
  final int? priority;

  const TeacherClassAssignmentItem({
    required this.assignmentId,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.assignmentType,
    required this.weeklyPeriods,
    required this.workloadPercentage,
    required this.studentCount,
    required this.isClassTeacher,
    this.roomNumber,
    this.priority,
  });

  factory TeacherClassAssignmentItem.fromJson(Map<String, dynamic> json) {
    return TeacherClassAssignmentItem(
      assignmentId: json['assignment_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString(),
      assignmentType: json['assignment_type']?.toString() ?? 'PRIMARY',
      weeklyPeriods: (json['weekly_periods'] as num?)?.toInt() ?? 0,
      workloadPercentage:
          (json['workload_percentage'] as num?)?.toDouble() ?? 0.0,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      isClassTeacher: json['is_class_teacher'] == true,
      roomNumber: json['room_number']?.toString(),
      priority: (json['priority'] as num?)?.toInt(),
    );
  }
}

class TeacherSyllabusTopic {
  final String id;
  final String syllabusCode;
  final String unitName;
  final String chapterName;
  final String topicName;
  final int sequenceOrder;
  final int estimatedPeriods;
  final String coverageStatus;
  final String? completedAt;
  final bool isExpectedByNow;

  const TeacherSyllabusTopic({
    required this.id,
    required this.syllabusCode,
    required this.unitName,
    required this.chapterName,
    required this.topicName,
    required this.sequenceOrder,
    required this.estimatedPeriods,
    required this.coverageStatus,
    this.completedAt,
    required this.isExpectedByNow,
  });

  factory TeacherSyllabusTopic.fromJson(Map<String, dynamic> json) {
    return TeacherSyllabusTopic(
      id: json['id']?.toString() ?? '',
      syllabusCode: json['syllabus_code']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      chapterName: json['chapter_name']?.toString() ?? '',
      topicName: json['topic_name']?.toString() ?? '',
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 0,
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 0,
      coverageStatus: json['coverage_status']?.toString() ?? 'PENDING',
      completedAt: json['completed_at']?.toString(),
      isExpectedByNow: json['is_expected_by_now'] == true,
    );
  }
}

class TeacherSyllabusSubjectProgress {
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final int totalTopics;
  final int completedTopics;
  final int expectedTopicsByNow;
  final double actualCompletionPercentage;
  final double expectedCompletionPercentage;
  final double paceVariance;
  final String paceStatus;
  final List<TeacherSyllabusTopic> topics;

  const TeacherSyllabusSubjectProgress({
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    required this.totalTopics,
    required this.completedTopics,
    required this.expectedTopicsByNow,
    required this.actualCompletionPercentage,
    required this.expectedCompletionPercentage,
    required this.paceVariance,
    required this.paceStatus,
    required this.topics,
  });

  factory TeacherSyllabusSubjectProgress.fromJson(Map<String, dynamic> json) {
    return TeacherSyllabusSubjectProgress(
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      completedTopics: (json['completed_topics'] as num?)?.toInt() ?? 0,
      expectedTopicsByNow:
          (json['expected_topics_by_now'] as num?)?.toInt() ?? 0,
      actualCompletionPercentage:
          (json['actual_completion_percentage'] as num?)?.toDouble() ?? 0.0,
      expectedCompletionPercentage:
          (json['expected_completion_percentage'] as num?)?.toDouble() ?? 0.0,
      paceVariance: (json['pace_variance'] as num?)?.toDouble() ?? 0.0,
      paceStatus: json['pace_status']?.toString() ?? 'ON_TRACK',
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) =>
                  TeacherSyllabusTopic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TeacherTimetableSlot {
  final String id;
  final String dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String periodType;
  final String? subjectName;
  final String? className;
  final String? sectionName;
  final String? roomNumber;
  final bool isActive;

  const TeacherTimetableSlot({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.periodType,
    this.subjectName,
    this.className,
    this.sectionName,
    this.roomNumber,
    required this.isActive,
  });

  factory TeacherTimetableSlot.fromJson(Map<String, dynamic> json) {
    return TeacherTimetableSlot(
      id: json['id']?.toString() ?? '',
      dayOfWeek: json['day_of_week']?.toString() ?? '',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 0,
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      periodType: json['period_type']?.toString() ?? 'REGULAR',
      subjectName: json['subject_name']?.toString(),
      className: json['class_name']?.toString(),
      sectionName: json['section_name']?.toString(),
      roomNumber: json['room_number']?.toString(),
      isActive: json['is_active'] != false,
    );
  }
}

class TeacherAttendanceSummary {
  final bool hasData;
  final double? attendanceRate;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int totalRecordedDays;
  final List<Map<String, dynamic>> monthlyTrend;
  final List<Map<String, dynamic>> recentLogs;

  const TeacherAttendanceSummary({
    required this.hasData,
    this.attendanceRate,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.totalRecordedDays,
    required this.monthlyTrend,
    required this.recentLogs,
  });

  factory TeacherAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSummary(
      hasData: json['has_data'] == true,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble(),
      presentDays: (json['present_days'] as num?)?.toInt() ?? 0,
      absentDays: (json['absent_days'] as num?)?.toInt() ?? 0,
      leaveDays: (json['leave_days'] as num?)?.toInt() ?? 0,
      totalRecordedDays: (json['total_recorded_days'] as num?)?.toInt() ?? 0,
      monthlyTrend: (json['monthly_trend'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      recentLogs: (json['recent_logs'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class TeacherHomeworkItem {
  final String id;
  final String title;
  final String className;
  final String sectionName;
  final String subjectName;
  final String assignedDate;
  final String dueDate;
  final int submissionCount;
  final int totalStudents;
  final String status;

  const TeacherHomeworkItem({
    required this.id,
    required this.title,
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.assignedDate,
    required this.dueDate,
    required this.submissionCount,
    required this.totalStudents,
    required this.status,
  });

  factory TeacherHomeworkItem.fromJson(Map<String, dynamic> json) {
    return TeacherHomeworkItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      assignedDate: json['assigned_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class TeacherExamComplianceItem {
  final String examId;
  final String examName;
  final String examType;
  final String examDate;
  final String className;
  final String sectionName;
  final String subjectName;
  final int totalStudents;
  final int marksEnteredCount;
  final int marksPendingCount;
  final double compliancePercentage;
  final String status;

  const TeacherExamComplianceItem({
    required this.examId,
    required this.examName,
    required this.examType,
    required this.examDate,
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.totalStudents,
    required this.marksEnteredCount,
    required this.marksPendingCount,
    required this.compliancePercentage,
    required this.status,
  });

  factory TeacherExamComplianceItem.fromJson(Map<String, dynamic> json) {
    return TeacherExamComplianceItem(
      examId: json['exam_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? '',
      examType: json['exam_type']?.toString() ?? '',
      examDate: json['exam_date']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      marksEnteredCount: (json['marks_entered_count'] as num?)?.toInt() ?? 0,
      marksPendingCount: (json['marks_pending_count'] as num?)?.toInt() ?? 0,
      compliancePercentage:
          (json['compliance_percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
    );
  }
}

class SubjectWorkloadItem {
  final String subjectName;
  final int weeklyPeriods;
  final double percentage;

  const SubjectWorkloadItem({
    required this.subjectName,
    required this.weeklyPeriods,
    required this.percentage,
  });

  factory SubjectWorkloadItem.fromJson(Map<String, dynamic> json) {
    return SubjectWorkloadItem(
      subjectName: json['subject_name']?.toString() ?? '',
      weeklyPeriods: (json['weekly_periods'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ClassWorkloadItem {
  final String className;
  final int weeklyPeriods;
  final double percentage;

  const ClassWorkloadItem({
    required this.className,
    required this.weeklyPeriods,
    required this.percentage,
  });

  factory ClassWorkloadItem.fromJson(Map<String, dynamic> json) {
    return ClassWorkloadItem(
      className: json['class_name']?.toString() ?? '',
      weeklyPeriods: (json['weekly_periods'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TeacherWorkloadSummary {
  final int weeklyPeriodCapacity;
  final int assignedWeeklyPeriods;
  final double utilizationRate;
  final List<SubjectWorkloadItem> subjectDistribution;
  final List<ClassWorkloadItem> classDistribution;

  const TeacherWorkloadSummary({
    required this.weeklyPeriodCapacity,
    required this.assignedWeeklyPeriods,
    required this.utilizationRate,
    required this.subjectDistribution,
    required this.classDistribution,
  });

  factory TeacherWorkloadSummary.fromJson(Map<String, dynamic> json) {
    return TeacherWorkloadSummary(
      weeklyPeriodCapacity:
          (json['weekly_period_capacity'] as num?)?.toInt() ?? 30,
      assignedWeeklyPeriods:
          (json['assigned_weekly_periods'] as num?)?.toInt() ?? 0,
      utilizationRate: (json['utilization_rate'] as num?)?.toDouble() ?? 0.0,
      subjectDistribution: (json['subject_distribution'] as List<dynamic>?)
              ?.map((e) =>
                  SubjectWorkloadItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      classDistribution: (json['class_distribution'] as List<dynamic>?)
              ?.map(
                  (e) => ClassWorkloadItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Teacher360Response {
  final TeacherDto teacher;
  final Teacher360Overview overview;
  final List<TeacherClassAssignmentItem> assignments;
  final List<TeacherSyllabusSubjectProgress> syllabusProgress;
  final List<TeacherTimetableSlot> timetable;
  final TeacherAttendanceSummary attendance;
  final List<TeacherHomeworkItem> homework;
  final List<TeacherExamComplianceItem> examCompliance;
  final TeacherWorkloadSummary workload;

  const Teacher360Response({
    required this.teacher,
    required this.overview,
    required this.assignments,
    required this.syllabusProgress,
    required this.timetable,
    required this.attendance,
    required this.homework,
    required this.examCompliance,
    required this.workload,
  });

  factory Teacher360Response.fromJson(Map<String, dynamic> json) {
    return Teacher360Response(
      teacher: TeacherDto.fromJson(json['teacher'] as Map<String, dynamic>),
      overview: Teacher360Overview.fromJson(
          json['overview'] as Map<String, dynamic>),
      assignments: (json['assignments'] as List<dynamic>?)
              ?.map((e) => TeacherClassAssignmentItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      syllabusProgress: (json['syllabus_progress'] as List<dynamic>?)
              ?.map((e) => TeacherSyllabusSubjectProgress.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      timetable: (json['timetable'] as List<dynamic>?)
              ?.map((e) =>
                  TeacherTimetableSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      attendance: TeacherAttendanceSummary.fromJson(
          json['attendance'] as Map<String, dynamic>),
      homework: (json['homework'] as List<dynamic>?)
              ?.map((e) =>
                  TeacherHomeworkItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      examCompliance: (json['exam_compliance'] as List<dynamic>?)
              ?.map((e) => TeacherExamComplianceItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      workload: TeacherWorkloadSummary.fromJson(
          json['workload'] as Map<String, dynamic>),
    );
  }
}
