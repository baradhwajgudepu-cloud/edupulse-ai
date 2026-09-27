import 'package:flutter/material.dart';

enum ExamStatusEnum {
  draft('DRAFT', 'Draft', Colors.grey),
  scheduled('SCHEDULED', 'Scheduled', Colors.blue),
  ongoing('ONGOING', 'Ongoing', Colors.amber),
  marksEntry('MARKS_ENTRY', 'Marks Entry', Colors.purple),
  underReview('UNDER_REVIEW', 'Under Review', Colors.orange),
  approved('APPROVED', 'Approved', Colors.teal),
  published('PUBLISHED', 'Published', Colors.green),
  locked('LOCKED', 'Locked', Colors.blueGrey),
  completed('COMPLETED', 'Completed', Colors.indigo),
  archived('ARCHIVED', 'Archived', Colors.brown);

  final String code;
  final String label;
  final Color color;

  const ExamStatusEnum(this.code, this.label, this.color);

  static ExamStatusEnum fromString(String? code) {
    if (code == null) return ExamStatusEnum.draft;
    final normalized = code.toUpperCase().trim();
    for (final status in ExamStatusEnum.values) {
      if (status.code == normalized) return status;
    }
    return ExamStatusEnum.draft;
  }

  List<ExamStatusEnum> get allowedNextStatuses {
    switch (this) {
      case ExamStatusEnum.draft:
        return [ExamStatusEnum.scheduled];
      case ExamStatusEnum.scheduled:
        return [ExamStatusEnum.draft, ExamStatusEnum.ongoing];
      case ExamStatusEnum.ongoing:
        return [ExamStatusEnum.marksEntry];
      case ExamStatusEnum.marksEntry:
        return [ExamStatusEnum.underReview];
      case ExamStatusEnum.underReview:
        return [ExamStatusEnum.marksEntry, ExamStatusEnum.approved];
      case ExamStatusEnum.approved:
        return [ExamStatusEnum.published];
      case ExamStatusEnum.published:
        return [ExamStatusEnum.completed];
      case ExamStatusEnum.completed:
        return [ExamStatusEnum.archived];
      case ExamStatusEnum.archived:
      case ExamStatusEnum.locked:
        return [];
    }
  }
}

enum ExamTypeCategoryEnum {
  scholastic('SCHOLASTIC', 'Scholastic'),
  coScholastic('CO_SCHOLASTIC', 'Co-Scholastic'),
  competitive('COMPETITIVE', 'Competitive'),
  practical('PRACTICAL', 'Practical'),
  internalAssessment('INTERNAL_ASSESSMENT', 'Internal Assessment'),
  other('OTHER', 'Other');

  final String code;
  final String label;

  const ExamTypeCategoryEnum(this.code, this.label);

  static ExamTypeCategoryEnum fromString(String? code) {
    if (code == null) return ExamTypeCategoryEnum.scholastic;
    final normalized = code.toUpperCase().trim();
    for (final category in ExamTypeCategoryEnum.values) {
      if (category.code == normalized) return category;
    }
    return ExamTypeCategoryEnum.scholastic;
  }
}

class ExamTypeMasterModel {
  final String id;
  final String tenantId;
  final String? schoolId;
  final String name;
  final String code;
  final String? description;
  final ExamTypeCategoryEnum category;
  final double defaultWeightage;
  final bool isSystem;
  final bool isActive;
  final int version;

  const ExamTypeMasterModel({
    required this.id,
    required this.tenantId,
    this.schoolId,
    required this.name,
    required this.code,
    this.description,
    required this.category,
    required this.defaultWeightage,
    required this.isSystem,
    required this.isActive,
    required this.version,
  });

  factory ExamTypeMasterModel.fromJson(Map<String, dynamic> json) {
    return ExamTypeMasterModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      category: ExamTypeCategoryEnum.fromString(json['category']?.toString()),
      defaultWeightage: (json['default_weightage'] as num?)?.toDouble() ?? 100.0,
      isSystem: json['is_system'] == true,
      isActive: json['is_active'] != false,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'name': name,
      'code': code,
      'description': description,
      'category': category.code,
      'default_weightage': defaultWeightage,
      'is_system': isSystem,
      'is_active': isActive,
    };
  }
}

