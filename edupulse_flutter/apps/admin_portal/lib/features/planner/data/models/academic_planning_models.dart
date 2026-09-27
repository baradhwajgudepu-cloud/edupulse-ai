import 'package:flutter/material.dart';

class SyllabusItem {
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
  final String? sectionId;
  final String? subjectId;

  const SyllabusItem({
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
    this.sectionId,
    this.subjectId,
  });

  factory SyllabusItem.fromJson(Map<String, dynamic> json) {
    return SyllabusItem(
      id: json['id'] as String,
      syllabusCode: json['syllabus_code'] as String?,
      unitName: (json['unit_name'] as String?) ?? 'Unit 1',
      chapterName: (json['chapter_name'] as String?) ?? 'Chapter 1',
      topicName: (json['topic_name'] as String?) ?? 'Topic',
      description: json['description'] as String?,
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 1,
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 2,
      coverageStatus: (json['coverage_status'] as String?) ?? 'PENDING',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'PLANNED',
      classId: json['class_id'] as String?,
      sectionId: json['section_id'] as String?,
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
      'section_id': sectionId,
      'subject_id': subjectId,
    };
  }

  Color get statusColor {
    switch (coverageStatus.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
      case 'ONGOING':
        return const Color(0xFF0F766E);
      case 'REOPENED':
        return const Color(0xFFF59E0B);
      case 'DEFERRED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Color get lifecycleColor {
    switch (lifecycleStatus.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
        return const Color(0xFF0F766E);
      case 'REOPENED':
        return const Color(0xFFF59E0B);
      case 'DEFERRED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

class CurriculumPopulateResult {
  final bool success;
  final String board;
  final int clonedCount;
  final bool available;
  final String message;
  final Map<String, dynamic> details;

  const CurriculumPopulateResult({
    required this.success,
    required this.board,
    required this.clonedCount,
    required this.available,
    required this.message,
    required this.details,
  });

  factory CurriculumPopulateResult.fromJson(Map<String, dynamic> json) {
    return CurriculumPopulateResult(
      success: json['success'] as bool? ?? false,
      board: json['board'] as String? ?? '',
      clonedCount: (json['cloned_count'] as num?)?.toInt() ?? 0,
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      details: (json['details'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class SyllabusPredictionItem {
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
  final String riskStatus;
  final String dataSufficiency;
  final String message;
  final String? targetExamName;
  final String? targetExamDate;
  final int? daysUntilExam;
  final int? bufferDays;

  const SyllabusPredictionItem({
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
    required this.riskStatus,
    required this.dataSufficiency,
    required this.message,
    this.targetExamName,
    this.targetExamDate,
    this.daysUntilExam,
    this.bufferDays,
  });

  factory SyllabusPredictionItem.fromJson(Map<String, dynamic> json) {
    return SyllabusPredictionItem(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? 'Class',
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
      riskStatus: json['risk_status'] as String? ?? 'ON_TRACK',
      dataSufficiency: json['data_sufficiency'] as String? ?? 'WAITING_FOR_PROGRESS',
      message: json['message'] as String? ?? '',
      targetExamName: json['target_exam_name'] as String?,
      targetExamDate: json['target_exam_date'] as String?,
      daysUntilExam: (json['days_until_exam'] as num?)?.toInt(),
      bufferDays: (json['buffer_days'] as num?)?.toInt(),
    );
  }

  Color get riskBadgeColor {
    switch (riskStatus.toUpperCase()) {
      case 'ON_TRACK':
        return const Color(0xFF10B981);
      case 'AT_RISK':
        return const Color(0xFFF59E0B);
      case 'LIKELY_TO_MISS_TARGET':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String get riskLabel {
    switch (riskStatus.toUpperCase()) {
      case 'ON_TRACK':
        return 'On Track';
      case 'AT_RISK':
        return 'At Risk';
      case 'LIKELY_TO_MISS_TARGET':
        return 'Likely to Miss Exam';
      default:
        return riskStatus;
    }
  }

  String get dataSufficiencyLabel {
    switch (dataSufficiency.toUpperCase()) {
      case 'NO_SYLLABUS':
        return 'No Syllabus Configured';
      case 'WAITING_FOR_PROGRESS':
        return 'Waiting for Teaching Progress';
      case 'INSUFFICIENT_DATA':
        return 'Insufficient Progress Data';
      case 'SUFFICIENT':
        return 'Sufficient Data';
      default:
        return dataSufficiency;
    }
  }
}

class AdaptiveRecommendationItem {
  final String id;
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String? sectionId;
  final String? sectionName;
  final String riskStatus;
  final int currentWeeklyPeriods;
  final int recommendedWeeklyPeriods;
  final int periodsDifference;
  final int durationWeeks;
  final String rationale;
  final String impactExplanation;
  final bool isOptional;

  const AdaptiveRecommendationItem({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    this.sectionId,
    this.sectionName,
    required this.riskStatus,
    required this.currentWeeklyPeriods,
    required this.recommendedWeeklyPeriods,
    required this.periodsDifference,
    required this.durationWeeks,
    required this.rationale,
    required this.impactExplanation,
    required this.isOptional,
  });

  factory AdaptiveRecommendationItem.fromJson(Map<String, dynamic> json) {
    return AdaptiveRecommendationItem(
      id: json['id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? 'Class',
      sectionId: json['section_id'] as String?,
      sectionName: json['section_name'] as String?,
      riskStatus: json['risk_status'] as String? ?? 'AT_RISK',
      currentWeeklyPeriods: (json['current_weekly_periods'] as num?)?.toInt() ?? 5,
      recommendedWeeklyPeriods: (json['recommended_weekly_periods'] as num?)?.toInt() ?? 6,
      periodsDifference: (json['periods_difference'] as num?)?.toInt() ?? 1,
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 4,
      rationale: json['rationale'] as String? ?? '',
      impactExplanation: json['impact_explanation'] as String? ?? '',
      isOptional: json['is_optional'] as bool? ?? true,
    );
  }
}

class AcademicPlanningSummary {
  final String schoolId;
  final String academicYearId;
  final double schoolWideCompletionPct;
  final int totalSubjectsTracked;
  final int onTrackCount;
  final int atRiskCount;
  final int likelyToMissCount;
  final int insufficientDataCount;
  final int upcomingExamsCount;
  final int pendingTimetableSuggestionsCount;
  final List<Map<String, dynamic>> classSummaries;
  final List<SyllabusPredictionItem> atRiskSubjects;
  final List<AdaptiveRecommendationItem> adaptiveRecommendations;

  const AcademicPlanningSummary({
    required this.schoolId,
    required this.academicYearId,
    required this.schoolWideCompletionPct,
    required this.totalSubjectsTracked,
    required this.onTrackCount,
    required this.atRiskCount,
    required this.likelyToMissCount,
    required this.insufficientDataCount,
    required this.upcomingExamsCount,
    required this.pendingTimetableSuggestionsCount,
    required this.classSummaries,
    required this.atRiskSubjects,
    required this.adaptiveRecommendations,
  });

  factory AcademicPlanningSummary.fromJson(Map<String, dynamic> json) {
    final atRiskList = (json['at_risk_subjects'] as List<dynamic>?) ?? [];
    final adaptList = (json['adaptive_recommendations'] as List<dynamic>?) ?? [];
    final clsList = (json['class_summaries'] as List<dynamic>?) ?? [];

    return AcademicPlanningSummary(
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      schoolWideCompletionPct: (json['school_wide_completion_pct'] as num?)?.toDouble() ?? 0.0,
      totalSubjectsTracked: (json['total_subjects_tracked'] as num?)?.toInt() ?? 0,
      onTrackCount: (json['on_track_count'] as num?)?.toInt() ?? 0,
      atRiskCount: (json['at_risk_count'] as num?)?.toInt() ?? 0,
      likelyToMissCount: (json['likely_to_miss_count'] as num?)?.toInt() ?? 0,
      insufficientDataCount: (json['insufficient_data_count'] as num?)?.toInt() ?? 0,
      upcomingExamsCount: (json['upcoming_exams_count'] as num?)?.toInt() ?? 0,
      pendingTimetableSuggestionsCount: (json['pending_timetable_suggestions_count'] as num?)?.toInt() ?? 0,
      classSummaries: clsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      atRiskSubjects: atRiskList.map((e) => SyllabusPredictionItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      adaptiveRecommendations: adaptList.map((e) => AdaptiveRecommendationItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class TimetableAISlotItem {
  final String dayOfWeek;
  final int periodNumber;
  final String periodType;
  final String startTime;
  final String endTime;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final String? roomNumber;
  final bool isBreak;

  const TimetableAISlotItem({
    required this.dayOfWeek,
    required this.periodNumber,
    required this.periodType,
    required this.startTime,
    required this.endTime,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    this.roomNumber,
    this.isBreak = false,
  });

  factory TimetableAISlotItem.fromJson(Map<String, dynamic> json) {
    return TimetableAISlotItem(
      dayOfWeek: json['day_of_week'] as String? ?? 'MONDAY',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      periodType: json['period_type'] as String? ?? 'ACADEMIC',
      startTime: json['start_time'] as String? ?? '08:30',
      endTime: json['end_time'] as String? ?? '09:15',
      subjectId: json['subject_id'] as String?,
      subjectName: json['subject_name'] as String?,
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      roomNumber: json['room_number'] as String?,
      isBreak: json['is_break'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'period_number': periodNumber,
      'period_type': periodType,
      'start_time': startTime,
      'end_time': endTime,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'room_number': roomNumber,
      'is_break': isBreak,
    };
  }
}

class TimetableAIRecommendation {
  final String recommendationId;
  final String classId;
  final String sectionId;
  final int totalAllocatedPeriods;
  final double weeklyWorkloadHours;
  final List<TimetableAISlotItem> suggestedSlots;
  final List<String> rationale;
  final List<String> riskFactors;
  final Map<String, dynamic> auditTrail;
  final String status;

  const TimetableAIRecommendation({
    required this.recommendationId,
    required this.classId,
    required this.sectionId,
    required this.totalAllocatedPeriods,
    required this.weeklyWorkloadHours,
    required this.suggestedSlots,
    required this.rationale,
    required this.riskFactors,
    required this.auditTrail,
    required this.status,
  });

  factory TimetableAIRecommendation.fromJson(Map<String, dynamic> json) {
    final slotsRaw = (json['suggested_slots'] as List<dynamic>?) ?? [];
    final ratRaw = (json['rationale'] as List<dynamic>?) ?? [];
    final riskRaw = (json['risk_factors'] as List<dynamic>?) ?? [];

    return TimetableAIRecommendation(
      recommendationId: json['recommendation_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      totalAllocatedPeriods: (json['total_allocated_periods'] as num?)?.toInt() ?? 0,
      weeklyWorkloadHours: (json['weekly_workload_hours'] as num?)?.toDouble() ?? 0.0,
      suggestedSlots: slotsRaw.map((e) => TimetableAISlotItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      rationale: ratRaw.map((e) => e.toString()).toList(),
      riskFactors: riskRaw.map((e) => e.toString()).toList(),
      auditTrail: (json['audit_trail'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'SUGGESTED',
    );
  }
}

class TimetableGridValidation {
  final bool isValid;
  final List<String> conflicts;
  final List<String> warnings;
  final int totalSlotsChecked;

  const TimetableGridValidation({
    required this.isValid,
    required this.conflicts,
    required this.warnings,
    required this.totalSlotsChecked,
  });

  factory TimetableGridValidation.fromJson(Map<String, dynamic> json) {
    final conf = (json['conflicts'] as List<dynamic>?) ?? [];
    final warn = (json['warnings'] as List<dynamic>?) ?? [];

    return TimetableGridValidation(
      isValid: json['is_valid'] as bool? ?? true,
      conflicts: conf.map((e) => e.toString()).toList(),
      warnings: warn.map((e) => e.toString()).toList(),
      totalSlotsChecked: (json['total_slots_checked'] as num?)?.toInt() ?? 0,
    );
  }
}

class CandidateEvaluationModel {
  final String teacherId;
  final String teacherName;
  final String? qualification;
  final String? specialization;
  final String eligibilityStatus;
  final bool hasAvailableCapacity;
  final int maxWeeklyCapacity;
  final int currentWeeklyPeriods;
  final int availableCapacity;
  final double currentSyllabusCompletionPct;
  final String classCompatibility;
  final String? sourceClassName;
  final String? sourceSectionName;
  final List<String> notes;
  final List<Map<String, dynamic>> compatibleSlots;

  const CandidateEvaluationModel({
    required this.teacherId,
    required this.teacherName,
    this.qualification,
    this.specialization,
    required this.eligibilityStatus,
    required this.hasAvailableCapacity,
    required this.maxWeeklyCapacity,
    required this.currentWeeklyPeriods,
    required this.availableCapacity,
    required this.currentSyllabusCompletionPct,
    required this.classCompatibility,
    this.sourceClassName,
    this.sourceSectionName,
    required this.notes,
    required this.compatibleSlots,
  });

  factory CandidateEvaluationModel.fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List<dynamic>?) ?? [];
    final rawSlots = (json['compatible_slots'] as List<dynamic>?) ?? [];
    return CandidateEvaluationModel(
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? 'Teacher',
      qualification: json['qualification'] as String?,
      specialization: json['specialization'] as String?,
      eligibilityStatus: json['eligibility_status'] as String? ?? 'ELIGIBLE',
      hasAvailableCapacity: json['has_available_capacity'] as bool? ?? true,
      maxWeeklyCapacity: (json['max_weekly_capacity'] as num?)?.toInt() ?? 30,
      currentWeeklyPeriods: (json['current_weekly_periods'] as num?)?.toInt() ?? 0,
      availableCapacity: (json['available_capacity'] as num?)?.toInt() ?? 0,
      currentSyllabusCompletionPct: (json['current_syllabus_completion_pct'] as num?)?.toDouble() ?? 0.0,
      classCompatibility: json['class_compatibility'] as String? ?? 'PARALLEL_SECTION',
      sourceClassName: json['source_class_name'] as String?,
      sourceSectionName: json['source_section_name'] as String?,
      notes: rawNotes.map((e) => e.toString()).toList(),
      compatibleSlots: rawSlots.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

class CrossTeacherRecoveryRecommendationModel {
  final String planId;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final double currentCompletion;
  final int delayDays;
  final String? recommendedSupportTeacherId;
  final String? recommendedSupportTeacherName;
  final String? primaryTeacherId;
  final String? primaryTeacherName;
  final String aiRecommendationText;
  final int recommendedPeriodsPerWeek;
  final int durationWeeks;
  final int totalRecoveryPeriods;
  final int projectedImprovementDays;
  final String? forecastCompletionDate;
  final String? newProjectedCompletionDate;
  final String parentNotes;
  final List<CandidateEvaluationModel> candidateEvaluations;
  final List<Map<String, dynamic>> proposedSlots;
  final String status;

  const CrossTeacherRecoveryRecommendationModel({
    required this.planId,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    required this.currentCompletion,
    required this.delayDays,
    this.recommendedSupportTeacherId,
    this.recommendedSupportTeacherName,
    this.primaryTeacherId,
    this.primaryTeacherName,
    required this.aiRecommendationText,
    required this.recommendedPeriodsPerWeek,
    required this.durationWeeks,
    required this.totalRecoveryPeriods,
    required this.projectedImprovementDays,
    this.forecastCompletionDate,
    this.newProjectedCompletionDate,
    required this.parentNotes,
    required this.candidateEvaluations,
    required this.proposedSlots,
    required this.status,
  });

  factory CrossTeacherRecoveryRecommendationModel.fromJson(Map<String, dynamic> json) {
    final rawCandidates = (json['candidate_evaluations'] as List<dynamic>?) ?? [];
    final rawSlots = (json['proposed_slots'] as List<dynamic>?) ?? [];

    return CrossTeacherRecoveryRecommendationModel(
      planId: json['plan_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? 'Class',
      sectionId: json['section_id'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? 'Section',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      currentCompletion: (json['current_completion'] as num?)?.toDouble() ?? 0.0,
      delayDays: (json['delay_days'] as num?)?.toInt() ?? 0,
      recommendedSupportTeacherId: json['recommended_support_teacher_id'] as String?,
      recommendedSupportTeacherName: json['recommended_support_teacher_name'] as String?,
      primaryTeacherId: json['primary_teacher_id'] as String?,
      primaryTeacherName: json['primary_teacher_name'] as String?,
      aiRecommendationText: json['ai_recommendation_text'] as String? ?? '',
      recommendedPeriodsPerWeek: (json['recommended_periods_per_week'] as num?)?.toInt() ?? 1,
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 2,
      totalRecoveryPeriods: (json['total_recovery_periods'] as num?)?.toInt() ?? 2,
      projectedImprovementDays: (json['projected_improvement_days'] as num?)?.toInt() ?? 0,
      forecastCompletionDate: json['forecast_completion_date'] as String?,
      newProjectedCompletionDate: json['new_projected_completion_date'] as String?,
      parentNotes: json['parent_notes'] as String? ?? '',
      candidateEvaluations: rawCandidates.map((e) => CandidateEvaluationModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      proposedSlots: rawSlots.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      status: json['status'] as String? ?? 'PROPOSED',
    );
  }
}

class RecoveryAnalyticsSummaryModel {
  final int totalNormalTeachingPeriods;
  final int totalRecoveryTeachingPeriods;
  final int totalCrossTeacherSupportPeriods;
  final int totalAbsenceRecoveryPeriods;
  final int activeRecoveryPlansCount;
  final int completedRecoveryPlansCount;

  const RecoveryAnalyticsSummaryModel({
    required this.totalNormalTeachingPeriods,
    required this.totalRecoveryTeachingPeriods,
    required this.totalCrossTeacherSupportPeriods,
    required this.totalAbsenceRecoveryPeriods,
    required this.activeRecoveryPlansCount,
    required this.completedRecoveryPlansCount,
  });

  factory RecoveryAnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return RecoveryAnalyticsSummaryModel(
      totalNormalTeachingPeriods: (json['total_normal_teaching_periods'] as num?)?.toInt() ?? 0,
      totalRecoveryTeachingPeriods: (json['total_recovery_teaching_periods'] as num?)?.toInt() ?? 0,
      totalCrossTeacherSupportPeriods: (json['total_cross_teacher_support_periods'] as num?)?.toInt() ?? 0,
      totalAbsenceRecoveryPeriods: (json['total_absence_recovery_periods'] as num?)?.toInt() ?? 0,
      activeRecoveryPlansCount: (json['active_recovery_plans_count'] as num?)?.toInt() ?? 0,
      completedRecoveryPlansCount: (json['completed_recovery_plans_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AcademicHeatmapCellModel {
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final double completionPercentage;
  final String status;
  final int delayDays;
  final String? targetDate;
  final String? forecastDate;
  final bool recoveryPlanActive;
  final String? recoveryPlanId;

  const AcademicHeatmapCellModel({
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.completionPercentage,
    required this.status,
    required this.delayDays,
    this.targetDate,
    this.forecastDate,
    this.recoveryPlanActive = false,
    this.recoveryPlanId,
  });

  factory AcademicHeatmapCellModel.fromJson(Map<String, dynamic> json) {
    return AcademicHeatmapCellModel(
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'ON_TRACK',
      delayDays: (json['delay_days'] as num?)?.toInt() ?? 0,
      targetDate: json['target_date'] as String?,
      forecastDate: json['forecast_date'] as String?,
      recoveryPlanActive: json['recovery_plan_active'] as bool? ?? false,
      recoveryPlanId: json['recovery_plan_id'] as String?,
    );
  }
}

class AcademicHeatmapDataModel {
  final String schoolId;
  final String academicYearId;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final List<AcademicHeatmapCellModel> cells;
  final Map<String, dynamic> summary;

  const AcademicHeatmapDataModel({
    required this.schoolId,
    required this.academicYearId,
    required this.classes,
    required this.subjects,
    required this.cells,
    required this.summary,
  });

  factory AcademicHeatmapDataModel.fromJson(Map<String, dynamic> json) {
    final rawClasses = (json['classes'] as List<dynamic>?) ?? [];
    final rawSubjects = (json['subjects'] as List<dynamic>?) ?? [];
    final rawCells = (json['cells'] as List<dynamic>?) ?? [];
    return AcademicHeatmapDataModel(
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      classes: rawClasses.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      subjects: rawSubjects.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      cells: rawCells.map((e) => AcademicHeatmapCellModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      summary: (json['summary'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class RecoveryPlanItemModel {
  final String id;
  final String date;
  final int periodNumber;
  final String phase;
  final String topicName;
  final int durationMinutes;
  final String? teacherId;
  final String? teacherName;
  final String classId;
  final String? className;
  final String sectionId;
  final String? sectionName;
  final String? roomId;
  final String? roomName;
  final String status;
  final bool isApproved;
  final String conflictStatus;
  final String? conflictMessage;

  const RecoveryPlanItemModel({
    required this.id,
    required this.date,
    required this.periodNumber,
    required this.phase,
    required this.topicName,
    required this.durationMinutes,
    this.teacherId,
    this.teacherName,
    required this.classId,
    this.className,
    required this.sectionId,
    this.sectionName,
    this.roomId,
    this.roomName,
    required this.status,
    required this.isApproved,
    required this.conflictStatus,
    this.conflictMessage,
  });

  factory RecoveryPlanItemModel.fromJson(Map<String, dynamic> json) {
    return RecoveryPlanItemModel(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      phase: json['phase'] as String? ?? 'PHASE_1_CATCHUP',
      topicName: json['topic_name'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String?,
      sectionId: json['section_id'] as String? ?? '',
      sectionName: json['section_name'] as String?,
      roomId: json['room_id'] as String?,
      roomName: json['room_name'] as String?,
      status: json['status'] as String? ?? 'SUGGESTED',
      isApproved: json['is_approved'] as bool? ?? false,
      conflictStatus: json['conflict_status'] as String? ?? 'NO_CONFLICT',
      conflictMessage: json['conflict_message'] as String?,
    );
  }
}

class AdminSyllabusRecoveryPlanModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String? className;
  final String sectionId;
  final String? sectionName;
  final String subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final String recoveryType;
  final String reason;
  final double currentCompletion;
  final String? targetCompletionDate;
  final String? forecastCompletionDate;
  final String? newForecastDate;
  final double expectedRecoveryPeriods;
  final String status;
  final String? rejectionRemarks;
  final List<RecoveryPlanItemModel> items;

  const AdminSyllabusRecoveryPlanModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    this.className,
    required this.sectionId,
    this.sectionName,
    required this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    this.recoveryType = 'TEACHER_SELF_RECOVERY',
    required this.reason,
    required this.currentCompletion,
    this.targetCompletionDate,
    this.forecastCompletionDate,
    this.newForecastDate,
    required this.expectedRecoveryPeriods,
    required this.status,
    this.rejectionRemarks,
    required this.items,
  });

  factory AdminSyllabusRecoveryPlanModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    return AdminSyllabusRecoveryPlanModel(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String?,
      sectionId: json['section_id'] as String? ?? '',
      sectionName: json['section_name'] as String?,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String?,
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      recoveryType: json['recovery_type'] as String? ?? 'TEACHER_SELF_RECOVERY',
      reason: json['reason'] as String? ?? '',
      currentCompletion: (json['current_completion'] as num?)?.toDouble() ?? 0.0,
      targetCompletionDate: json['target_completion_date'] as String?,
      forecastCompletionDate: json['forecast_completion_date'] as String?,
      newForecastDate: json['new_forecast_date'] as String?,
      expectedRecoveryPeriods: (json['expected_recovery_periods'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'SUGGESTED',
      rejectionRemarks: json['rejection_remarks'] as String?,
      items: rawItems.map((e) => RecoveryPlanItemModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class SubjectCoverageSummary {
  final String subjectId;
  final String subjectName;
  final int totalTopics;
  final int completedTopics;
  final int inProgressTopics;
  final int pendingTopics;
  final double coveragePercentage;
  final int plannedPeriods;
  final int completedPeriods;
  final int weeklyTimetablePeriods;
  final String? sectionId;
  final String? sectionName;
  final List<ChapterCoverageItem> chapters;

  const SubjectCoverageSummary({
    required this.subjectId,
    required this.subjectName,
    required this.totalTopics,
    required this.completedTopics,
    required this.inProgressTopics,
    required this.pendingTopics,
    required this.coveragePercentage,
    required this.plannedPeriods,
    required this.completedPeriods,
    required this.weeklyTimetablePeriods,
    this.sectionId,
    this.sectionName,
    required this.chapters,
  });

  factory SubjectCoverageSummary.fromJson(Map<String, dynamic> json) {
    return SubjectCoverageSummary(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      completedTopics: (json['completed_topics'] as num?)?.toInt() ?? 0,
      inProgressTopics: (json['in_progress_topics'] as num?)?.toInt() ?? 0,
      pendingTopics: (json['pending_topics'] as num?)?.toInt() ?? 0,
      coveragePercentage: (json['coverage_percentage'] as num?)?.toDouble() ?? 0.0,
      plannedPeriods: (json['planned_periods'] as num?)?.toInt() ?? 0,
      completedPeriods: (json['completed_periods'] as num?)?.toInt() ?? 0,
      weeklyTimetablePeriods: (json['weekly_timetable_periods'] as num?)?.toInt() ?? 0,
      sectionId: json['section_id'] as String?,
      sectionName: json['section_name'] as String?,
      chapters: ((json['chapters'] as List<dynamic>?) ?? [])
          .map((c) => ChapterCoverageItem.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }
}

class ChapterCoverageItem {
  final String chapterName;
  final String unitName;
  final int totalTopics;
  final int completedTopics;
  final double coveragePercentage;
  final int plannedPeriods;
  final int completedPeriods;

  const ChapterCoverageItem({
    required this.chapterName,
    required this.unitName,
    required this.totalTopics,
    required this.completedTopics,
    required this.coveragePercentage,
    required this.plannedPeriods,
    required this.completedPeriods,
  });

  factory ChapterCoverageItem.fromJson(Map<String, dynamic> json) {
    return ChapterCoverageItem(
      chapterName: json['chapter_name'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? '',
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      completedTopics: (json['completed_topics'] as num?)?.toInt() ?? 0,
      coveragePercentage: (json['coverage_percentage'] as num?)?.toDouble() ?? 0.0,
      plannedPeriods: (json['planned_periods'] as num?)?.toInt() ?? 0,
      completedPeriods: (json['completed_periods'] as num?)?.toInt() ?? 0,
    );
  }
}


