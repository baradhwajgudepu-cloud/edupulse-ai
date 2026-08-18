import 'package:freezed_annotation/freezed_annotation.dart';

part 'section_dto.freezed.dart';
part 'section_dto.g.dart';

@freezed
class SectionDto with _$SectionDto {
  const factory SectionDto({
    required String id,
    required String name,
    required String code,
    @JsonKey(name: 'class_id') required String classId,
  }) = _SectionDto;

  factory SectionDto.fromJson(Map<String, dynamic> json) =>
      _$SectionDtoFromJson(json);
}
