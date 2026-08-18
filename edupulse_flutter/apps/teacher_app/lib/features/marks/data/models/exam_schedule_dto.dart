import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/exam_schedule_entity.dart';

part 'exam_schedule_dto.freezed.dart';
part 'exam_schedule_dto.g.dart';

@freezed
class ExamScheduleDto with _$ExamScheduleDto {
  const factory ExamScheduleDto({
    required String id,
    @JsonKey(name: 'exam_id') required String examId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'subject_id') required String subjectId,
    @JsonKey(name: 'teacher_subject_assignment_id') required String teacherSubjectAssignmentId,
    @JsonKey(name: 'exam_date') required String examDate,
    @JsonKey(name: 'start_time') required String startTime,
    @JsonKey(name: 'end_time') required String endTime,
    @JsonKey(name: 'max_marks') required int maxMarks,
    @JsonKey(name: 'pass_marks') required int passMarks,
    @JsonKey(name: 'room_number') String? roomNumber,
    @JsonKey(name: 'is_active') required bool isActive,
    required int version,
  }) = _ExamScheduleDto;

  const ExamScheduleDto._();

  factory ExamScheduleDto.fromJson(Map<String, dynamic> json) =>
      _$ExamScheduleDtoFromJson(json);

  ExamScheduleEntity toEntity() {
    return ExamScheduleEntity(
      id: id,
      examId: examId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      examDate: DateTime.parse(examDate),
      startTime: startTime,
      endTime: endTime,
      maxMarks: maxMarks,
      passMarks: passMarks,
      roomNumber: roomNumber,
      isActive: isActive,
      version: version,
    );
  }
}
