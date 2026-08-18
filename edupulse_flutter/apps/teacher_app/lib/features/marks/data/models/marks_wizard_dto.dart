import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/marks_wizard_entity.dart';
import 'marks_dto.dart';

part 'marks_wizard_dto.freezed.dart';
part 'marks_wizard_dto.g.dart';

@freezed
class StudentShortInfoDto with _$StudentShortInfoDto {
  const factory StudentShortInfoDto({
    required String id,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'roll_number') required String rollNumber,
  }) = _StudentShortInfoDto;

  const StudentShortInfoDto._();

  factory StudentShortInfoDto.fromJson(Map<String, dynamic> json) =>
      _$StudentShortInfoDtoFromJson(json);

  StudentShortInfoEntity toEntity() {
    return StudentShortInfoEntity(
      id: id,
      firstName: firstName,
      lastName: lastName,
      rollNumber: rollNumber,
    );
  }
}

@freezed
class MarkWizardItemDto with _$MarkWizardItemDto {
  const factory MarkWizardItemDto({
    required StudentShortInfoDto student,
    @JsonKey(name: 'mark_record') MarksDto? markRecord,
    @JsonKey(name: 'is_missing') required bool isMissing,
  }) = _MarkWizardItemDto;

  const MarkWizardItemDto._();

  factory MarkWizardItemDto.fromJson(Map<String, dynamic> json) =>
      _$MarkWizardItemDtoFromJson(json);

  MarkWizardItemEntity toEntity() {
    return MarkWizardItemEntity(
      student: student.toEntity(),
      markRecord: markRecord?.toEntity(),
      isMissing: isMissing,
    );
  }
}

@freezed
class MarksWizardDto with _$MarksWizardDto {
  const factory MarksWizardDto({
    @JsonKey(name: 'total_students') required int totalStudents,
    @JsonKey(name: 'entered_count') required int enteredCount,
    @JsonKey(name: 'missing_count') required int missingCount,
    @JsonKey(name: 'average_score') double? averageScore,
    @JsonKey(name: 'highest_score') double? highestScore,
    @JsonKey(name: 'lowest_score') double? lowestScore,
    @JsonKey(name: 'missing_students') required List<StudentShortInfoDto> missingStudents,
    required List<MarkWizardItemDto> entries,
  }) = _MarksWizardDto;

  const MarksWizardDto._();

  factory MarksWizardDto.fromJson(Map<String, dynamic> json) =>
      _$MarksWizardDtoFromJson(json);

  MarksWizardEntity toEntity() {
    return MarksWizardEntity(
      totalStudents: totalStudents,
      enteredCount: enteredCount,
      missingCount: missingCount,
      averageScore: averageScore,
      highestScore: highestScore,
      lowestScore: lowestScore,
      missingStudents: missingStudents.map((s) => s.toEntity()).toList(),
      entries: entries.map((e) => e.toEntity()).toList(),
    );
  }
}