class ExamPaperClassModel {
  final String id;
  final String examinationId;
  final String paperId;
  final String classId;
  final String? className;
  final int? maximumMarks;
  final int? passMarks;
  final int? durationMinutes;
  final bool isActive;

  const ExamPaperClassModel({
    required this.id,
    required this.examinationId,
    required this.paperId,
    required this.classId,
    this.className,
    this.maximumMarks,
    this.passMarks,
    this.durationMinutes,
    required this.isActive,
  });

  factory ExamPaperClassModel.fromJson(Map<String, dynamic> json) {
    return ExamPaperClassModel(
      id: json['id']?.toString() ?? '',
      examinationId: json['examination_id']?.toString() ?? '',
      paperId: json['paper_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? json['class_obj']?['name']?.toString(),
      maximumMarks: (json['maximum_marks'] as num?)?.toInt(),
      passMarks: (json['pass_marks'] as num?)?.toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'maximum_marks': maximumMarks,
      'pass_marks': passMarks,
      'duration_minutes': durationMinutes,
    };
  }
}

class ExamPaperModel {
  final String id;
  final String examinationId;
  final String subjectId;
  final String? subjectName;
  final String? subjectCode;
  final String paperName;
  final String? paperCode;
  final int defaultMaxMarks;
  final int defaultPassMarks;
  final int defaultDurationMinutes;
  final int orderIndex;
  final bool isActive;
  final List<ExamPaperClassModel> classConfigs;

  const ExamPaperModel({
    required this.id,
    required this.examinationId,
    required this.subjectId,
    this.subjectName,
    this.subjectCode,
    required this.paperName,
    this.paperCode,
    this.defaultMaxMarks = 100,
    this.defaultPassMarks = 35,
    this.defaultDurationMinutes = 180,
    this.orderIndex = 0,
    this.isActive = true,
    this.classConfigs = const [],
  });

  factory ExamPaperModel.fromJson(Map<String, dynamic> json) {
    final rawConfigs = json['class_configs'] as List<dynamic>? ?? [];
    return ExamPaperModel(
      id: json['id']?.toString() ?? '',
      examinationId: json['examination_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? json['subject']?['subject_name']?.toString(),
      subjectCode: json['subject_code']?.toString() ?? json['subject']?['subject_code']?.toString(),
      paperName: json['paper_name']?.toString() ?? '',
      paperCode: json['paper_code']?.toString(),
      defaultMaxMarks: (json['default_max_marks'] as num?)?.toInt() ?? 100,
      defaultPassMarks: (json['default_pass_marks'] as num?)?.toInt() ?? 35,
      defaultDurationMinutes: (json['default_duration_minutes'] as num?)?.toInt() ?? 180,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] != false,
      classConfigs: rawConfigs.map((c) => ExamPaperClassModel.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'paper_name': paperName,
      'paper_code': paperCode,
      'default_max_marks': defaultMaxMarks,
      'default_pass_marks': defaultPassMarks,
      'default_duration_minutes': defaultDurationMinutes,
      'order_index': orderIndex,
      'class_configs': classConfigs.map((c) => c.toJson()).toList(),
    };
  }

  int maxMarksForClass(String classId) {
    for (final cfg in classConfigs) {
      if (cfg.classId == classId && cfg.maximumMarks != null) {
        return cfg.maximumMarks!;
      }
    }
    return defaultMaxMarks;
  }

  int passMarksForClass(String classId) {
    for (final cfg in classConfigs) {
      if (cfg.classId == classId && cfg.passMarks != null) {
        return cfg.passMarks!;
      }
    }
    return defaultPassMarks;
  }

  int durationForClass(String classId) {
    for (final cfg in classConfigs) {
      if (cfg.classId == classId && cfg.durationMinutes != null) {
        return cfg.durationMinutes!;
      }
    }
    return defaultDurationMinutes;
  }

  ExamPaperClassModel? configForClass(String classId) {
    for (final cfg in classConfigs) {
      if (cfg.classId == classId) {
        return cfg;
      }
    }
    return null;
  }
}

class ExamScheduleModel {
  final String id;
  final String examId;
  final String? paperId;
  final String? paperName;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String? teacherSubjectAssignmentId;
  final String? className;
  final String? sectionName;
  final String? subjectName;
  final String? subjectCode;
  final String examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;
  final String? roomNumber;
  final bool isActive;
  final int version;

