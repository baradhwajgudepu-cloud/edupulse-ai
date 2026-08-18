import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/homework_entity.dart';

part 'homework_dto.freezed.dart';
part 'homework_dto.g.dart';

@freezed
class HomeworkDto with _$HomeworkDto {
  const factory HomeworkDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'teacher_id') required String teacherId,
    @JsonKey(name: 'teacher_subject_assignment_id') required String teacherSubjectAssignmentId,
    @JsonKey(name: 'subject_id') required String subjectId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'timetable_id') String? timetableId,
    required String title,
    required String description,
    @JsonKey(name: 'due_date') required String dueDate,
    required String priority,
    required String status,
    @JsonKey(name: 'attachment_url') String? attachmentUrl,
    @JsonKey(name: 'estimated_minutes') int? estimatedMinutes,
    @JsonKey(name: 'is_active') required bool isActive,
    required Map<String, dynamic> settings,
    @JsonKey(name: 'ai_metrics') required Map<String, dynamic> aiMetrics,
    required int version,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _HomeworkDto;

  const HomeworkDto._();

  factory HomeworkDto.fromJson(Map<String, dynamic> json) =>
      _$HomeworkDtoFromJson(json);

  HomeworkEntity toEntity() {
    final priorityEnum = HomeworkPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => HomeworkPriority.NORMAL,
    );

    final statusEnum = HomeworkStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => HomeworkStatus.DRAFT,
    );

    return HomeworkEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: DateTime.parse(dueDate),
      priority: priorityEnum,
      status: statusEnum,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
      isActive: isActive,
      settings: settings,
      aiMetrics: aiMetrics,
      version: version,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}
