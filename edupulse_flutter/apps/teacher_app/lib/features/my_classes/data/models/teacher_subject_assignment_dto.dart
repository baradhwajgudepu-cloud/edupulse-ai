import 'package:freezed_annotation/freezed_annotation.dart';

part 'teacher_subject_assignment_dto.freezed.dart';
part 'teacher_subject_assignment_dto.g.dart';

@freezed
class TeacherSubjectAssignmentDto with _$TeacherSubjectAssignmentDto {
  const factory TeacherSubjectAssignmentDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'teacher_id') required String teacherId,
    @JsonKey(name: 'subject_id') required String subjectId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'assignment_type') required String assignmentType,
    required int priority,
    @JsonKey(name: 'weekly_periods') required int weeklyPeriods,
    @JsonKey(name: 'is_class_teacher') required bool isClassTeacher,
    @JsonKey(name: 'is_active') required bool isActive,
    required String status,
  }) = _TeacherSubjectAssignmentDto;

  factory TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic> json) =>
      _$TeacherSubjectAssignmentDtoFromJson(json);
}
