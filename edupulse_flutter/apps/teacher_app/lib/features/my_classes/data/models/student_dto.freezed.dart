// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'student_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StudentDto _$StudentDtoFromJson(Map<String, dynamic> json) {
  return _StudentDto.fromJson(json);
}

/// @nodoc
mixin _$StudentDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_name')
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: 'middle_name')
  String? get middleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_name')
  String get lastName => throw _privateConstructorUsedError;
  String get gender => throw _privateConstructorUsedError;
  @JsonKey(name: 'date_of_birth')
  String get dateOfBirth => throw _privateConstructorUsedError;
  @JsonKey(name: 'blood_group')
  String? get bloodGroup => throw _privateConstructorUsedError;
  String? get mobile => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'photo_url')
  String? get photoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'admission_number')
  String get admissionNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'roll_number')
  String get rollNumber => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_name')
  String? get className => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_name')
  String? get sectionName => throw _privateConstructorUsedError;

  /// Serializes this StudentDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudentDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentDtoCopyWith<StudentDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentDtoCopyWith<$Res> {
  factory $StudentDtoCopyWith(
          StudentDto value, $Res Function(StudentDto) then) =
      _$StudentDtoCopyWithImpl<$Res, StudentDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'middle_name') String? middleName,
      @JsonKey(name: 'last_name') String lastName,
      String gender,
      @JsonKey(name: 'date_of_birth') String dateOfBirth,
      @JsonKey(name: 'blood_group') String? bloodGroup,
      String? mobile,
      String? email,
      @JsonKey(name: 'photo_url') String? photoUrl,
      @JsonKey(name: 'admission_number') String admissionNumber,
      @JsonKey(name: 'roll_number') String rollNumber,
      String status,
      @JsonKey(name: 'class_name') String? className,
      @JsonKey(name: 'section_name') String? sectionName});
}

/// @nodoc
class _$StudentDtoCopyWithImpl<$Res, $Val extends StudentDto>
    implements $StudentDtoCopyWith<$Res> {
  _$StudentDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudentDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? firstName = null,
    Object? middleName = freezed,
    Object? lastName = null,
    Object? gender = null,
    Object? dateOfBirth = null,
    Object? bloodGroup = freezed,
    Object? mobile = freezed,
    Object? email = freezed,
    Object? photoUrl = freezed,
    Object? admissionNumber = null,
    Object? rollNumber = null,
    Object? status = null,
    Object? className = freezed,
    Object? sectionName = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      academicYearId: null == academicYearId
          ? _value.academicYearId
          : academicYearId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      middleName: freezed == middleName
          ? _value.middleName
          : middleName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      gender: null == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String,
      dateOfBirth: null == dateOfBirth
          ? _value.dateOfBirth
          : dateOfBirth // ignore: cast_nullable_to_non_nullable
              as String,
      bloodGroup: freezed == bloodGroup
          ? _value.bloodGroup
          : bloodGroup // ignore: cast_nullable_to_non_nullable
              as String?,
      mobile: freezed == mobile
          ? _value.mobile
          : mobile // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      admissionNumber: null == admissionNumber
          ? _value.admissionNumber
          : admissionNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      className: freezed == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String?,
      sectionName: freezed == sectionName
          ? _value.sectionName
          : sectionName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentDtoImplCopyWith<$Res>
    implements $StudentDtoCopyWith<$Res> {
  factory _$$StudentDtoImplCopyWith(
          _$StudentDtoImpl value, $Res Function(_$StudentDtoImpl) then) =
      __$$StudentDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'middle_name') String? middleName,
      @JsonKey(name: 'last_name') String lastName,
      String gender,
      @JsonKey(name: 'date_of_birth') String dateOfBirth,
      @JsonKey(name: 'blood_group') String? bloodGroup,
      String? mobile,
      String? email,
      @JsonKey(name: 'photo_url') String? photoUrl,
      @JsonKey(name: 'admission_number') String admissionNumber,
      @JsonKey(name: 'roll_number') String rollNumber,
      String status,
      @JsonKey(name: 'class_name') String? className,
      @JsonKey(name: 'section_name') String? sectionName});
}

