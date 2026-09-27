import 'package:flutter/material.dart';

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get value => name.toUpperCase();

  String get displayLabel {
    switch (this) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }

  String get shortLabel {
    switch (this) {
      case DayOfWeek.monday:
        return 'Mon';
      case DayOfWeek.tuesday:
        return 'Tue';
      case DayOfWeek.wednesday:
        return 'Wed';
      case DayOfWeek.thursday:
        return 'Thu';
      case DayOfWeek.friday:
        return 'Fri';
      case DayOfWeek.saturday:
        return 'Sat';
      case DayOfWeek.sunday:
        return 'Sun';
    }
  }

  static DayOfWeek fromString(String val) {
    switch (val.toUpperCase()) {
      case 'MONDAY':
        return DayOfWeek.monday;
      case 'TUESDAY':
        return DayOfWeek.tuesday;
      case 'WEDNESDAY':
        return DayOfWeek.wednesday;
      case 'THURSDAY':
        return DayOfWeek.thursday;
      case 'FRIDAY':
        return DayOfWeek.friday;
      case 'SATURDAY':
        return DayOfWeek.saturday;
      case 'SUNDAY':
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }
}

enum PeriodType {
  regular,
  lab,
  sports,
  library,
  breakPeriod,
  exam;

  String get value {
    switch (this) {
      case PeriodType.breakPeriod:
        return 'BREAK';
      default:
        return name.toUpperCase();
    }
  }

  String get displayLabel {
    switch (this) {
      case PeriodType.regular:
        return 'Regular';
      case PeriodType.lab:
        return 'Lab / Practical';
      case PeriodType.sports:
        return 'Physical Ed / Sports';
      case PeriodType.library:
        return 'Library';
      case PeriodType.breakPeriod:
        return 'Break / Recess';
      case PeriodType.exam:
        return 'Examination';
    }
  }

  IconData get icon {
    switch (this) {
      case PeriodType.regular:
        return Icons.menu_book_outlined;
      case PeriodType.lab:
        return Icons.biotech_outlined;
      case PeriodType.sports:
        return Icons.sports_soccer_outlined;
      case PeriodType.library:
        return Icons.local_library_outlined;
      case PeriodType.breakPeriod:
        return Icons.free_breakfast_outlined;
      case PeriodType.exam:
        return Icons.fact_check_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PeriodType.regular:
        return const Color(0xFF1E40AF); // Deep Blue
      case PeriodType.lab:
        return const Color(0xFF7C3AED); // Purple
      case PeriodType.sports:
        return const Color(0xFF059669); // Emerald
      case PeriodType.library:
        return const Color(0xFF0D9488); // Teal
      case PeriodType.breakPeriod:
        return const Color(0xFFD97706); // Amber
      case PeriodType.exam:
        return const Color(0xFFDC2626); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PeriodType.regular:
        return const Color(0xFFEFF6FF);
      case PeriodType.lab:
        return const Color(0xFFF5F3FF);
      case PeriodType.sports:
        return const Color(0xFFECFDF5);
      case PeriodType.library:
        return const Color(0xFFF0FDFA);
      case PeriodType.breakPeriod:
        return const Color(0xFFFFFBEB);
      case PeriodType.exam:
        return const Color(0xFFFEF2F2);
    }
  }

  static PeriodType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'LAB':
        return PeriodType.lab;
      case 'SPORTS':
        return PeriodType.sports;
      case 'LIBRARY':
        return PeriodType.library;
      case 'BREAK':
        return PeriodType.breakPeriod;
      case 'EXAM':
        return PeriodType.exam;
      case 'REGULAR':
      default:
        return PeriodType.regular;
    }
  }
}

@immutable
class TimetableDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String? teacherSubjectAssignmentId;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  
  final DayOfWeek dayOfWeek;
  final int periodNumber;
  final String? periodId;
  
  final String startTime;
  final String endTime;
  
  final PeriodType periodType;
  final String? roomId;
  final bool isAvailable;
  
  final String status;
  final bool isActive;
  final int version;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;

  const TimetableDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    this.teacherSubjectAssignmentId,
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.dayOfWeek,
    required this.periodNumber,
    this.periodId,
    required this.startTime,
    required this.endTime,
    required this.periodType,
    this.roomId,
    required this.isAvailable,
    required this.status,
    required this.isActive,
    required this.version,
    this.settings = const {},
    this.aiMetrics = const {},
  });

  String get formattedTimeRange {
    final start = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    final end = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    return '$start - $end';
  }

  factory TimetableDto.fromJson(Map<String, dynamic> json) {
    return TimetableDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id'] as String?,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      dayOfWeek: DayOfWeek.fromString(json['day_of_week'] as String? ?? 'MONDAY'),
      periodNumber: json['period_number'] as int? ?? 1,
      periodId: json['period_id'] as String?,
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '09:45',
      periodType: PeriodType.fromString(json['period_type'] as String? ?? 'REGULAR'),
      roomId: (json['room_number'] ?? json['room_id']) as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      settings: (json['settings'] as Map<String, dynamic>?) ?? const {},
      aiMetrics: (json['ai_metrics'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'class_id': classId,
      'section_id': sectionId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'day_of_week': dayOfWeek.value,
      'period_number': periodNumber,
      'period_id': periodId,
      'start_time': startTime,
      'end_time': endTime,
      'period_type': periodType.value,
      'room_id': roomId,
      'is_available': isAvailable,
      'status': status,
      'is_active': isActive,
      'version': version,
      'settings': settings,
      'ai_metrics': aiMetrics,
    };
  }
}

