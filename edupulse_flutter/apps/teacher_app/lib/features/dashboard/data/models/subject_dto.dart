import 'package:freezed_annotation/freezed_annotation.dart';

part 'subject_dto.freezed.dart';
part 'subject_dto.g.dart';

@freezed
class SubjectDto with _$SubjectDto {
  const factory SubjectDto({
    required String id,
    @JsonKey(name: 'subject_name') required String subjectName,
    @JsonKey(name: 'subject_code') required String subjectCode,
    @JsonKey(name: 'short_name') String? shortName,
    @JsonKey(name: 'display_color') String? displayColor,
  }) = _SubjectDto;

  factory SubjectDto.fromJson(Map<String, dynamic> json) =>
      _$SubjectDtoFromJson(json);
}
