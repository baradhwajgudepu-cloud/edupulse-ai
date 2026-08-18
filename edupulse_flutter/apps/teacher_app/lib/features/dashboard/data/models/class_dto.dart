import 'package:freezed_annotation/freezed_annotation.dart';

part 'class_dto.freezed.dart';
part 'class_dto.g.dart';

@freezed
class ClassDto with _$ClassDto {
  const factory ClassDto({
    required String id,
    required String name,
    required String code,
  }) = _ClassDto;

  factory ClassDto.fromJson(Map<String, dynamic> json) =>
      _$ClassDtoFromJson(json);
}
