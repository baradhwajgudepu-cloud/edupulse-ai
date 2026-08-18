// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'staff_attendance_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StaffAttendanceDto _$StaffAttendanceDtoFromJson(Map<String, dynamic> json) {
  return _StaffAttendanceDto.fromJson(json);
}

/// @nodoc
mixin _$StaffAttendanceDto {
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_date')
  String get attendanceDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_time')
  String? get checkInTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_latitude')
  double? get checkInLatitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_longitude')
  double? get checkInLongitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_distance_meters')
  double? get checkInDistanceMeters => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_out_time')
  String? get checkOutTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_out_latitude')
  double? get checkOutLatitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_out_longitude')
  double? get checkOutLongitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_out_distance_meters')
  double? get checkOutDistanceMeters => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_mocked_location')
  bool get isMockedLocation => throw _privateConstructorUsedError;
  String? get remarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_seconds')
  int? get durationSeconds => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this StaffAttendanceDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StaffAttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StaffAttendanceDtoCopyWith<StaffAttendanceDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StaffAttendanceDtoCopyWith<$Res> {
  factory $StaffAttendanceDtoCopyWith(
          StaffAttendanceDto value, $Res Function(StaffAttendanceDto) then) =
      _$StaffAttendanceDtoCopyWithImpl<$Res, StaffAttendanceDto>;
  @useResult
  $Res call(
      {String? id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'check_in_time') String? checkInTime,
      @JsonKey(name: 'check_in_latitude') double? checkInLatitude,
      @JsonKey(name: 'check_in_longitude') double? checkInLongitude,
      @JsonKey(name: 'check_in_distance_meters') double? checkInDistanceMeters,
      @JsonKey(name: 'check_out_time') String? checkOutTime,
      @JsonKey(name: 'check_out_latitude') double? checkOutLatitude,
      @JsonKey(name: 'check_out_longitude') double? checkOutLongitude,
      @JsonKey(name: 'check_out_distance_meters')
      double? checkOutDistanceMeters,
      @JsonKey(name: 'is_mocked_location') bool isMockedLocation,
      String? remarks,
      @JsonKey(name: 'duration_seconds') int? durationSeconds,
      String status});
}

/// @nodoc
class _$StaffAttendanceDtoCopyWithImpl<$Res, $Val extends StaffAttendanceDto>
    implements $StaffAttendanceDtoCopyWith<$Res> {
  _$StaffAttendanceDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StaffAttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = null,
    Object? teacherId = null,
    Object? schoolId = null,
    Object? attendanceDate = null,
    Object? checkInTime = freezed,
    Object? checkInLatitude = freezed,
    Object? checkInLongitude = freezed,
    Object? checkInDistanceMeters = freezed,
    Object? checkOutTime = freezed,
    Object? checkOutLatitude = freezed,
    Object? checkOutLongitude = freezed,
    Object? checkOutDistanceMeters = freezed,
    Object? isMockedLocation = null,
    Object? remarks = freezed,
    Object? durationSeconds = freezed,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      checkInTime: freezed == checkInTime
          ? _value.checkInTime
          : checkInTime // ignore: cast_nullable_to_non_nullable
              as String?,
      checkInLatitude: freezed == checkInLatitude
          ? _value.checkInLatitude
          : checkInLatitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInLongitude: freezed == checkInLongitude
          ? _value.checkInLongitude
          : checkInLongitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInDistanceMeters: freezed == checkInDistanceMeters
          ? _value.checkInDistanceMeters
          : checkInDistanceMeters // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutTime: freezed == checkOutTime
          ? _value.checkOutTime
          : checkOutTime // ignore: cast_nullable_to_non_nullable
              as String?,
      checkOutLatitude: freezed == checkOutLatitude
          ? _value.checkOutLatitude
          : checkOutLatitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutLongitude: freezed == checkOutLongitude
          ? _value.checkOutLongitude
          : checkOutLongitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutDistanceMeters: freezed == checkOutDistanceMeters
          ? _value.checkOutDistanceMeters
          : checkOutDistanceMeters // ignore: cast_nullable_to_non_nullable
              as double?,
      isMockedLocation: null == isMockedLocation
          ? _value.isMockedLocation
          : isMockedLocation // ignore: cast_nullable_to_non_nullable
              as bool,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StaffAttendanceDtoImplCopyWith<$Res>
    implements $StaffAttendanceDtoCopyWith<$Res> {
  factory _$$StaffAttendanceDtoImplCopyWith(_$StaffAttendanceDtoImpl value,
          $Res Function(_$StaffAttendanceDtoImpl) then) =
      __$$StaffAttendanceDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'check_in_time') String? checkInTime,
      @JsonKey(name: 'check_in_latitude') double? checkInLatitude,
      @JsonKey(name: 'check_in_longitude') double? checkInLongitude,
      @JsonKey(name: 'check_in_distance_meters') double? checkInDistanceMeters,
      @JsonKey(name: 'check_out_time') String? checkOutTime,
      @JsonKey(name: 'check_out_latitude') double? checkOutLatitude,
      @JsonKey(name: 'check_out_longitude') double? checkOutLongitude,
      @JsonKey(name: 'check_out_distance_meters')
      double? checkOutDistanceMeters,
      @JsonKey(name: 'is_mocked_location') bool isMockedLocation,
      String? remarks,
      @JsonKey(name: 'duration_seconds') int? durationSeconds,
      String status});
}

