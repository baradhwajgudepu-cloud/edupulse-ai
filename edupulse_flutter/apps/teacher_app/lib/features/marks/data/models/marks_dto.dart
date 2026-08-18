import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/student_mark_entity.dart';

part 'marks_dto.freezed.dart';
part 'marks_dto.g.dart';

@freezed
class MarksDto with _$MarksDto {
  const factory MarksDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'examination_id') required String examinationId,
    @JsonKey(name: 'exam_schedule_id') required String examScheduleId,
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'teacher_subject_assignment_id') required String teacherSubjectAssignmentId,
    @JsonKey(name: 'teacher_id') required String teacherId,
    @JsonKey(name: 'subject_id') required String subjectId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'maximum_marks') required int maximumMarks,
    @JsonKey(name: 'marks_obtained') double? marksObtained,
    @JsonKey(name: 'result_status') required String resultStatus,
    required String status,
    String? grade,
    String? remarks,
    required Map<String, dynamic> settings,
    @JsonKey(name: 'ai_metrics') required Map<String, dynamic> aiMetrics,
    @JsonKey(name: 'audit_history') required List<dynamic> auditHistory,
    @JsonKey(name: 'is_active') required bool isActive,
    required int version,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _MarksDto;

  const MarksDto._();

  factory MarksDto.fromJson(Map<String, dynamic> json) =>
      _$MarksDtoFromJson(json);

  StudentMarkEntity toEntity() {
    final resultEnum = ExamResult.values.firstWhere(
      (e) => e.name == resultStatus,
      orElse: () => ExamResult.PRESENT,
    );

    final statusEnum = MarksStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => MarksStatus.DRAFT,
    );

    return StudentMarkEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      examinationId: examinationId,
      examScheduleId: examScheduleId,
      studentId: studentId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      teacherId: teacherId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      maximumMarks: maximumMarks,
      marksObtained: marksObtained,
      resultStatus: resultEnum,
      status: statusEnum,
      grade: grade,
      remarks: remarks,
      settings: settings,
      aiMetrics: aiMetrics,
      auditHistory: auditHistory,
      isActive: isActive,
      version: version,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}