class TimetableConflictDto {
  final bool hasConflict;
  final String? conflictType;
  final String? conflictMessage;

  const TimetableConflictDto({
    required this.hasConflict,
    this.conflictType,
    this.conflictMessage,
  });

  factory TimetableConflictDto.fromJson(Map<String, dynamic> json) {
    return TimetableConflictDto(
      hasConflict: json['has_conflict'] as bool? ?? false,
      conflictType: json['conflict_type'] as String?,
      conflictMessage: json['conflict_message'] as String?,
    );
  }
}

class StateHolidayVerificationStatus {
  final String state;
  final String academicYearCode;
  final bool isVerified;
  final String? source;
  final String? sourceVersion;
  final int holidaysCount;
  final String message;
  final bool canImport;

  const StateHolidayVerificationStatus({
    required this.state,
    required this.academicYearCode,
    required this.isVerified,
    this.source,
    this.sourceVersion,
    required this.holidaysCount,
    required this.message,
    required this.canImport,
  });

  factory StateHolidayVerificationStatus.fromJson(Map<String, dynamic> json) {
    return StateHolidayVerificationStatus(
      state: json['state'] as String? ?? '',
      academicYearCode: json['academic_year_code'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      source: json['source'] as String?,
      sourceVersion: json['source_version'] as String?,
      holidaysCount: (json['holidays_count'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      canImport: json['can_import'] as bool? ?? true,
    );
  }
}

class HolidayImpactData {
  final String holidayDate;
  final String holidayTitle;
  final String holidayType;
  final int affectedPeriodsCount;
  final int affectedSectionsCount;
  final int affectedTeachersCount;
  final int syllabusRisksCount;
  final List<String> syllabusRiskDetails;

  const HolidayImpactData({
    required this.holidayDate,
    required this.holidayTitle,
    required this.holidayType,
    required this.affectedPeriodsCount,
    required this.affectedSectionsCount,
    required this.affectedTeachersCount,
    required this.syllabusRisksCount,
    this.syllabusRiskDetails = const [],
  });

  factory HolidayImpactData.fromJson(Map<String, dynamic> json) {
    final risks = (json['syllabus_risk_details'] as List<dynamic>?) ??
        (json['syllabus_risks'] as List<dynamic>?) ??
        [];
    return HolidayImpactData(
      holidayDate: json['holiday_date'] as String? ?? '',
      holidayTitle: json['holiday_title'] as String? ?? json['title'] as String? ?? 'Declared Holiday',
      holidayType: json['holiday_type'] as String? ?? 'PRINCIPAL_DECLARED_HOLIDAY',
      affectedPeriodsCount: (json['affected_periods_count'] as num?)?.toInt() ?? (json['periods_affected'] as num?)?.toInt() ?? 0,
      affectedSectionsCount: (json['affected_sections_count'] as num?)?.toInt() ?? (json['sections_affected'] as num?)?.toInt() ?? 0,
      affectedTeachersCount: (json['affected_teachers_count'] as num?)?.toInt() ?? (json['teachers_affected'] as num?)?.toInt() ?? 0,
      syllabusRisksCount: (json['syllabus_risks_count'] as num?)?.toInt() ?? risks.length,
      syllabusRiskDetails: risks.map((e) => e.toString()).toList(),
    );
  }
}

class AIRecoveryChange {
  final String originalTimetableId;
  final String classId;
  final String sectionId;
  final String className;
  final String sectionName;
  final String teacherId;
  final String teacherName;
  final String subjectId;
  final String subjectName;
  final String originalDay;
  final int originalPeriodNumber;
  final String targetDay;
  final int targetPeriodNumber;
  final String targetDate;
  final String action;
  final String reason;

  const AIRecoveryChange({
    required this.originalTimetableId,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.teacherId,
    required this.teacherName,
    required this.subjectId,
    required this.subjectName,
    required this.originalDay,
    required this.originalPeriodNumber,
    required this.targetDay,
    required this.targetPeriodNumber,
    required this.targetDate,
    required this.action,
    required this.reason,
  });

  factory AIRecoveryChange.fromJson(Map<String, dynamic> json) {
    return AIRecoveryChange(
      originalTimetableId: json['original_timetable_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      originalDay: json['original_day'] as String? ?? '',
      originalPeriodNumber: (json['original_period_number'] as num?)?.toInt() ?? 1,
      targetDay: json['target_day'] as String? ?? '',
      targetPeriodNumber: (json['target_period_number'] as num?)?.toInt() ?? 1,
      targetDate: json['target_date'] as String? ?? '',
      action: json['action'] as String? ?? 'MOVE_SLOT',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original_timetable_id': originalTimetableId,
      'class_id': classId,
      'section_id': sectionId,
      'class_name': className,
      'section_name': sectionName,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'original_day': originalDay,
      'original_period_number': originalPeriodNumber,
      'target_day': targetDay,
      'target_period_number': targetPeriodNumber,
      'target_date': targetDate,
      'action': action,
      'reason': reason,
    };
  }
}

class AIRecoveryPreview {
  final String recoveryId;
  final String holidayEventId;
  final String holidayDate;
  final String holidayTitle;
  final int totalSlotsAffected;
  final int totalSlotsRecovered;
  final int unrecoveredSlots;
  final List<AIRecoveryChange> changes;
  final String summary;
  final String status;

  const AIRecoveryPreview({
    required this.recoveryId,
    required this.holidayEventId,
    required this.holidayDate,
    required this.holidayTitle,
    required this.totalSlotsAffected,
    required this.totalSlotsRecovered,
    required this.unrecoveredSlots,
    required this.changes,
    required this.summary,
    this.status = 'PENDING_APPROVAL',
  });

  factory AIRecoveryPreview.fromJson(Map<String, dynamic> json) {
    final changesRaw = (json['changes'] as List<dynamic>?) ??
        (json['proposed_changes'] as List<dynamic>?) ??
        [];
    return AIRecoveryPreview(
      recoveryId: json['recovery_id'] as String? ?? json['id'] as String? ?? '',
      holidayEventId: json['holiday_event_id'] as String? ?? '',
      holidayDate: json['holiday_date'] as String? ?? '',
      holidayTitle: json['holiday_title'] as String? ?? '',
      totalSlotsAffected: (json['total_slots_affected'] as num?)?.toInt() ?? (json['periods_affected'] as num?)?.toInt() ?? 0,
      totalSlotsRecovered: (json['total_slots_recovered'] as num?)?.toInt() ?? changesRaw.length,
      unrecoveredSlots: (json['unrecovered_slots'] as num?)?.toInt() ?? 0,
      changes: changesRaw.map((e) => AIRecoveryChange.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      summary: json['summary'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING_APPROVAL',
    );
  }
}

class TimetableCapacitySummaryDto {
  final String schoolId;
  final String academicYearId;
  final String? classId;
  final String? sectionId;
  final int workingDaysCount;
  final int periodsPerDay;
  final int availableWeeklyCapacity;
  final int totalSubjectsConfigured;
  final int officialSubjectsCount;
  final int schoolAddedSubjectsCount;
  final int totalRequiredPeriods;
  final int remainingCapacity;
  final bool isShortfall;
  final int shortfallPeriods;
  final String? shortfallWarningMessage;
  final bool isExtendedHoursEnabled;
  final int extendedHoursPotentialCapacity;
  final List<String> remediationOptions;

  const TimetableCapacitySummaryDto({
    required this.schoolId,
    required this.academicYearId,
    this.classId,
    this.sectionId,
    required this.workingDaysCount,
    required this.periodsPerDay,
    required this.availableWeeklyCapacity,
    required this.totalSubjectsConfigured,
    required this.officialSubjectsCount,
    required this.schoolAddedSubjectsCount,
    required this.totalRequiredPeriods,
    required this.remainingCapacity,
    required this.isShortfall,
    required this.shortfallPeriods,
    this.shortfallWarningMessage,
    required this.isExtendedHoursEnabled,
    required this.extendedHoursPotentialCapacity,
    required this.remediationOptions,
  });

  factory TimetableCapacitySummaryDto.fromJson(Map<String, dynamic> json) {
    return TimetableCapacitySummaryDto(
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      classId: json['class_id'] as String?,
      sectionId: json['section_id'] as String?,
      workingDaysCount: (json['working_days_count'] as num?)?.toInt() ?? 6,
      periodsPerDay: (json['periods_per_day'] as num?)?.toInt() ?? 8,
      availableWeeklyCapacity: (json['available_weekly_capacity'] as num? ?? json['total_periods_available'] as num?)?.toInt() ?? 48,
      totalSubjectsConfigured: (json['total_subjects_configured'] as num?)?.toInt() ?? 0,
      officialSubjectsCount: (json['official_subjects_count'] as num?)?.toInt() ?? 0,
      schoolAddedSubjectsCount: (json['school_added_subjects_count'] as num?)?.toInt() ?? 0,
      totalRequiredPeriods: (json['total_required_periods'] as num? ?? json['total_periods_required'] as num?)?.toInt() ?? 0,
      remainingCapacity: (json['remaining_capacity'] as num?)?.toInt() ?? 0,
      isShortfall: json['is_shortfall'] as bool? ?? false,
      shortfallPeriods: (json['shortfall_periods'] as num?)?.toInt() ?? 0,
      shortfallWarningMessage: json['shortfall_warning_message'] as String?,
      isExtendedHoursEnabled: json['is_extended_hours_enabled'] as bool? ?? false,
      extendedHoursPotentialCapacity: (json['extended_hours_potential_capacity'] as num? ?? json['extended_periods_available'] as num?)?.toInt() ?? 0,
      remediationOptions: ((json['remediation_options'] ?? json['remediation_choices']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class ExtendedWorkingHourDto {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String normalStartTime;
  final String normalEndTime;
  final int periodsPerDay;
  final int lunchPeriodNumber;
  final List<String> workingDays;
  final bool isExtendedHoursEnabled;
  final String? extendedStartTime;
  final String? extendedEndTime;
  final List<String> applicableDays;
  final int additionalPeriods;
  final String activityType;
  final int weeklyNormalPeriods;
  final int weeklyExtendedPeriods;
  final int totalWeeklyCapacity;

  const ExtendedWorkingHourDto({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.normalStartTime,
    required this.normalEndTime,
    required this.periodsPerDay,
    required this.lunchPeriodNumber,
    required this.workingDays,
    required this.isExtendedHoursEnabled,
    this.extendedStartTime,
    this.extendedEndTime,
    required this.applicableDays,
    required this.additionalPeriods,
    required this.activityType,
    required this.weeklyNormalPeriods,
    required this.weeklyExtendedPeriods,
    required this.totalWeeklyCapacity,
    this.periodDurationMinutes = 45,
    this.breaks = const [],
    this.calculatedEndTime,
    this.requiresExtension = false,
    this.extensionMinutes = 0,
    this.calculatedTimings = const [],
  });

  final int periodDurationMinutes;
  final List<BreakTimingDto> breaks;
  final String? calculatedEndTime;
  final bool requiresExtension;
  final int extensionMinutes;
  final List<Map<String, dynamic>> calculatedTimings;

  factory ExtendedWorkingHourDto.fromJson(Map<String, dynamic> json) {
    return ExtendedWorkingHourDto(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      normalStartTime: json['normal_start_time'] as String? ?? '08:30',
      normalEndTime: json['normal_end_time'] as String? ?? '15:30',
      periodsPerDay: (json['periods_per_day'] as num?)?.toInt() ?? 8,
      lunchPeriodNumber: (json['lunch_period_number'] as num?)?.toInt() ?? 4,
      workingDays: (json['working_days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'],
      isExtendedHoursEnabled: json['is_extended_hours_enabled'] as bool? ?? false,
      extendedStartTime: json['extended_start_time'] as String?,
      extendedEndTime: json['extended_end_time'] as String?,
      applicableDays: (json['applicable_days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      additionalPeriods: (json['additional_periods'] as num?)?.toInt() ?? 1,
      activityType: json['activity_type'] as String? ?? 'ADDITIONAL_SUBJECT',
      weeklyNormalPeriods: (json['weekly_normal_periods'] as num?)?.toInt() ?? 48,
      weeklyExtendedPeriods: (json['weekly_extended_periods'] as num?)?.toInt() ?? 0,
      totalWeeklyCapacity: (json['total_weekly_capacity'] as num?)?.toInt() ?? 48,
      periodDurationMinutes: (json['period_duration_minutes'] as num?)?.toInt() ?? 45,
      breaks: (json['breaks'] as List<dynamic>?)
              ?.map((e) => BreakTimingDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      calculatedEndTime: json['calculated_end_time'] as String?,
      requiresExtension: json['requires_extension'] as bool? ?? false,
      extensionMinutes: (json['extension_minutes'] as num?)?.toInt() ?? 0,
      calculatedTimings: (json['calculated_timings'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'normal_start_time': normalStartTime,
      'normal_end_time': normalEndTime,
      'periods_per_day': periodsPerDay,
      'lunch_period_number': lunchPeriodNumber,
      'working_days': workingDays,
      'is_extended_hours_enabled': isExtendedHoursEnabled,
      'extended_start_time': extendedStartTime,
      'extended_end_time': extendedEndTime,
      'applicable_days': applicableDays,
      'additional_periods': additionalPeriods,
      'activity_type': activityType,
      'period_duration_minutes': periodDurationMinutes,
      'breaks': breaks.map((b) => b.toJson()).toList(),
    };
  }
}

class BreakTimingDto {
  final String id;
  final String name;
  final String breakType; // SHORT_BREAK | LUNCH_BREAK
  final int afterPeriod;
  final int durationMinutes;
  final String? startTime;
  final String? endTime;

  const BreakTimingDto({
    required this.id,
    required this.name,
    required this.breakType,
    required this.afterPeriod,
    required this.durationMinutes,
    this.startTime,
    this.endTime,
  });

  factory BreakTimingDto.fromJson(Map<String, dynamic> json) {
    return BreakTimingDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Break',
      breakType: json['break_type'] as String? ?? 'SHORT_BREAK',
      afterPeriod: (json['after_period'] as num?)?.toInt() ?? 4,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      startTime: json['start_time_str'] as String? ?? json['start_time'] as String?,
      endTime: json['end_time_str'] as String? ?? json['end_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'break_type': breakType,
      'after_period': afterPeriod,
      'duration_minutes': durationMinutes,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
    };
  }
}

class TimetableRecalculationPreviewDto {
  final String normalStartTime;
  final String originalEndTime;
  final String calculatedEndTime;
  final int extensionMinutes;
  final bool requiresExtension;
  final int periodsPerDay;
  final int periodDurationMinutes;
  final List<BreakTimingDto> breaks;
  final List<Map<String, dynamic>> periodTimings;

  const TimetableRecalculationPreviewDto({
    required this.normalStartTime,
    required this.originalEndTime,
    required this.calculatedEndTime,
    required this.extensionMinutes,
    required this.requiresExtension,
    required this.periodsPerDay,
    required this.periodDurationMinutes,
    required this.breaks,
    required this.periodTimings,
  });

  factory TimetableRecalculationPreviewDto.fromJson(Map<String, dynamic> json) {
    return TimetableRecalculationPreviewDto(
      normalStartTime: json['normal_start_time'] as String? ?? '08:30',
      originalEndTime: json['original_end_time'] as String? ?? '15:30',
      calculatedEndTime: json['calculated_end_time'] as String? ?? '15:30',
      extensionMinutes: (json['extension_minutes'] as num?)?.toInt() ?? 0,
      requiresExtension: json['requires_extension'] as bool? ?? false,
      periodsPerDay: (json['periods_per_day'] as num?)?.toInt() ?? 8,
      periodDurationMinutes: (json['period_duration_minutes'] as num?)?.toInt() ?? 45,
      breaks: (json['breaks'] as List<dynamic>?)
              ?.map((e) => BreakTimingDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      periodTimings: (json['period_timings'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class TimetableMoveRequest {
  final String sourceId;
  final DayOfWeek targetDayOfWeek;
  final int targetPeriodNumber;
  final String schoolId;
  final String academicYearId;

  const TimetableMoveRequest({
    required this.sourceId,
    required this.targetDayOfWeek,
    required this.targetPeriodNumber,
    required this.schoolId,
    required this.academicYearId,
  });

  Map<String, dynamic> toJson() {
    return {
      'source_id': sourceId,
      'target_day_of_week': targetDayOfWeek.value,
      'target_period_number': targetPeriodNumber,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
    };
  }
}

class TimetableMoveResponseDto {
  final TimetableDto movedSlot;
  final TimetableDto? swappedSlot;
  final String message;

  const TimetableMoveResponseDto({
    required this.movedSlot,
    this.swappedSlot,
    required this.message,
  });

  factory TimetableMoveResponseDto.fromJson(Map<String, dynamic> json) {
    return TimetableMoveResponseDto(
      movedSlot: TimetableDto.fromJson(Map<String, dynamic>.from(json['moved_slot'] as Map)),
      swappedSlot: json['swapped_slot'] != null
          ? TimetableDto.fromJson(Map<String, dynamic>.from(json['swapped_slot'] as Map))
          : null,
      message: json['message'] as String? ?? 'Slot moved successfully.',
    );
  }
}


