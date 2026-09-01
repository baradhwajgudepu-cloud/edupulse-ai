// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AttendanceDto _$AttendanceDtoFromJson(Map<String, dynamic> json) {
  return _AttendanceDto.fromJson(json);
}

/// @nodoc
mixin _$AttendanceDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_date')
  String get attendanceDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_status')
  String get attendanceStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'remarks')
  String? get remarks => throw _privateConstructorUsedError;

  /// Serializes this AttendanceDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceDtoCopyWith<AttendanceDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceDtoCopyWith<$Res> {
  factory $AttendanceDtoCopyWith(
          AttendanceDto value, $Res Function(AttendanceDto) then) =
      _$AttendanceDtoCopyWithImpl<$Res, AttendanceDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'attendance_status') String attendanceStatus,
      @JsonKey(name: 'remarks') String? remarks});
}

/// @nodoc
class _$AttendanceDtoCopyWithImpl<$Res, $Val extends AttendanceDto>
    implements $AttendanceDtoCopyWith<$Res> {
  _$AttendanceDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? attendanceDate = null,
    Object? attendanceStatus = null,
    Object? remarks = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceStatus: null == attendanceStatus
          ? _value.attendanceStatus
          : attendanceStatus // ignore: cast_nullable_to_non_nullable
              as String,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttendanceDtoImplCopyWith<$Res>
    implements $AttendanceDtoCopyWith<$Res> {
  factory _$$AttendanceDtoImplCopyWith(
          _$AttendanceDtoImpl value, $Res Function(_$AttendanceDtoImpl) then) =
      __$$AttendanceDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'attendance_status') String attendanceStatus,
      @JsonKey(name: 'remarks') String? remarks});
}

/// @nodoc
class __$$AttendanceDtoImplCopyWithImpl<$Res>
    extends _$AttendanceDtoCopyWithImpl<$Res, _$AttendanceDtoImpl>
    implements _$$AttendanceDtoImplCopyWith<$Res> {
  __$$AttendanceDtoImplCopyWithImpl(
      _$AttendanceDtoImpl _value, $Res Function(_$AttendanceDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? attendanceDate = null,
    Object? attendanceStatus = null,
    Object? remarks = freezed,
  }) {
    return _then(_$AttendanceDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceStatus: null == attendanceStatus
          ? _value.attendanceStatus
          : attendanceStatus // ignore: cast_nullable_to_non_nullable
              as String,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceDtoImpl implements _AttendanceDto {
  const _$AttendanceDtoImpl(
      {required this.id,
      @JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'attendance_date') required this.attendanceDate,
      @JsonKey(name: 'attendance_status') required this.attendanceStatus,
      @JsonKey(name: 'remarks') this.remarks});

  factory _$AttendanceDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'attendance_date')
  final String attendanceDate;
  @override
  @JsonKey(name: 'attendance_status')
  final String attendanceStatus;
  @override
  @JsonKey(name: 'remarks')
  final String? remarks;

  @override
  String toString() {
    return 'AttendanceDto(id: $id, studentId: $studentId, attendanceDate: $attendanceDate, attendanceStatus: $attendanceStatus, remarks: $remarks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.attendanceDate, attendanceDate) ||
                other.attendanceDate == attendanceDate) &&
            (identical(other.attendanceStatus, attendanceStatus) ||
                other.attendanceStatus == attendanceStatus) &&
            (identical(other.remarks, remarks) || other.remarks == remarks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, studentId, attendanceDate, attendanceStatus, remarks);

  /// Create a copy of AttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceDtoImplCopyWith<_$AttendanceDtoImpl> get copyWith =>
      __$$AttendanceDtoImplCopyWithImpl<_$AttendanceDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceDtoImplToJson(
      this,
    );
  }
}

abstract class _AttendanceDto implements AttendanceDto {
  const factory _AttendanceDto(
      {required final String id,
      @JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'attendance_date') required final String attendanceDate,
      @JsonKey(name: 'attendance_status')
      required final String attendanceStatus,
      @JsonKey(name: 'remarks') final String? remarks}) = _$AttendanceDtoImpl;

  factory _AttendanceDto.fromJson(Map<String, dynamic> json) =
      _$AttendanceDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'attendance_date')
  String get attendanceDate;
  @override
  @JsonKey(name: 'attendance_status')
  String get attendanceStatus;
  @override
  @JsonKey(name: 'remarks')
  String? get remarks;

  /// Create a copy of AttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceDtoImplCopyWith<_$AttendanceDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
