import 'package:flutter/material.dart';

class TeacherSyllabusItem {
  final String id;
  final String? syllabusCode;
  final String unitName;
  final String chapterName;
  final String topicName;
  final String? description;
  final int sequenceOrder;
  final int estimatedPeriods;
  final String coverageStatus;
  final String lifecycleStatus;
  final String? classId;
  final String? subjectId;

  const TeacherSyllabusItem({
    required this.id,
    this.syllabusCode,
    required this.unitName,
    required this.chapterName,
    required this.topicName,
    this.description,
    required this.sequenceOrder,
    required this.estimatedPeriods,
    required this.coverageStatus,
    required this.lifecycleStatus,
    this.classId,
    this.subjectId,
  });

  factory TeacherSyllabusItem.fromJson(Map<String, dynamic> json) {
    return TeacherSyllabusItem(
      id: json['id'] as String,
      syllabusCode: json['syllabus_code'] as String?,
      unitName: (json['unit_name'] as String?) ?? 'General Unit',
      chapterName: (json['chapter_name'] as String?) ?? 'General Chapter',
      topicName: (json['topic_name'] as String?) ?? 'Topic',
      description: json['description'] as String?,
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 1,
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 4,
      coverageStatus: (json['coverage_status'] as String?) ?? 'PENDING',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'PLANNED',
      classId: json['class_id'] as String?,
      subjectId: json['subject_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syllabus_code': syllabusCode,
      'unit_name': unitName,
      'chapter_name': chapterName,
      'topic_name': topicName,
      'description': description,
      'sequence_order': sequenceOrder,
      'estimated_periods': estimatedPeriods,
      'coverage_status': coverageStatus,
      'lifecycle_status': lifecycleStatus,
      'class_id': classId,
      'subject_id': subjectId,
    };
  }
}

class TeacherCoverageProgressItem {
  final String id;
  final String syllabusId;
  final String sectionId;
  final String? teacherId;
  final String status;
  final double completionPercentage;
  final String? startedAt;
  final String? completedAt;
  final String? remarks;

  const TeacherCoverageProgressItem({
    required this.id,
    required this.syllabusId,
    required this.sectionId,
    this.teacherId,
    required this.status,
    required this.completionPercentage,
    this.startedAt,
    this.completedAt,
    this.remarks,
  });

  factory TeacherCoverageProgressItem.fromJson(Map<String, dynamic> json) {
    return TeacherCoverageProgressItem(
      id: json['id'] as String,
      syllabusId: json['syllabus_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      status: (json['status'] as String?) ?? 'NOT_STARTED',
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syllabus_id': syllabusId,
      'section_id': sectionId,
      'teacher_id': teacherId,
      'status': status,
      'completion_percentage': completionPercentage,
      'started_at': startedAt,
      'completed_at': completedAt,
      'remarks': remarks,
    };
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
        return const Color(0xFF0F766E);
      case 'REOPENED':
        return const Color(0xFFF59E0B);
      case 'SKIPPED':
      case 'DEFERRED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String get displayLabel {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'REOPENED':
        return 'Reopened';
      case 'SKIPPED':
        return 'Skipped';
      case 'DEFERRED':
        return 'Deferred';
      default:
        return 'Not Started';
    }
  }
}

class TeacherSyllabusPrediction {
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String? sectionId;
  final String? sectionName;
  final String? teacherId;
  final String? teacherName;
  final int totalChapters;
  final int completedChapters;
  final int inProgressChapters;
  final int remainingChapters;
  final int totalTopics;
  final int completedTopics;
  final double completionPercentage;
  final double plannedPace;
  final double actualPace;
  final String? projectedCompletionDate;
  final bool isEstimate;
  final String? targetExamName;
  final String? targetExamDate;
  final int? daysGapToExam;
  final String riskStatus;
  final String dataSufficiency;
  final String message;
  final String? recommendedAction;

  const TeacherSyllabusPrediction({
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    this.sectionId,
    this.sectionName,
    this.teacherId,
    this.teacherName,
    required this.totalChapters,
    required this.completedChapters,
    required this.inProgressChapters,
    required this.remainingChapters,
    required this.totalTopics,
    required this.completedTopics,
    required this.completionPercentage,
    required this.plannedPace,
    required this.actualPace,
    this.projectedCompletionDate,
    this.isEstimate = true,
    this.targetExamName,
    this.targetExamDate,
    this.daysGapToExam,
    required this.riskStatus,
    required this.dataSufficiency,
    required this.message,
    this.recommendedAction,
  });

  factory TeacherSyllabusPrediction.fromJson(Map<String, dynamic> json) {
    return TeacherSyllabusPrediction(
      subjectId: json['subject_id'] as String,
      subjectName: (json['subject_name'] as String?) ?? 'Subject',
      classId: json['class_id'] as String,
      className: (json['class_name'] as String?) ?? 'Class',
      sectionId: json['section_id'] as String?,
      sectionName: json['section_name'] as String?,
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      completedChapters: (json['completed_chapters'] as num?)?.toInt() ?? 0,
      inProgressChapters: (json['in_progress_chapters'] as num?)?.toInt() ?? 0,
      remainingChapters: (json['remaining_chapters'] as num?)?.toInt() ?? 0,
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      completedTopics: (json['completed_topics'] as num?)?.toInt() ?? 0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      plannedPace: (json['planned_pace'] as num?)?.toDouble() ?? 0.0,
      actualPace: (json['actual_pace'] as num?)?.toDouble() ?? 0.0,
      projectedCompletionDate: json['projected_completion_date'] as String?,
      isEstimate: (json['is_estimate'] as bool?) ?? true,
      targetExamName: json['target_exam_name'] as String?,
      targetExamDate: json['target_exam_date'] as String?,
      daysGapToExam: (json['days_gap_to_exam'] as num?)?.toInt(),
      riskStatus: (json['risk_status'] as String?) ?? 'ON_TRACK',
      dataSufficiency: (json['data_sufficiency'] as String?) ?? 'SUFFICIENT',
      message: (json['message'] as String?) ?? '',
      recommendedAction: json['recommended_action'] as String?,
    );
  }

  Color get riskColor {
    switch (riskStatus.toUpperCase()) {
      case 'ON_TRACK':
        return const Color(0xFF10B981);
      case 'AT_RISK':
        return const Color(0xFFF59E0B);
      case 'LIKELY_TO_MISS_TARGET':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String get riskLabel {
    switch (riskStatus.toUpperCase()) {
      case 'ON_TRACK':
        return 'On Track';
      case 'AT_RISK':
        return 'Pacing Alert: At Risk';
      case 'LIKELY_TO_MISS_TARGET':
        return 'Pacing Alert: Miss Risk';
      default:
        return riskStatus;
    }
  }

  Color get sufficiencyColor {
    switch (dataSufficiency.toUpperCase()) {
      case 'SUFFICIENT':
        return const Color(0xFF10B981);
      case 'WAITING_FOR_PROGRESS':
        return const Color(0xFF3B82F6);
      case 'INSUFFICIENT_DATA':
        return const Color(0xFF64748B);
      case 'NO_SYLLABUS':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String get sufficiencyLabel {
    switch (dataSufficiency.toUpperCase()) {
      case 'SUFFICIENT':
        return 'Verified Data';
      case 'WAITING_FOR_PROGRESS':
        return 'Awaiting Teaching Progress';
      case 'INSUFFICIENT_DATA':
        return 'Accumulating Progress Data';
      case 'NO_SYLLABUS':
        return 'No Syllabus Configured';
      default:
        return dataSufficiency;
    }
  }
}
