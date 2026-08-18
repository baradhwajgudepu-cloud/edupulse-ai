// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StudentDtoImpl _$$StudentDtoImplFromJson(Map<String, dynamic> json) =>
    _$StudentDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      bloodGroup: json['blood_group'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      admissionNumber: json['admission_number'] as String,
      rollNumber: json['roll_number'] as String,
      status: json['status'] as String,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
    );

Map<String, dynamic> _$$StudentDtoImplToJson(_$StudentDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'first_name': instance.firstName,
      'middle_name': instance.middleName,
      'last_name': instance.lastName,
      'gender': instance.gender,
      'date_of_birth': instance.dateOfBirth,
      'blood_group': instance.bloodGroup,
      'mobile': instance.mobile,
      'email': instance.email,
      'photo_url': instance.photoUrl,
      'admission_number': instance.admissionNumber,
      'roll_number': instance.rollNumber,
      'status': instance.status,
      'class_name': instance.className,
      'section_name': instance.sectionName,
    };
