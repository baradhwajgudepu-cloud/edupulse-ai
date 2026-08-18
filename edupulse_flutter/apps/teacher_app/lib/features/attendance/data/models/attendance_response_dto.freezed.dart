// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AttendanceResponseDto _$AttendanceResponseDtoFromJson(
    Map<String, dynamic> json) {
  return _AttendanceResponseDto.fromJson(json);
}

/// @nodoc
mixin _$AttendanceResponseDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_session_id')
  String get attendanceSessionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'timetable_id')
  String get timetableId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String? get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String? get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_date')
  String get attendanceDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_status')
  AttendanceStatus get attendanceStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_source')
  AttendanceSource get attendanceSource => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_reason')
  AttendanceReason get attendanceReason => throw _privateConstructorUsedError;
  String? get remarks => throw _privateConstructorUsedError;

  /// Serializes this AttendanceResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceResponseDtoCopyWith<AttendanceResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceResponseDtoCopyWith<$Res> {
  factory $AttendanceResponseDtoCopyWith(AttendanceResponseDto value,
          $Res Function(AttendanceResponseDto) then) =
      _$AttendanceResponseDtoCopyWithImpl<$Res, AttendanceResponseDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'attendance_session_id') String attendanceSessionId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'timetable_id') String timetableId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'attendance_status') AttendanceStatus attendanceStatus,
      @JsonKey(name: 'attendance_source') AttendanceSource attendanceSource,
      @JsonKey(name: 'attendance_reason') AttendanceReason attendanceReason,
      String? remarks});
}

/// @nodoc
class _$AttendanceResponseDtoCopyWithImpl<$Res,
        $Val extends AttendanceResponseDto>
    implements $AttendanceResponseDtoCopyWith<$Res> {
  _$AttendanceResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? attendanceSessionId = null,
    Object? studentId = null,
    Object? timetableId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? teacherId = freezed,
    Object? subjectId = freezed,
    Object? attendanceDate = null,
    Object? attendanceStatus = null,
    Object? attendanceSource = null,
    Object? attendanceReason = null,
    Object? remarks = freezed,
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
      attendanceSessionId: null == attendanceSessionId
          ? _value.attendanceSessionId
          : attendanceSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      timetableId: null == timetableId
          ? _value.timetableId
          : timetableId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
      subjectId: freezed == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String?,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceStatus: null == attendanceStatus
          ? _value.attendanceStatus
          : attendanceStatus // ignore: cast_nullable_to_non_nullable
              as AttendanceStatus,
      attendanceSource: null == attendanceSource
          ? _value.attendanceSource
          : attendanceSource // ignore: cast_nullable_to_non_nullable
              as AttendanceSource,
      attendanceReason: null == attendanceReason
          ? _value.attendanceReason
          : attendanceReason // ignore: cast_nullable_to_non_nullable
              as AttendanceReason,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttendanceResponseDtoImplCopyWith<$Res>
    implements $AttendanceResponseDtoCopyWith<$Res> {
  factory _$$AttendanceResponseDtoImplCopyWith(
          _$AttendanceResponseDtoImpl value,
          $Res Function(_$AttendanceResponseDtoImpl) then) =
      __$$AttendanceResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'attendance_session_id') String attendanceSessionId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'timetable_id') String timetableId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      @JsonKey(name: 'attendance_status') AttendanceStatus attendanceStatus,
      @JsonKey(name: 'attendance_source') AttendanceSource attendanceSource,
      @JsonKey(name: 'attendance_reason') AttendanceReason attendanceReason,
      String? remarks});
}

