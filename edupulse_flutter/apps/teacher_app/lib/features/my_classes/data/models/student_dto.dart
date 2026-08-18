import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_dto.freezed.dart';
part 'student_dto.g.dart';

@freezed
class StudentDto with _$StudentDto {
  const factory StudentDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'middle_name') String? middleName,
    @JsonKey(name: 'last_name') required String lastName,
    required String gender,
    @JsonKey(name: 'date_of_birth') required String dateOfBirth,
    @JsonKey(name: 'blood_group') String? bloodGroup,
    String? mobile,
    String? email,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @JsonKey(name: 'admission_number') required String admissionNumber,
    @JsonKey(name: 'roll_number') required String rollNumber,
    required String status,
    @JsonKey(name: 'class_name') String? className,
    @JsonKey(name: 'section_name') String? sectionName,
  }) = _StudentDto;

  factory StudentDto.fromJson(Map<String, dynamic> json) =>
      _$StudentDtoFromJson(json);
}