/// @nodoc
class __$$StaffAttendanceDtoImplCopyWithImpl<$Res>
    extends _$StaffAttendanceDtoCopyWithImpl<$Res, _$StaffAttendanceDtoImpl>
    implements _$$StaffAttendanceDtoImplCopyWith<$Res> {
  __$$StaffAttendanceDtoImplCopyWithImpl(_$StaffAttendanceDtoImpl _value,
      $Res Function(_$StaffAttendanceDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of StaffAttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = null,
    Object? teacherId = null,
    Object? schoolId = null,
    Object? attendanceDate = null,
    Object? checkInTime = freezed,
    Object? checkInLatitude = freezed,
    Object? checkInLongitude = freezed,
    Object? checkInDistanceMeters = freezed,
    Object? checkOutTime = freezed,
    Object? checkOutLatitude = freezed,
    Object? checkOutLongitude = freezed,
    Object? checkOutDistanceMeters = freezed,
    Object? isMockedLocation = null,
    Object? remarks = freezed,
    Object? durationSeconds = freezed,
    Object? status = null,
  }) {
    return _then(_$StaffAttendanceDtoImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      checkInTime: freezed == checkInTime
          ? _value.checkInTime
          : checkInTime // ignore: cast_nullable_to_non_nullable
              as String?,
      checkInLatitude: freezed == checkInLatitude
          ? _value.checkInLatitude
          : checkInLatitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInLongitude: freezed == checkInLongitude
          ? _value.checkInLongitude
          : checkInLongitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkInDistanceMeters: freezed == checkInDistanceMeters
          ? _value.checkInDistanceMeters
          : checkInDistanceMeters // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutTime: freezed == checkOutTime
          ? _value.checkOutTime
          : checkOutTime // ignore: cast_nullable_to_non_nullable
              as String?,
      checkOutLatitude: freezed == checkOutLatitude
          ? _value.checkOutLatitude
          : checkOutLatitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutLongitude: freezed == checkOutLongitude
          ? _value.checkOutLongitude
          : checkOutLongitude // ignore: cast_nullable_to_non_nullable
              as double?,
      checkOutDistanceMeters: freezed == checkOutDistanceMeters
          ? _value.checkOutDistanceMeters
          : checkOutDistanceMeters // ignore: cast_nullable_to_non_nullable
              as double?,
      isMockedLocation: null == isMockedLocation
          ? _value.isMockedLocation
          : isMockedLocation // ignore: cast_nullable_to_non_nullable
              as bool,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      durationSeconds: freezed == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StaffAttendanceDtoImpl implements _StaffAttendanceDto {
  const _$StaffAttendanceDtoImpl(
      {this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'attendance_date') required this.attendanceDate,
      @JsonKey(name: 'check_in_time') this.checkInTime,
      @JsonKey(name: 'check_in_latitude') this.checkInLatitude,
      @JsonKey(name: 'check_in_longitude') this.checkInLongitude,
      @JsonKey(name: 'check_in_distance_meters') this.checkInDistanceMeters,
      @JsonKey(name: 'check_out_time') this.checkOutTime,
      @JsonKey(name: 'check_out_latitude') this.checkOutLatitude,
      @JsonKey(name: 'check_out_longitude') this.checkOutLongitude,
      @JsonKey(name: 'check_out_distance_meters') this.checkOutDistanceMeters,
      @JsonKey(name: 'is_mocked_location') this.isMockedLocation = false,
      this.remarks,
      @JsonKey(name: 'duration_seconds') this.durationSeconds,
      required this.status});

  factory _$StaffAttendanceDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$StaffAttendanceDtoImplFromJson(json);

  @override
  final String? id;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @override
  @JsonKey(name: 'school_id')
  final String schoolId;
  @override
  @JsonKey(name: 'attendance_date')
  final String attendanceDate;
  @override
  @JsonKey(name: 'check_in_time')
  final String? checkInTime;
  @override
  @JsonKey(name: 'check_in_latitude')
  final double? checkInLatitude;
  @override
  @JsonKey(name: 'check_in_longitude')
  final double? checkInLongitude;
  @override
  @JsonKey(name: 'check_in_distance_meters')
  final double? checkInDistanceMeters;
  @override
  @JsonKey(name: 'check_out_time')
  final String? checkOutTime;
  @override
  @JsonKey(name: 'check_out_latitude')
  final double? checkOutLatitude;
  @override
  @JsonKey(name: 'check_out_longitude')
  final double? checkOutLongitude;
  @override
  @JsonKey(name: 'check_out_distance_meters')
  final double? checkOutDistanceMeters;
  @override
  @JsonKey(name: 'is_mocked_location')
  final bool isMockedLocation;
  @override
  final String? remarks;
  @override
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  @override
  final String status;

  @override
  String toString() {
    return 'StaffAttendanceDto(id: $id, tenantId: $tenantId, teacherId: $teacherId, schoolId: $schoolId, attendanceDate: $attendanceDate, checkInTime: $checkInTime, checkInLatitude: $checkInLatitude, checkInLongitude: $checkInLongitude, checkInDistanceMeters: $checkInDistanceMeters, checkOutTime: $checkOutTime, checkOutLatitude: $checkOutLatitude, checkOutLongitude: $checkOutLongitude, checkOutDistanceMeters: $checkOutDistanceMeters, isMockedLocation: $isMockedLocation, remarks: $remarks, durationSeconds: $durationSeconds, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StaffAttendanceDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.attendanceDate, attendanceDate) ||
                other.attendanceDate == attendanceDate) &&
            (identical(other.checkInTime, checkInTime) ||
                other.checkInTime == checkInTime) &&
            (identical(other.checkInLatitude, checkInLatitude) ||
                other.checkInLatitude == checkInLatitude) &&
            (identical(other.checkInLongitude, checkInLongitude) ||
                other.checkInLongitude == checkInLongitude) &&
            (identical(other.checkInDistanceMeters, checkInDistanceMeters) ||
                other.checkInDistanceMeters == checkInDistanceMeters) &&
            (identical(other.checkOutTime, checkOutTime) ||
                other.checkOutTime == checkOutTime) &&
            (identical(other.checkOutLatitude, checkOutLatitude) ||
                other.checkOutLatitude == checkOutLatitude) &&
            (identical(other.checkOutLongitude, checkOutLongitude) ||
                other.checkOutLongitude == checkOutLongitude) &&
            (identical(other.checkOutDistanceMeters, checkOutDistanceMeters) ||
                other.checkOutDistanceMeters == checkOutDistanceMeters) &&
            (identical(other.isMockedLocation, isMockedLocation) ||
                other.isMockedLocation == isMockedLocation) &&
            (identical(other.remarks, remarks) || other.remarks == remarks) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      teacherId,
      schoolId,
      attendanceDate,
      checkInTime,
      checkInLatitude,
      checkInLongitude,
      checkInDistanceMeters,
      checkOutTime,
      checkOutLatitude,
      checkOutLongitude,
      checkOutDistanceMeters,
      isMockedLocation,
      remarks,
      durationSeconds,
      status);

  /// Create a copy of StaffAttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StaffAttendanceDtoImplCopyWith<_$StaffAttendanceDtoImpl> get copyWith =>
      __$$StaffAttendanceDtoImplCopyWithImpl<_$StaffAttendanceDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StaffAttendanceDtoImplToJson(
      this,
    );
  }
}

