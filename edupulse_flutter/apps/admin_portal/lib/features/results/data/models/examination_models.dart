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

class ExamScheduleModel {
  final String id;
  final String examId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String? teacherSubjectAssignmentId;
  final String? className;
  final String? sectionName;
  final String? subjectName;
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
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    this.teacherSubjectAssignmentId,
    this.className,
    this.sectionName,
    this.subjectName,
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
      classId: json['class_id']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id']?.toString(),
      className: json['class_obj']?['name']?.toString() ?? json['class_name']?.toString(),
      sectionName: json['section']?['name']?.toString() ?? json['section_name']?.toString(),
      subjectName: json['subject']?['subject_name']?.toString() ?? json['subject_name']?.toString(),
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
    this.settings = const {},
    this.aiMetrics = const {},
    required this.isActive,
    required this.version,
    this.schedules = const [],
  });

  factory ExaminationModel.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['schedules'] as List<dynamic>? ?? [];
    final rawClassIds = json['participating_class_ids'] as List<dynamic>? ?? [];

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
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      aiMetrics: (json['ai_metrics'] as Map<String, dynamic>?) ?? {},
      isActive: json['is_active'] != false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      schedules: rawSchedules.map((s) => ExamScheduleModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class BulkTimetablePreviewItemModel {
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final String subjectName;
  final String? teacherSubjectAssignmentId;
  final String examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;
  final String? roomNumber;

  const BulkTimetablePreviewItemModel({
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    this.teacherSubjectAssignmentId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
    this.roomNumber,
  });

  factory BulkTimetablePreviewItemModel.fromJson(Map<String, dynamic> json) {
    return BulkTimetablePreviewItemModel(
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id']?.toString(),
      examDate: json['exam_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? 100,
      passMarks: (json['pass_marks'] as num?)?.toInt() ?? 35,
      roomNumber: json['room_number']?.toString(),
    );
  }

  Map<String, dynamic> toSchedulePayload() {
    return {
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

  const BulkTimetablePreviewResponseModel({
    required this.totalSlots,
    required this.schedules,
  });

  factory BulkTimetablePreviewResponseModel.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['schedules'] as List<dynamic>? ?? [];
    return BulkTimetablePreviewResponseModel(
      totalSlots: (json['total_slots'] as num?)?.toInt() ?? rawSchedules.length,
      schedules: rawSchedules.map((s) => BulkTimetablePreviewItemModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