/// @nodoc
class __$$StudentDtoImplCopyWithImpl<$Res>
    extends _$StudentDtoCopyWithImpl<$Res, _$StudentDtoImpl>
    implements _$$StudentDtoImplCopyWith<$Res> {
  __$$StudentDtoImplCopyWithImpl(
      _$StudentDtoImpl _value, $Res Function(_$StudentDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudentDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? firstName = null,
    Object? middleName = freezed,
    Object? lastName = null,
    Object? gender = null,
    Object? dateOfBirth = null,
    Object? bloodGroup = freezed,
    Object? mobile = freezed,
    Object? email = freezed,
    Object? photoUrl = freezed,
    Object? admissionNumber = null,
    Object? rollNumber = null,
    Object? status = null,
    Object? className = freezed,
    Object? sectionName = freezed,
  }) {
    return _then(_$StudentDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      academicYearId: null == academicYearId
          ? _value.academicYearId
          : academicYearId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      middleName: freezed == middleName
          ? _value.middleName
          : middleName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      gender: null == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String,
      dateOfBirth: null == dateOfBirth
          ? _value.dateOfBirth
          : dateOfBirth // ignore: cast_nullable_to_non_nullable
              as String,
      bloodGroup: freezed == bloodGroup
          ? _value.bloodGroup
          : bloodGroup // ignore: cast_nullable_to_non_nullable
              as String?,
      mobile: freezed == mobile
          ? _value.mobile
          : mobile // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      admissionNumber: null == admissionNumber
          ? _value.admissionNumber
          : admissionNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      className: freezed == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String?,
      sectionName: freezed == sectionName
          ? _value.sectionName
          : sectionName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudentDtoImpl implements _StudentDto {
  const _$StudentDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'first_name') required this.firstName,
      @JsonKey(name: 'middle_name') this.middleName,
      @JsonKey(name: 'last_name') required this.lastName,
      required this.gender,
      @JsonKey(name: 'date_of_birth') required this.dateOfBirth,
      @JsonKey(name: 'blood_group') this.bloodGroup,
      this.mobile,
      this.email,
      @JsonKey(name: 'photo_url') this.photoUrl,
      @JsonKey(name: 'admission_number') required this.admissionNumber,
      @JsonKey(name: 'roll_number') required this.rollNumber,
      required this.status,
      @JsonKey(name: 'class_name') this.className,
      @JsonKey(name: 'section_name') this.sectionName});

  factory _$StudentDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'school_id')
  final String schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  final String academicYearId;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;
  @override
  @JsonKey(name: 'first_name')
  final String firstName;
  @override
  @JsonKey(name: 'middle_name')
  final String? middleName;
  @override
  @JsonKey(name: 'last_name')
  final String lastName;
  @override
  final String gender;
  @override
  @JsonKey(name: 'date_of_birth')
  final String dateOfBirth;
  @override
  @JsonKey(name: 'blood_group')
  final String? bloodGroup;
  @override
  final String? mobile;
  @override
  final String? email;
  @override
  @JsonKey(name: 'photo_url')
  final String? photoUrl;
  @override
  @JsonKey(name: 'admission_number')
  final String admissionNumber;
  @override
  @JsonKey(name: 'roll_number')
  final String rollNumber;
  @override
  final String status;
  @override
  @JsonKey(name: 'class_name')
  final String? className;
  @override
  @JsonKey(name: 'section_name')
  final String? sectionName;

  @override
  String toString() {
    return 'StudentDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, classId: $classId, sectionId: $sectionId, firstName: $firstName, middleName: $middleName, lastName: $lastName, gender: $gender, dateOfBirth: $dateOfBirth, bloodGroup: $bloodGroup, mobile: $mobile, email: $email, photoUrl: $photoUrl, admissionNumber: $admissionNumber, rollNumber: $rollNumber, status: $status, className: $className, sectionName: $sectionName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.middleName, middleName) ||
                other.middleName == middleName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.dateOfBirth, dateOfBirth) ||
                other.dateOfBirth == dateOfBirth) &&
            (identical(other.bloodGroup, bloodGroup) ||
                other.bloodGroup == bloodGroup) &&
            (identical(other.mobile, mobile) || other.mobile == mobile) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.admissionNumber, admissionNumber) ||
                other.admissionNumber == admissionNumber) &&
            (identical(other.rollNumber, rollNumber) ||
                other.rollNumber == rollNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.className, className) ||
                other.className == className) &&
            (identical(other.sectionName, sectionName) ||
                other.sectionName == sectionName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        tenantId,
        schoolId,
        academicYearId,
        classId,
        sectionId,
        firstName,
        middleName,
        lastName,
        gender,
        dateOfBirth,
        bloodGroup,
        mobile,
        email,
        photoUrl,
        admissionNumber,
        rollNumber,
        status,
        className,
        sectionName
      ]);

  /// Create a copy of StudentDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentDtoImplCopyWith<_$StudentDtoImpl> get copyWith =>
      __$$StudentDtoImplCopyWithImpl<_$StudentDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentDtoImplToJson(
      this,
    );
  }
}

abstract class _StudentDto implements StudentDto {
  const factory _StudentDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'first_name') required final String firstName,
      @JsonKey(name: 'middle_name') final String? middleName,
      @JsonKey(name: 'last_name') required final String lastName,
      required final String gender,
      @JsonKey(name: 'date_of_birth') required final String dateOfBirth,
      @JsonKey(name: 'blood_group') final String? bloodGroup,
      final String? mobile,
      final String? email,
      @JsonKey(name: 'photo_url') final String? photoUrl,
      @JsonKey(name: 'admission_number') required final String admissionNumber,
      @JsonKey(name: 'roll_number') required final String rollNumber,
      required final String status,
      @JsonKey(name: 'class_name') final String? className,
      @JsonKey(name: 'section_name')
      final String? sectionName}) = _$StudentDtoImpl;

  factory _StudentDto.fromJson(Map<String, dynamic> json) =
      _$StudentDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'school_id')
  String get schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  String get academicYearId;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;
  @override
  @JsonKey(name: 'first_name')
  String get firstName;
  @override
  @JsonKey(name: 'middle_name')
  String? get middleName;
  @override
  @JsonKey(name: 'last_name')
  String get lastName;
  @override
  String get gender;
  @override
  @JsonKey(name: 'date_of_birth')
  String get dateOfBirth;
  @override
  @JsonKey(name: 'blood_group')
  String? get bloodGroup;
  @override
  String? get mobile;
  @override
  String? get email;
  @override
  @JsonKey(name: 'photo_url')
  String? get photoUrl;
  @override
  @JsonKey(name: 'admission_number')
  String get admissionNumber;
  @override
  @JsonKey(name: 'roll_number')
  String get rollNumber;
  @override
  String get status;
  @override
  @JsonKey(name: 'class_name')
  String? get className;
  @override
  @JsonKey(name: 'section_name')
  String? get sectionName;

  /// Create a copy of StudentDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentDtoImplCopyWith<_$StudentDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
