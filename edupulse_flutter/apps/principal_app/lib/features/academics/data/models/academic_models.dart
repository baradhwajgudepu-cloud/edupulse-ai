class ExamSchedule {
  final String id;
  final String subjectId;
  final String examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;

  ExamSchedule({
    required this.id,
    required this.subjectId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      examDate: json['exam_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      maxMarks: json['max_marks'] as int? ?? 100,
      passMarks: json['pass_marks'] as int? ?? 35,
    );
  }
}

class Examination {
  final String id;
  final String examName;
  final String examType;
  final String startDate;
  final String endDate;
  final String status;
  final String? description;
  final List<ExamSchedule> schedules;

  Examination({
    required this.id,
    required this.examName,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    required this.schedules,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    final schedList = json['schedules'] as List<dynamic>? ?? [];
    return Examination(
      id: json['id'] as String? ?? '',
      examName: json['exam_name'] as String? ?? '',
      examType: json['exam_type'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      description: json['description'] as String?,
      schedules: schedList.map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MarksSummary {
  final double classAverage;
  final double passPercentage;
  final double highestScore;
  final double lowestScore;
  final int missingCount;
  final int absentCount;

  MarksSummary({
    required this.classAverage,
    required this.passPercentage,
    required this.highestScore,
    required this.lowestScore,
    required this.missingCount,
    required this.absentCount,
  });

  factory MarksSummary.fromJson(Map<String, dynamic> json) {
    return MarksSummary(
      classAverage: (json['class_average'] as num?)?.toDouble() ?? 0.0,
      passPercentage: (json['pass_percentage'] as num?)?.toDouble() ?? 0.0,
      highestScore: (json['highest_score'] as num?)?.toDouble() ?? 0.0,
      lowestScore: (json['lowest_score'] as num?)?.toDouble() ?? 0.0,
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory MarksSummary.empty() {
    return MarksSummary(
      classAverage: 0.0,
      passPercentage: 0.0,
      highestScore: 0.0,
      lowestScore: 0.0,
      missingCount: 0,
      absentCount: 0,
    );
  }
}

class AcademicHeatmapCell {
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

  AcademicHeatmapCell({
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

  factory AcademicHeatmapCell.fromJson(Map<String, dynamic> json) {
    return AcademicHeatmapCell(
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

class AcademicHeatmapData {
  final String schoolId;
  final String academicYearId;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final List<AcademicHeatmapCell> cells;
  final Map<String, dynamic> summary;

  AcademicHeatmapData({
    required this.schoolId,
    required this.academicYearId,
    required this.classes,
    required this.subjects,
    required this.cells,
    required this.summary,
  });

  factory AcademicHeatmapData.fromJson(Map<String, dynamic> json) {
    final rawClasses = (json['classes'] as List<dynamic>?) ?? [];
    final rawSubjects = (json['subjects'] as List<dynamic>?) ?? [];
    final rawCells = (json['cells'] as List<dynamic>?) ?? [];
    return AcademicHeatmapData(
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      classes: rawClasses.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      subjects: rawSubjects.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      cells: rawCells.map((e) => AcademicHeatmapCell.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      summary: (json['summary'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class RecoveryPlanItem {
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

  RecoveryPlanItem({
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

  factory RecoveryPlanItem.fromJson(Map<String, dynamic> json) {
    return RecoveryPlanItem(
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

class SyllabusRecoveryPlan {
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
  final List<RecoveryPlanItem> items;

  SyllabusRecoveryPlan({
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

  factory SyllabusRecoveryPlan.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    return SyllabusRecoveryPlan(
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
      items: rawItems.map((e) => RecoveryPlanItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class TeacherAbsenceImpact {
  final String teacherId;
  final String teacherName;
  final String absenceDate;
  final int totalMissedPeriods;
  final List<Map<String, dynamic>> affectedClasses;
  final List<Map<String, dynamic>> affectedTopics;
  final Map<String, dynamic> forecastDelays;
  final bool recoveryRecommended;

  TeacherAbsenceImpact({
    required this.teacherId,
    required this.teacherName,
    required this.absenceDate,
    required this.totalMissedPeriods,
    required this.affectedClasses,
    required this.affectedTopics,
    required this.forecastDelays,
    required this.recoveryRecommended,
  });

  factory TeacherAbsenceImpact.fromJson(Map<String, dynamic> json) {
    return TeacherAbsenceImpact(
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      absenceDate: json['absence_date'] as String? ?? '',
      totalMissedPeriods: (json['total_missed_periods'] as num?)?.toInt() ?? 0,
      affectedClasses: ((json['affected_classes'] as List<dynamic>?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      affectedTopics: ((json['affected_topics'] as List<dynamic>?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      forecastDelays: (json['forecast_delays'] as Map<String, dynamic>?) ?? {},
      recoveryRecommended: json['recovery_recommended'] as bool? ?? false,
    );
  }
}
