import 'package:freezed_annotation/freezed_annotation.dart';

part 'outstanding_class_dto.freezed.dart';
part 'outstanding_class_dto.g.dart';

@freezed
class OutstandingClassDto with _$OutstandingClassDto {
  const factory OutstandingClassDto({
    @JsonKey(name: 'class_name') required String className,
    @JsonKey(name: 'outstanding_amount') required double outstandingAmount,
  }) = _OutstandingClassDto;

  factory OutstandingClassDto.fromJson(Map<String, dynamic> json) =>
      _$OutstandingClassDtoFromJson(json);
}