abstract class _StaffAttendanceDto implements StaffAttendanceDto {
  const factory _StaffAttendanceDto(
      {final String? id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'teacher_id') required final String teacherId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'attendance_date') required final String attendanceDate,
      @JsonKey(name: 'check_in_time') final String? checkInTime,
      @JsonKey(name: 'check_in_latitude') final double? checkInLatitude,
      @JsonKey(name: 'check_in_longitude') final double? checkInLongitude,
      @JsonKey(name: 'check_in_distance_meters')
      final double? checkInDistanceMeters,
      @JsonKey(name: 'check_out_time') final String? checkOutTime,
      @JsonKey(name: 'check_out_latitude') final double? checkOutLatitude,
      @JsonKey(name: 'check_out_longitude') final double? checkOutLongitude,
      @JsonKey(name: 'check_out_distance_meters')
      final double? checkOutDistanceMeters,
      @JsonKey(name: 'is_mocked_location') final bool isMockedLocation,
      final String? remarks,
      @JsonKey(name: 'duration_seconds') final int? durationSeconds,
      required final String status}) = _$StaffAttendanceDtoImpl;

  factory _StaffAttendanceDto.fromJson(Map<String, dynamic> json) =
      _$StaffAttendanceDtoImpl.fromJson;

  @override
  String? get id;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'teacher_id')
  String get teacherId;
  @override
  @JsonKey(name: 'school_id')
  String get schoolId;
  @override
  @JsonKey(name: 'attendance_date')
  String get attendanceDate;
  @override
  @JsonKey(name: 'check_in_time')
  String? get checkInTime;
  @override
  @JsonKey(name: 'check_in_latitude')
  double? get checkInLatitude;
  @override
  @JsonKey(name: 'check_in_longitude')
  double? get checkInLongitude;
  @override
  @JsonKey(name: 'check_in_distance_meters')
  double? get checkInDistanceMeters;
  @override
  @JsonKey(name: 'check_out_time')
  String? get checkOutTime;
  @override
  @JsonKey(name: 'check_out_latitude')
  double? get checkOutLatitude;
  @override
  @JsonKey(name: 'check_out_longitude')
  double? get checkOutLongitude;
  @override
  @JsonKey(name: 'check_out_distance_meters')
  double? get checkOutDistanceMeters;
  @override
  @JsonKey(name: 'is_mocked_location')
  bool get isMockedLocation;
  @override
  String? get remarks;
  @override
  @JsonKey(name: 'duration_seconds')
  int? get durationSeconds;
  @override
  String get status;

  /// Create a copy of StaffAttendanceDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StaffAttendanceDtoImplCopyWith<_$StaffAttendanceDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
