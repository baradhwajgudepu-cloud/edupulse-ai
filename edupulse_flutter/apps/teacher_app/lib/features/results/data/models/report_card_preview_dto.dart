import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/report_card_preview_entity.dart';

part 'report_card_preview_dto.freezed.dart';
part 'report_card_preview_dto.g.dart';

@freezed
class ReportCardSubjectMarkRowDto with _$ReportCardSubjectMarkRowDto {
  const factory ReportCardSubjectMarkRowDto({
    @JsonKey(name: 'subject_name') required String subjectName,
    @JsonKey(name: 'maximum_marks') required int maximumMarks,
    @JsonKey(name: 'marks_obtained') double? marksObtained,
    @JsonKey(name: 'result_status') required String resultStatus,
    required String grade,
    String? remarks,
  }) = _ReportCardSubjectMarkRowDto;

  const ReportCardSubjectMarkRowDto._();

  factory ReportCardSubjectMarkRowDto.fromJson(Map<String, dynamic> json) =>
      _$ReportCardSubjectMarkRowDtoFromJson(json);

  ReportCardSubjectMarkRowEntity toEntity() {
    return ReportCardSubjectMarkRowEntity(
      subjectName: subjectName,
      maximumMarks: maximumMarks,
      marksObtained: marksObtained,
      resultStatus: resultStatus,
      grade: grade,
      remarks: remarks,
    );
  }
}

@freezed
class ReportCardPreviewDto with _$ReportCardPreviewDto {
  const factory ReportCardPreviewDto({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'student_name') required String studentName,
    @JsonKey(name: 'admission_number') required String admissionNumber,
    @JsonKey(name: 'roll_number') required String rollNumber,
    @JsonKey(name: 'class_name') required String className,
    @JsonKey(name: 'section_name') required String sectionName,
    @JsonKey(name: 'attendance_total') required int attendanceTotal,
    @JsonKey(name: 'attendance_present') required int attendancePresent,
    @JsonKey(name: 'attendance_percentage') required double attendancePercentage,
    @JsonKey(name: 'overall_percentage') required double overallPercentage,
    @JsonKey(name: 'overall_grade') required String overallGrade,
    @JsonKey(name: 'promotion_status') required String promotionStatus,
    @JsonKey(name: 'subject_marks') required List<ReportCardSubjectMarkRowDto> subjectMarks,
    @JsonKey(name: 'teacher_remarks') String? teacherRemarks,
    @JsonKey(name: 'principal_remarks') String? principalRemarks,
    @JsonKey(name: 'ai_narrative') required String aiNarrative,
    @JsonKey(name: 'is_valid') required bool isValid,
    @JsonKey(name: 'missing_reasons') required List<String> missingReasons,
  }) = _ReportCardPreviewDto;

  const ReportCardPreviewDto._();

  factory ReportCardPreviewDto.fromJson(Map<String, dynamic> json) =>
      _$ReportCardPreviewDtoFromJson(json);

  ReportCardPreviewEntity toEntity() {
    return ReportCardPreviewEntity(
      studentId: studentId,
      studentName: studentName,
      admissionNumber: admissionNumber,
      rollNumber: rollNumber,
      className: className,
      sectionName: sectionName,
      attendanceTotal: attendanceTotal,
      attendancePresent: attendancePresent,
      attendancePercentage: attendancePercentage,
      overallPercentage: overallPercentage,
      overallGrade: overallGrade,
      promotionStatus: promotionStatus,
      subjectMarks: subjectMarks.map((e) => e.toEntity()).toList(),
      teacherRemarks: teacherRemarks,
      principalRemarks: principalRemarks,
      aiNarrative: aiNarrative,
      isValid: isValid,
      missingReasons: missingReasons,
    );
  }
}