  const ExamScheduleModel({
    required this.id,
    required this.examId,
    this.paperId,
    this.paperName,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    this.teacherSubjectAssignmentId,
    this.className,
    this.sectionName,
    this.subjectName,
    this.subjectCode,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
    this.roomNumber,
    required this.isActive,
    required this.version,
  });

  factory ExamScheduleModel.fromJson(Map<String, dynamic> json) {
    return ExamScheduleModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      paperId: json['paper_id']?.toString(),
      paperName: json['paper_name']?.toString() ?? json['paper']?['paper_name']?.toString(),
      classId: json['class_id']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id']?.toString(),
      className: json['class_obj']?['name']?.toString() ?? json['class_name']?.toString(),
      sectionName: json['section']?['name']?.toString() ?? json['section_name']?.toString(),
      subjectName: json['subject']?['subject_name']?.toString() ?? json['subject_name']?.toString(),
      subjectCode: json['subject']?['subject_code']?.toString() ?? json['subject_code']?.toString(),
      examDate: json['exam_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? 100,
      passMarks: (json['pass_marks'] as num?)?.toInt() ?? 35,
      roomNumber: json['room_number']?.toString(),
      isActive: json['is_active'] != false,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paper_id': paperId,
      'class_id': classId,
      'section_id': sectionId,
      'subject_id': subjectId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'exam_date': examDate,
      'start_time': startTime,
      'end_time': endTime,
      'max_marks': maxMarks,
      'pass_marks': passMarks,
      'room_number': roomNumber,
    };
  }
}

class ExaminationModel {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String examName;
  final String examType;
  final String startDate;
  final String endDate;
  final ExamStatusEnum status;
  final String? description;
  final List<String> participatingClassIds;
  final List<String> participatingClassNames;
  final String? classesRangeFormatted;
  final int totalPapersCount;
  final int totalSchedulesCount;
  final List<ExamPaperModel> papers;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final bool isActive;
  final int version;
  final List<ExamScheduleModel> schedules;

  const ExaminationModel({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.examName,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    this.participatingClassIds = const [],
    this.participatingClassNames = const [],
    this.classesRangeFormatted,
    this.totalPapersCount = 0,
    this.totalSchedulesCount = 0,
    this.papers = const [],
    this.settings = const {},
    this.aiMetrics = const {},
    this.isActive = true,
    this.version = 1,
    this.schedules = const [],
  });

  factory ExaminationModel.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['schedules'] as List<dynamic>? ?? [];
    final rawClassIds = json['participating_class_ids'] as List<dynamic>? ?? [];
    final rawClassNames = json['participating_class_names'] as List<dynamic>? ?? [];
    final rawPapers = json['papers'] as List<dynamic>? ?? [];

