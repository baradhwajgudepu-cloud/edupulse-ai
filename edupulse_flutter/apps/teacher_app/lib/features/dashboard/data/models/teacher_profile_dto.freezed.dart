// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teacher_profile_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TeacherProfileDto _$TeacherProfileDtoFromJson(Map<String, dynamic> json) {
  return _TeacherProfileDto.fromJson(json);
}

/// @nodoc
mixin _$TeacherProfileDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'employee_code')
  String get employeeCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_name')
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_name')
  String get lastName => throw _privateConstructorUsedError;
  String? get designation => throw _privateConstructorUsedError;
  String? get department => throw _privateConstructorUsedError;
  @JsonKey(name: 'official_email')
  String get officialEmail => throw _privateConstructorUsedError;
  String get mobile => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this TeacherProfileDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeacherProfileDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeacherProfileDtoCopyWith<TeacherProfileDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeacherProfileDtoCopyWith<$Res> {
  factory $TeacherProfileDtoCopyWith(
          TeacherProfileDto value, $Res Function(TeacherProfileDto) then) =
      _$TeacherProfileDtoCopyWithImpl<$Res, TeacherProfileDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'employee_code') String employeeCode,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'last_name') String lastName,
      String? designation,
      String? department,
      @JsonKey(name: 'official_email') String officialEmail,
      String mobile,
      String status});
}

/// @nodoc
class _$TeacherProfileDtoCopyWithImpl<$Res, $Val extends TeacherProfileDto>
    implements $TeacherProfileDtoCopyWith<$Res> {
  _$TeacherProfileDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeacherProfileDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? employeeCode = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? designation = freezed,
    Object? department = freezed,
    Object? officialEmail = null,
    Object? mobile = null,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      employeeCode: null == employeeCode
          ? _value.employeeCode
          : employeeCode // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      designation: freezed == designation
          ? _value.designation
          : designation // ignore: cast_nullable_to_non_nullable
              as String?,
      department: freezed == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String?,
      officialEmail: null == officialEmail
          ? _value.officialEmail
          : officialEmail // ignore: cast_nullable_to_non_nullable
              as String,
      mobile: null == mobile
          ? _value.mobile
          : mobile // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TeacherProfileDtoImplCopyWith<$Res>
    implements $TeacherProfileDtoCopyWith<$Res> {
  factory _$$TeacherProfileDtoImplCopyWith(_$TeacherProfileDtoImpl value,
          $Res Function(_$TeacherProfileDtoImpl) then) =
      __$$TeacherProfileDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'employee_code') String employeeCode,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'last_name') String lastName,
      String? designation,
      String? department,
      @JsonKey(name: 'official_email') String officialEmail,
      String mobile,
      String status});
}

/// @nodoc
class __$$TeacherProfileDtoImplCopyWithImpl<$Res>
    extends _$TeacherProfileDtoCopyWithImpl<$Res, _$TeacherProfileDtoImpl>
    implements _$$TeacherProfileDtoImplCopyWith<$Res> {
  __$$TeacherProfileDtoImplCopyWithImpl(_$TeacherProfileDtoImpl _value,
      $Res Function(_$TeacherProfileDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TeacherProfileDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? employeeCode = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? designation = freezed,
    Object? department = freezed,
    Object? officialEmail = null,
    Object? mobile = null,
    Object? status = null,
  }) {
    return _then(_$TeacherProfileDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      employeeCode: null == employeeCode
          ? _value.employeeCode
          : employeeCode // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      designation: freezed == designation
          ? _value.designation
          : designation // ignore: cast_nullable_to_non_nullable
              as String?,
      department: freezed == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String?,
      officialEmail: null == officialEmail
          ? _value.officialEmail
          : officialEmail // ignore: cast_nullable_to_non_nullable
              as String,
      mobile: null == mobile
          ? _value.mobile
          : mobile // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TeacherProfileDtoImpl implements _TeacherProfileDto {
  const _$TeacherProfileDtoImpl(
      {required this.id,
      @JsonKey(name: 'employee_code') required this.employeeCode,
      @JsonKey(name: 'first_name') required this.firstName,
      @JsonKey(name: 'last_name') required this.lastName,
      this.designation,
      this.department,
      @JsonKey(name: 'official_email') required this.officialEmail,
      required this.mobile,
      required this.status});

  factory _$TeacherProfileDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeacherProfileDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'employee_code')
  final String employeeCode;
  @override
  @JsonKey(name: 'first_name')
  final String firstName;
  @override
  @JsonKey(name: 'last_name')
  final String lastName;
  @override
  final String? designation;
  @override
  final String? department;
  @override
  @JsonKey(name: 'official_email')
  final String officialEmail;
  @override
  final String mobile;
  @override
  final String status;

  @override
  String toString() {
    return 'TeacherProfileDto(id: $id, employeeCode: $employeeCode, firstName: $firstName, lastName: $lastName, designation: $designation, department: $department, officialEmail: $officialEmail, mobile: $mobile, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeacherProfileDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.employeeCode, employeeCode) ||
                other.employeeCode == employeeCode) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.designation, designation) ||
                other.designation == designation) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.officialEmail, officialEmail) ||
                other.officialEmail == officialEmail) &&
            (identical(other.mobile, mobile) || other.mobile == mobile) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, employeeCode, firstName,
      lastName, designation, department, officialEmail, mobile, status);

  /// Create a copy of TeacherProfileDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeacherProfileDtoImplCopyWith<_$TeacherProfileDtoImpl> get copyWith =>
      __$$TeacherProfileDtoImplCopyWithImpl<_$TeacherProfileDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeacherProfileDtoImplToJson(
      this,
    );
  }
}

abstract class _TeacherProfileDto implements TeacherProfileDto {
  const factory _TeacherProfileDto(
      {required final String id,
      @JsonKey(name: 'employee_code') required final String employeeCode,
      @JsonKey(name: 'first_name') required final String firstName,
      @JsonKey(name: 'last_name') required final String lastName,
      final String? designation,
      final String? department,
      @JsonKey(name: 'official_email') required final String officialEmail,
      required final String mobile,
      required final String status}) = _$TeacherProfileDtoImpl;

  factory _TeacherProfileDto.fromJson(Map<String, dynamic> json) =
      _$TeacherProfileDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'employee_code')
  String get employeeCode;
  @override
  @JsonKey(name: 'first_name')
  String get firstName;
  @override
  @JsonKey(name: 'last_name')
  String get lastName;
  @override
  String? get designation;
  @override
  String? get department;
  @override
  @JsonKey(name: 'official_email')
  String get officialEmail;
  @override
  String get mobile;
  @override
  String get status;

  /// Create a copy of TeacherProfileDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeacherProfileDtoImplCopyWith<_$TeacherProfileDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
