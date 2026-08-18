import 'package:freezed_annotation/freezed_annotation.dart';

part 'academic_year_dto.freezed.dart';
part 'academic_year_dto.g.dart';

@freezed
class AcademicYearDto with _$AcademicYearDto {
  const factory AcademicYearDto({
    required String id,
    required String name,
    required String code,
    required String status,
  }) = _AcademicYearDto;

  factory AcademicYearDto.fromJson(Map<String, dynamic> json) =>
      _$AcademicYearDtoFromJson(json);
}