/// @nodoc
class __$$AttendanceResponseDtoImplCopyWithImpl<$Res>
    extends _$AttendanceResponseDtoCopyWithImpl<$Res,
        _$AttendanceResponseDtoImpl>
    implements _$$AttendanceResponseDtoImplCopyWith<$Res> {
  __$$AttendanceResponseDtoImplCopyWithImpl(_$AttendanceResponseDtoImpl _value,
      $Res Function(_$AttendanceResponseDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AttendanceResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? attendanceSessionId = null,
    Object? studentId = null,
    Object? timetableId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? teacherId = freezed,
    Object? subjectId = freezed,
    Object? attendanceDate = null,
    Object? attendanceStatus = null,
    Object? attendanceSource = null,
    Object? attendanceReason = null,
    Object? remarks = freezed,
  }) {
    return _then(_$AttendanceResponseDtoImpl(
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
      attendanceSessionId: null == attendanceSessionId
          ? _value.attendanceSessionId
          : attendanceSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      timetableId: null == timetableId
          ? _value.timetableId
          : timetableId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
      subjectId: freezed == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String?,
      attendanceDate: null == attendanceDate
          ? _value.attendanceDate
          : attendanceDate // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceStatus: null == attendanceStatus
          ? _value.attendanceStatus
          : attendanceStatus // ignore: cast_nullable_to_non_nullable
              as AttendanceStatus,
      attendanceSource: null == attendanceSource
          ? _value.attendanceSource
          : attendanceSource // ignore: cast_nullable_to_non_nullable
              as AttendanceSource,
      attendanceReason: null == attendanceReason
          ? _value.attendanceReason
          : attendanceReason // ignore: cast_nullable_to_non_nullable
              as AttendanceReason,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceResponseDtoImpl implements _AttendanceResponseDto {
  const _$AttendanceResponseDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'attendance_session_id') required this.attendanceSessionId,
      @JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'timetable_id') required this.timetableId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'teacher_id') this.teacherId,
      @JsonKey(name: 'subject_id') this.subjectId,
      @JsonKey(name: 'attendance_date') required this.attendanceDate,
      @JsonKey(name: 'attendance_status') required this.attendanceStatus,
      @JsonKey(name: 'attendance_source') required this.attendanceSource,
      @JsonKey(name: 'attendance_reason') required this.attendanceReason,
      this.remarks});

  factory _$AttendanceResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceResponseDtoImplFromJson(json);

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
  @JsonKey(name: 'attendance_session_id')
  final String attendanceSessionId;
  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'timetable_id')
  final String timetableId;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;
  @override
  @JsonKey(name: 'teacher_id')
  final String? teacherId;
  @override
  @JsonKey(name: 'subject_id')
  final String? subjectId;
  @override
  @JsonKey(name: 'attendance_date')
  final String attendanceDate;
  @override
  @JsonKey(name: 'attendance_status')
  final AttendanceStatus attendanceStatus;
  @override
  @JsonKey(name: 'attendance_source')
  final AttendanceSource attendanceSource;
  @override
  @JsonKey(name: 'attendance_reason')
  final AttendanceReason attendanceReason;
  @override
  final String? remarks;

  @override
  String toString() {
    return 'AttendanceResponseDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, attendanceSessionId: $attendanceSessionId, studentId: $studentId, timetableId: $timetableId, classId: $classId, sectionId: $sectionId, teacherId: $teacherId, subjectId: $subjectId, attendanceDate: $attendanceDate, attendanceStatus: $attendanceStatus, attendanceSource: $attendanceSource, attendanceReason: $attendanceReason, remarks: $remarks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceResponseDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.attendanceSessionId, attendanceSessionId) ||
                other.attendanceSessionId == attendanceSessionId) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.timetableId, timetableId) ||
                other.timetableId == timetableId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.attendanceDate, attendanceDate) ||
                other.attendanceDate == attendanceDate) &&
            (identical(other.attendanceStatus, attendanceStatus) ||
                other.attendanceStatus == attendanceStatus) &&
            (identical(other.attendanceSource, attendanceSource) ||
                other.attendanceSource == attendanceSource) &&
            (identical(other.attendanceReason, attendanceReason) ||
                other.attendanceReason == attendanceReason) &&
            (identical(other.remarks, remarks) || other.remarks == remarks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      schoolId,
      academicYearId,
      attendanceSessionId,
      studentId,
      timetableId,
      classId,
      sectionId,
      teacherId,
      subjectId,
      attendanceDate,
      attendanceStatus,
      attendanceSource,
      attendanceReason,
      remarks);

  /// Create a copy of AttendanceResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceResponseDtoImplCopyWith<_$AttendanceResponseDtoImpl>
      get copyWith => __$$AttendanceResponseDtoImplCopyWithImpl<
          _$AttendanceResponseDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceResponseDtoImplToJson(
      this,
    );
  }
}

abstract class _AttendanceResponseDto implements AttendanceResponseDto {
  const factory _AttendanceResponseDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'attendance_session_id')
      required final String attendanceSessionId,
      @JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'timetable_id') required final String timetableId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'teacher_id') final String? teacherId,
      @JsonKey(name: 'subject_id') final String? subjectId,
      @JsonKey(name: 'attendance_date') required final String attendanceDate,
      @JsonKey(name: 'attendance_status')
      required final AttendanceStatus attendanceStatus,
      @JsonKey(name: 'attendance_source')
      required final AttendanceSource attendanceSource,
      @JsonKey(name: 'attendance_reason')
      required final AttendanceReason attendanceReason,
      final String? remarks}) = _$AttendanceResponseDtoImpl;

  factory _AttendanceResponseDto.fromJson(Map<String, dynamic> json) =
      _$AttendanceResponseDtoImpl.fromJson;

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
  @JsonKey(name: 'attendance_session_id')
  String get attendanceSessionId;
  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'timetable_id')
  String get timetableId;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;
  @override
  @JsonKey(name: 'teacher_id')
  String? get teacherId;
  @override
  @JsonKey(name: 'subject_id')
  String? get subjectId;
  @override
  @JsonKey(name: 'attendance_date')
  String get attendanceDate;
  @override
  @JsonKey(name: 'attendance_status')
  AttendanceStatus get attendanceStatus;
  @override
  @JsonKey(name: 'attendance_source')
  AttendanceSource get attendanceSource;
  @override
  @JsonKey(name: 'attendance_reason')
  AttendanceReason get attendanceReason;
  @override
  String? get remarks;

  /// Create a copy of AttendanceResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceResponseDtoImplCopyWith<_$AttendanceResponseDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
