import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/examination_entity.dart';
import 'exam_schedule_dto.dart';

part 'examination_dto.freezed.dart';
part 'examination_dto.g.dart';

@freezed
class ExaminationDto with _$ExaminationDto {
  const factory ExaminationDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'exam_name') required String examName,
    @JsonKey(name: 'exam_type') required String examType,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    required String status,
    String? description,
    required Map<String, dynamic> settings,
    @JsonKey(name: 'ai_metrics') required Map<String, dynamic> aiMetrics,
    @JsonKey(name: 'is_active') required bool isActive,
    required int version,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
    @Default([]) List<ExamScheduleDto> schedules,
  }) = _ExaminationDto;

  const ExaminationDto._();

  factory ExaminationDto.fromJson(Map<String, dynamic> json) =>
      _$ExaminationDtoFromJson(json);

  ExaminationEntity toEntity() {
    final typeEnum = ExamType.values.firstWhere(
      (e) => e.name == examType,
      orElse: () => ExamType.UNIT_TEST,
    );

    final statusEnum = ExamStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ExamStatus.DRAFT,
    );

    return ExaminationEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      examName: examName,
      examType: typeEnum,
      startDate: DateTime.parse(startDate),
      endDate: DateTime.parse(endDate),
      status: statusEnum,
      description: description,
      settings: settings,
      aiMetrics: aiMetrics,
      isActive: isActive,
      version: version,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      schedules: schedules.map((s) => s.toEntity()).toList(),
    );
  }
}
