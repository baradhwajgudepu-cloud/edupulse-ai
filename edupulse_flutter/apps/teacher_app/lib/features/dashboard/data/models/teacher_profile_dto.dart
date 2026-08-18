import 'package:freezed_annotation/freezed_annotation.dart';

part 'teacher_profile_dto.freezed.dart';
part 'teacher_profile_dto.g.dart';

@freezed
class TeacherProfileDto with _$TeacherProfileDto {
  const factory TeacherProfileDto({
    required String id,
    @JsonKey(name: 'employee_code') required String employeeCode,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    String? designation,
    String? department,
    @JsonKey(name: 'official_email') required String officialEmail,
    required String mobile,
    required String status,
  }) = _TeacherProfileDto;

  factory TeacherProfileDto.fromJson(Map<String, dynamic> json) =>
      _$TeacherProfileDtoFromJson(json);
}
