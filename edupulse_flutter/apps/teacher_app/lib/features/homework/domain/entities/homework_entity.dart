enum HomeworkPriority {
  LOW,
  NORMAL,
  HIGH,
}

enum HomeworkStatus {
  DRAFT,
  PUBLISHED,
  ARCHIVED,
}

class HomeworkEntity {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String teacherId;
  final String teacherSubjectAssignmentId;
  final String subjectId;
  final String classId;
  final String sectionId;
  final String? timetableId;
  final String title;
  final String description;
  final DateTime dueDate;
  final HomeworkPriority priority;
  final HomeworkStatus status;
  final String? attachmentUrl;
  final int? estimatedMinutes;
  final bool isActive;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HomeworkEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.teacherId,
    required this.teacherSubjectAssignmentId,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
    this.timetableId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.attachmentUrl,
    this.estimatedMinutes,
    required this.isActive,
    required this.settings,
    required this.aiMetrics,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  HomeworkEntity copyWith({
    String? id,
    String? tenantId,
    String? schoolId,
    String? academicYearId,
    String? teacherId,
    String? teacherSubjectAssignmentId,
    String? subjectId,
    String? classId,
    String? sectionId,
    String? Function()? timetableId,
    String? title,
    String? description,
    DateTime? dueDate,
    HomeworkPriority? priority,
    HomeworkStatus? status,
    String? Function()? attachmentUrl,
    int? Function()? estimatedMinutes,
    bool? isActive,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? aiMetrics,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HomeworkEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      teacherId: teacherId ?? this.teacherId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId ?? this.teacherSubjectAssignmentId,
      subjectId: subjectId ?? this.subjectId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      timetableId: timetableId != null ? timetableId() : this.timetableId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attachmentUrl: attachmentUrl != null ? attachmentUrl() : this.attachmentUrl,
      estimatedMinutes: estimatedMinutes != null ? estimatedMinutes() : this.estimatedMinutes,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
      aiMetrics: aiMetrics ?? this.aiMetrics,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
