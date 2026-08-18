import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/bulk_class_generate_entity.dart';

part 'bulk_class_generate_dto.freezed.dart';
part 'bulk_class_generate_dto.g.dart';

@freezed
class StudentFailureDetailDto with _$StudentFailureDetailDto {
  const factory StudentFailureDetailDto({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'student_name') required String studentName,
    required List<String> reasons,
  }) = _StudentFailureDetailDto;

  const StudentFailureDetailDto._();

  factory StudentFailureDetailDto.fromJson(Map<String, dynamic> json) =>
      _$StudentFailureDetailDtoFromJson(json);

  StudentFailureDetailEntity toEntity() {
    return StudentFailureDetailEntity(
      studentId: studentId,
      studentName: studentName,
      reasons: reasons,
    );
  }
}

@freezed
class BulkClassGenerateDto with _$BulkClassGenerateDto {
  const factory BulkClassGenerateDto({
    @JsonKey(name: 'total_students') required int totalStudents,
    @JsonKey(name: 'generated_count') required int generatedCount,
    @JsonKey(name: 'failed_count') required int failedCount,
    required List<StudentFailureDetailDto> failures,
  }) = _BulkClassGenerateDto;

  const BulkClassGenerateDto._();

  factory BulkClassGenerateDto.fromJson(Map<String, dynamic> json) =>
      _$BulkClassGenerateDtoFromJson(json);

  BulkClassGenerateEntity toEntity() {
    return BulkClassGenerateEntity(
      totalStudents: totalStudents,
      generatedCount: generatedCount,
      failedCount: failedCount,
      failures: failures.map((e) => e.toEntity()).toList(),
    );
  }
}
