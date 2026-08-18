// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeacherProfileDtoImpl _$$TeacherProfileDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$TeacherProfileDtoImpl(
      id: json['id'] as String,
      employeeCode: json['employee_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      officialEmail: json['official_email'] as String,
      mobile: json['mobile'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$$TeacherProfileDtoImplToJson(
        _$TeacherProfileDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'employee_code': instance.employeeCode,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'designation': instance.designation,
      'department': instance.department,
      'official_email': instance.officialEmail,
      'mobile': instance.mobile,
      'status': instance.status,
    };