    return ExaminationModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      academicYearId: json['academic_year_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? '',
      examType: json['exam_type']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      status: ExamStatusEnum.fromString(json['status']?.toString()),
      description: json['description']?.toString(),
      participatingClassIds: rawClassIds.map((e) => e.toString()).toList(),
      participatingClassNames: rawClassNames.map((e) => e.toString()).toList(),
      classesRangeFormatted: json['classes_range_formatted']?.toString(),
      totalPapersCount: (json['total_papers_count'] as num?)?.toInt() ?? rawPapers.length,
      totalSchedulesCount: (json['total_schedules_count'] as num?)?.toInt() ?? rawSchedules.length,
      papers: rawPapers.map((p) => ExamPaperModel.fromJson(p as Map<String, dynamic>)).toList(),
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      aiMetrics: (json['ai_metrics'] as Map<String, dynamic>?) ?? {},
      isActive: json['is_active'] != false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      schedules: rawSchedules.map((s) => ExamScheduleModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  /// Returns the configured exam code if present in settings.
  String? get examCode => (settings['exam_code'] ?? settings['code'])?.toString();

  /// Effective class scope: participating_class_ids UNION schedule.class_id
  Set<String> get effectiveClassIds {
    final ids = Set<String>.from(participatingClassIds);
    for (final s in schedules) {
      if (s.classId.isNotEmpty) {
        ids.add(s.classId);
      }
    }
    return ids;
  }

  /// Whether this examination represents a consolidated institutional examination cycle.
  bool get isCycleModel => participatingClassIds.isNotEmpty || papers.isNotEmpty || totalPapersCount > 0;

  /// Total count of examination papers configured for this cycle.
  int get papersCount => totalPapersCount > 0 ? totalPapersCount : papers.length;

  /// Total count of scheduled examination slots for this cycle.
  int get schedulesCount => totalSchedulesCount > 0 ? totalSchedulesCount : schedules.length;

  /// Formats a human-readable class scope string using optional class name mapping.
  String formatClassScope(Map<String, String>? classIdToName) {
    if (classesRangeFormatted != null && classesRangeFormatted!.isNotEmpty) {
      return classesRangeFormatted!;
    }
    final ids = effectiveClassIds;
    if (ids.isEmpty) return 'All Classes';
    if (ids.length == 1) {
      final cid = ids.first;
      return classIdToName?[cid] ?? 'Class $cid';
    }

    final names = participatingClassNames.isNotEmpty
        ? participatingClassNames
        : (classIdToName != null ? ids.map((id) => classIdToName[id] ?? id).toList() : <String>[]);
    if (names.isNotEmpty) {
      final numbers = <int>[];
      bool allNumbered = true;
      for (final n in names) {
        final match = RegExp(r'(\d+)').firstMatch(n);
        if (match != null) {
          numbers.add(int.parse(match.group(1)!));
        } else {
          allNumbered = false;
        }
      }
      if (allNumbered && numbers.length == names.length) {
        numbers.sort();
        return 'Classes ${numbers.first}–${numbers.last}';
      }
      if (names.length <= 2) {
        return names.join(', ');
      }
    }
    return '${ids.length} Classes';
  }

  /// Reusable dropdown disambiguation helper:
  /// e.g. "Quarterly Examination 2026 · Classes 5–10 · 6 papers"
  String getDisambiguatedTitle({Map<String, String>? classIdToName, int? explicitScheduleCount}) {
    final parts = <String>[examName];

    // 1. Class scope
    final scopeStr = formatClassScope(classIdToName);
    parts.add(scopeStr);

    // 2. Paper / Schedule count
    final paperCount = totalPapersCount > 0 ? totalPapersCount : papers.length;
    if (paperCount > 0) {
      parts.add(paperCount == 1 ? '1 paper' : '$paperCount papers');
    } else {
      final count = explicitScheduleCount ?? (totalSchedulesCount > 0 ? totalSchedulesCount : schedules.length);
      if (count == 1) {
        parts.add('1 slot');
      } else if (count > 1) {
        parts.add('$count slots');
      }
    }

    // 3. Exam Code
    final code = examCode;
    if (code != null && code.isNotEmpty) {
      parts.add(code);
    }

    return parts.join(' · ');
  }
}

class BulkTimetablePreviewItemModel {
  final String? paperId;
  final String? paperName;
  final String? sessionName;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String? teacherSubjectAssignmentId;
  final String examDate;
  final String? dayName;
  final String startTime;
  final String endTime;
  final int? durationMinutes;
  final int maxMarks;
  final int passMarks;
  final String? roomNumber;
  final String? conflictStatus;

  const BulkTimetablePreviewItemModel({
    this.paperId,
    this.paperName,
    this.sessionName,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.teacherSubjectAssignmentId,
    required this.examDate,
    this.dayName,
    required this.startTime,
    required this.endTime,
    this.durationMinutes,
    required this.maxMarks,
    required this.passMarks,
    this.roomNumber,
    this.conflictStatus,
  });

  factory BulkTimetablePreviewItemModel.fromJson(Map<String, dynamic> json) {
    return BulkTimetablePreviewItemModel(
      paperId: json['paper_id']?.toString(),
      paperName: json['paper_name']?.toString(),
      sessionName: json['session_name']?.toString(),
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString(),
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id']?.toString(),
      examDate: json['exam_date']?.toString() ?? '',
      dayName: json['day_name']?.toString(),
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? 100,
      passMarks: (json['pass_marks'] as num?)?.toInt() ?? 35,
      roomNumber: json['room_number']?.toString(),
      conflictStatus: json['conflict_status']?.toString() ?? 'OK',
    );
  }

  Map<String, dynamic> toSchedulePayload() {
    return {
      'paper_id': paperId,
      'class_id': classId,
      'section_id': sectionId,
      'subject_id': subjectId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'exam_date': examDate,
      'start_time': startTime,
      'end_time': endTime,
      'max_marks': maxMarks,
      'pass_marks': passMarks,
      'room_number': roomNumber,
    };
  }
}

class BulkTimetablePreviewResponseModel {
  final int totalSlots;
  final List<BulkTimetablePreviewItemModel> schedules;
  final List<String> warnings;
  final bool hasConflicts;
  final int conflictCount;

  const BulkTimetablePreviewResponseModel({
    required this.totalSlots,
    required this.schedules,
    this.warnings = const [],
    this.hasConflicts = false,
    this.conflictCount = 0,
  });

  factory BulkTimetablePreviewResponseModel.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['schedules'] as List<dynamic>? ?? [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];
    return BulkTimetablePreviewResponseModel(
      totalSlots: (json['total_slots'] as num?)?.toInt() ?? rawSchedules.length,
      schedules: rawSchedules.map((s) => BulkTimetablePreviewItemModel.fromJson(s as Map<String, dynamic>)).toList(),
      warnings: rawWarnings.map((w) => w.toString()).toList(),
      hasConflicts: json['has_conflicts'] == true,
      conflictCount: (json['conflict_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExamDeletionImpactModel {
  final String examId;
  final String examName;
  final String status;
  final int papersCount;
  final int resultsCount;
  final int questionPapersCount;
  final bool canDeleteDirect;
  final bool canArchive;
  final bool canPermanentDelete;
  final String warningMessage;
  final String affectedSummary;

  const ExamDeletionImpactModel({
    required this.examId,
    required this.examName,
    required this.status,
    required this.papersCount,
    required this.resultsCount,
    required this.questionPapersCount,
    required this.canDeleteDirect,
    required this.canArchive,
    required this.canPermanentDelete,
    required this.warningMessage,
    required this.affectedSummary,
  });

  factory ExamDeletionImpactModel.fromJson(Map<String, dynamic> json) {
    return ExamDeletionImpactModel(
      examId: json['exam_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      papersCount: (json['papers_count'] as num?)?.toInt() ?? 0,
      resultsCount: (json['results_count'] as num?)?.toInt() ?? 0,
      questionPapersCount: (json['question_papers_count'] as num?)?.toInt() ?? 0,
      canDeleteDirect: json['can_delete_direct'] == true,
      canArchive: json['can_archive'] == true,
      canPermanentDelete: json['can_permanent_delete'] == true,
      warningMessage: json['warning_message']?.toString() ?? '',
      affectedSummary: json['affected_summary']?.toString() ?? '',
    );
  }
}

class ExtractedQuestionItemModel {
  final String? id;
  String questionNumber;
  String? parentQuestionId;
  String sectionName;
  int sequenceOrder;
  String? questionText;
  double maxMarks;
  String questionType;
  String difficulty;
  String? chapterName;
  String? topicName;
  String? syllabusId;
  double? extractionConfidence;
  double? mappingConfidence;
  String? mappingSource;
  String reviewStatus;
  List<ExtractedQuestionItemModel> subQuestions;

  ExtractedQuestionItemModel({
    this.id,
    required this.questionNumber,
    this.parentQuestionId,
    this.sectionName = 'Section A',
    this.sequenceOrder = 1,
    this.questionText,
    this.maxMarks = 5.0,
    this.questionType = 'SHORT',
    this.difficulty = 'MEDIUM',
    this.chapterName,
    this.topicName,
    this.syllabusId,
    this.extractionConfidence,
    this.mappingConfidence,
    this.mappingSource,
    this.reviewStatus = 'PENDING',
    this.subQuestions = const [],
  });

  factory ExtractedQuestionItemModel.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['sub_questions'] as List<dynamic>? ?? [];
    return ExtractedQuestionItemModel(
      id: json['id']?.toString(),
      questionNumber: json['question_number']?.toString() ?? 'Q1',
      parentQuestionId: json['parent_question_id']?.toString(),
      sectionName: json['section_name']?.toString() ?? 'Section A',
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 1,
      questionText: json['question_text']?.toString(),
      maxMarks: (json['max_marks'] as num?)?.toDouble() ?? 5.0,
      questionType: json['question_type']?.toString() ?? 'SHORT',
      difficulty: json['difficulty']?.toString() ?? 'MEDIUM',
      chapterName: json['chapter_name']?.toString(),
      topicName: json['topic_name']?.toString(),
      syllabusId: json['syllabus_id']?.toString(),
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble(),
      mappingConfidence: (json['mapping_confidence'] as num?)?.toDouble(),
      mappingSource: json['mapping_source']?.toString(),
      reviewStatus: json['review_status']?.toString() ?? 'PENDING',
      subQuestions: rawSubs.map((s) => ExtractedQuestionItemModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'question_number': questionNumber,
      if (parentQuestionId != null) 'parent_question_id': parentQuestionId,
      'section_name': sectionName,
      'sequence_order': sequenceOrder,
      'question_text': questionText,
      'max_marks': maxMarks,
      'question_type': questionType,
      'difficulty': difficulty,
      'chapter_name': chapterName,
      'topic_name': topicName,
      if (syllabusId != null) 'syllabus_id': syllabusId,
      'extraction_confidence': extractionConfidence,
      'mapping_confidence': mappingConfidence,
      'mapping_source': mappingSource,
      'review_status': reviewStatus,
      'sub_questions': subQuestions.map((s) => s.toJson()).toList(),
    };
  }
}

class QuestionPaperModel {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String examinationId;
  final String paperId;
  final String title;
  final double totalMarks;
  final int totalQuestions;
  final int sectionsCount;
  final String? sourceFileName;
  final String? sourceFileType;
  final String processingStatus;
  final String verificationStatus;
  final String? verifiedBy;
  final String? verifiedAt;
  final Map<String, dynamic> aiExtractionMetadata;
  final Map<String, dynamic> syllabusCoverageMetrics;
  final List<ExtractedQuestionItemModel> questions;

  const QuestionPaperModel({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.examinationId,
    required this.paperId,
    required this.title,
    required this.totalMarks,
    required this.totalQuestions,
    required this.sectionsCount,
    this.sourceFileName,
    this.sourceFileType,
    required this.processingStatus,
    required this.verificationStatus,
    this.verifiedBy,
    this.verifiedAt,
    this.aiExtractionMetadata = const {},
    this.syllabusCoverageMetrics = const {},
    this.questions = const [],
  });

  factory QuestionPaperModel.fromJson(Map<String, dynamic> json) {
    final rawQ = json['questions'] as List<dynamic>? ?? [];
    return QuestionPaperModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      academicYearId: json['academic_year_id']?.toString() ?? '',
      examinationId: json['examination_id']?.toString() ?? '',
      paperId: json['paper_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Question Paper',
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 100.0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? 1,
      sourceFileName: json['source_file_name']?.toString(),
      sourceFileType: json['source_file_type']?.toString(),
      processingStatus: json['processing_status']?.toString() ?? 'EXTRACTED',
      verificationStatus: json['verification_status']?.toString() ?? 'PENDING_REVIEW',
      verifiedBy: json['verified_by']?.toString(),
      verifiedAt: json['verified_at']?.toString(),
      aiExtractionMetadata: json['ai_extraction_metadata'] as Map<String, dynamic>? ?? {},
      syllabusCoverageMetrics: json['syllabus_coverage_metrics'] as Map<String, dynamic>? ?? {},
      questions: rawQ.map((q) => ExtractedQuestionItemModel.fromJson(q as Map<String, dynamic>)).toList(),
    );
  }
}

class QuestionPaperExtractionResponseModel {
  final String paperId;
  final String questionPaperId;
  final String title;
  final int detectedQuestionsCount;
  final double detectedMaximumMarks;
  final int detectedSectionsCount;
  final double overallConfidence;
  final int lowConfidenceCount;
  final String verificationStatus;
  final List<ExtractedQuestionItemModel> questions;

  const QuestionPaperExtractionResponseModel({
    required this.paperId,
    required this.questionPaperId,
    required this.title,
    required this.detectedQuestionsCount,
    required this.detectedMaximumMarks,
    required this.detectedSectionsCount,
    required this.overallConfidence,
    required this.lowConfidenceCount,
    required this.verificationStatus,
    required this.questions,
  });

  factory QuestionPaperExtractionResponseModel.fromJson(Map<String, dynamic> json) {
    final rawQ = json['questions'] as List<dynamic>? ?? [];
    return QuestionPaperExtractionResponseModel(
      paperId: json['paper_id']?.toString() ?? '',
      questionPaperId: json['question_paper_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detectedQuestionsCount: (json['detected_questions_count'] as num?)?.toInt() ?? 0,
      detectedMaximumMarks: (json['detected_maximum_marks'] as num?)?.toDouble() ?? 0.0,
      detectedSectionsCount: (json['detected_sections_count'] as num?)?.toInt() ?? 1,
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble() ?? 1.0,
      lowConfidenceCount: (json['low_confidence_count'] as num?)?.toInt() ?? 0,
      verificationStatus: json['verification_status']?.toString() ?? 'PENDING_REVIEW',
      questions: rawQ.map((q) => ExtractedQuestionItemModel.fromJson(q as Map<String, dynamic>)).toList(),
    );
  }
}

class SyllabusTopicOptionModel {
  final String syllabusId;
  final String? unitName;
  final String chapterName;
  final String topicName;
  final int estimatedPeriods;

  const SyllabusTopicOptionModel({
    required this.syllabusId,
    this.unitName,
    required this.chapterName,
    required this.topicName,
    this.estimatedPeriods = 4,
  });

  factory SyllabusTopicOptionModel.fromJson(Map<String, dynamic> json) {
    return SyllabusTopicOptionModel(
      syllabusId: json['syllabus_id']?.toString() ?? '',
      unitName: json['unit_name']?.toString(),
      chapterName: json['chapter_name']?.toString() ?? '',
      topicName: json['topic_name']?.toString() ?? '',
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 4,
    );
  }
}

class QuestionWiseStudentRowModel {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String? rollNumber;
  Map<String, double> questionMarks;
  double totalObtained;
  final double maxMarks;
  bool isComplete;
  String resultStatus;
  String? remarks;

  QuestionWiseStudentRowModel({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    this.rollNumber,
    required this.questionMarks,
    required this.totalObtained,
    required this.maxMarks,
    this.isComplete = true,
    this.resultStatus = 'PRESENT',
    this.remarks,
  });

  factory QuestionWiseStudentRowModel.fromJson(Map<String, dynamic> json) {
    final rawMarks = json['question_marks'] as Map<String, dynamic>? ?? {};
    final marksMap = <String, double>{};
    rawMarks.forEach((k, v) {
      if (v != null) {
        marksMap[k] = (v as num).toDouble();
      }
    });

    return QuestionWiseStudentRowModel(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      admissionNumber: json['admission_number']?.toString() ?? '',
      rollNumber: json['roll_number']?.toString(),
      questionMarks: marksMap,
      totalObtained: (json['total_obtained'] as num?)?.toDouble() ?? 0.0,
      maxMarks: (json['max_marks'] as num?)?.toDouble() ?? 100.0,
      isComplete: json['is_complete'] == true,
      resultStatus: json['result_status']?.toString() ?? 'PRESENT',
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'admission_number': admissionNumber,
      'roll_number': rollNumber,
      'question_marks': questionMarks,
      'total_obtained': totalObtained,
      'max_marks': maxMarks,
      'is_complete': isComplete,
      'result_status': resultStatus,
      'remarks': remarks,
    };
  }
}

class QuestionWiseMarksMatrixModel {
  final String paperId;
  final String examId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String className;
  final String sectionName;
  final String subjectName;
  final double totalMaxMarks;
  final List<ExtractedQuestionItemModel> questions;
  final List<QuestionWiseStudentRowModel> rows;
  final String mode; // TOTAL_ONLY, QUESTION_WISE

  const QuestionWiseMarksMatrixModel({
    required this.paperId,
    required this.examId,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.totalMaxMarks,
    required this.questions,
    required this.rows,
    required this.mode,
  });

  factory QuestionWiseMarksMatrixModel.fromJson(Map<String, dynamic> json) {
    final rawQ = json['questions'] as List<dynamic>? ?? [];
    final rawRows = json['rows'] as List<dynamic>? ?? [];
    return QuestionWiseMarksMatrixModel(
      paperId: json['paper_id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      totalMaxMarks: (json['total_max_marks'] as num?)?.toDouble() ?? 100.0,
      questions: rawQ.map((q) => ExtractedQuestionItemModel.fromJson(q as Map<String, dynamic>)).toList(),
      rows: rawRows.map((r) => QuestionWiseStudentRowModel.fromJson(r as Map<String, dynamic>)).toList(),
      mode: json['mode']?.toString() ?? 'QUESTION_WISE',
    );
  }
}

class QuestionWiseAnalyticsModel {
  final String paperId;
  final String examId;
  final String examName;
  final String subjectName;
  final String className;
  final int totalStudentsAssessed;
  final double classAveragePct;
  final double highestScore;
  final double lowestScore;
  final double passPercentage;
  final bool hasQuestionData;
  final String dataSufficiency;
  final String message;
  final List<Map<String, dynamic>> questionAnalytics;
  final List<Map<String, dynamic>> topicAnalytics;
  final List<Map<String, dynamic>> chapterAnalytics;
  final Map<String, dynamic> syllabusCoverage;

  const QuestionWiseAnalyticsModel({
    required this.paperId,
    required this.examId,
    required this.examName,
    required this.subjectName,
    required this.className,
    required this.totalStudentsAssessed,
    required this.classAveragePct,
    required this.highestScore,
    required this.lowestScore,
    required this.passPercentage,
    required this.hasQuestionData,
    required this.dataSufficiency,
    required this.message,
    required this.questionAnalytics,
    required this.topicAnalytics,
    required this.chapterAnalytics,
    required this.syllabusCoverage,
  });

  factory QuestionWiseAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return QuestionWiseAnalyticsModel(
      paperId: json['paper_id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      totalStudentsAssessed: (json['total_students_assessed'] as num?)?.toInt() ?? 0,
      classAveragePct: (json['class_average_pct'] as num?)?.toDouble() ?? 0.0,
      highestScore: (json['highest_score'] as num?)?.toDouble() ?? 0.0,
      lowestScore: (json['lowest_score'] as num?)?.toDouble() ?? 0.0,
      passPercentage: (json['pass_percentage'] as num?)?.toDouble() ?? 0.0,
      hasQuestionData: json['has_question_data'] == true,
      dataSufficiency: json['data_sufficiency']?.toString() ?? 'TOTAL_MARKS_ONLY',
      message: json['message']?.toString() ?? '',
      questionAnalytics: (json['question_analytics'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      topicAnalytics: (json['topic_analytics'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      chapterAnalytics: (json['chapter_analytics'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      syllabusCoverage: json['syllabus_coverage'] != null ? Map<String, dynamic>.from(json['syllabus_coverage'] as Map) : {},
    );
  }
}

