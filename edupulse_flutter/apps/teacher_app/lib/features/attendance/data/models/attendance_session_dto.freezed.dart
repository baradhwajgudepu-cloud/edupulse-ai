// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_session_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AttendanceSessionDto _$AttendanceSessionDtoFromJson(Map<String, dynamic> json) {
  return _AttendanceSessionDto.fromJson(json);
}

/// @nodoc
mixin _$AttendanceSessionDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
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
  AttendanceSessionStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'marked_by')
  String? get markedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'marked_at')
  String? get markedAt => throw _privateConstructorUsedError;
  List<AttendanceResponseDto> get attendances =>
      throw _privateConstructorUsedError;

  /// Serializes this AttendanceSessionDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceSessionDtoCopyWith<AttendanceSessionDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceSessionDtoCopyWith<$Res> {
  factory $AttendanceSessionDtoCopyWith(AttendanceSessionDto value,
          $Res Function(AttendanceSessionDto) then) =
      _$AttendanceSessionDtoCopyWithImpl<$Res, AttendanceSessionDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'timetable_id') String timetableId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      AttendanceSessionStatus status,
      @JsonKey(name: 'marked_by') String? markedBy,
      @JsonKey(name: 'marked_at') String? markedAt,
      List<AttendanceResponseDto> attendances});
}

/// @nodoc
class _$AttendanceSessionDtoCopyWithImpl<$Res,
        $Val extends AttendanceSessionDto>
    implements $AttendanceSessionDtoCopyWith<$Res> {
  _$AttendanceSessionDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? timetableId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? teacherId = freezed,
    Object? subjectId = freezed,
    Object? attendanceDate = null,
    Object? status = null,
    Object? markedBy = freezed,
    Object? markedAt = freezed,
    Object? attendances = null,
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendanceSessionStatus,
      markedBy: freezed == markedBy
          ? _value.markedBy
          : markedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      markedAt: freezed == markedAt
          ? _value.markedAt
          : markedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      attendances: null == attendances
          ? _value.attendances
          : attendances // ignore: cast_nullable_to_non_nullable
              as List<AttendanceResponseDto>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttendanceSessionDtoImplCopyWith<$Res>
    implements $AttendanceSessionDtoCopyWith<$Res> {
  factory _$$AttendanceSessionDtoImplCopyWith(_$AttendanceSessionDtoImpl value,
          $Res Function(_$AttendanceSessionDtoImpl) then) =
      __$$AttendanceSessionDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'timetable_id') String timetableId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'teacher_id') String? teacherId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'attendance_date') String attendanceDate,
      AttendanceSessionStatus status,
      @JsonKey(name: 'marked_by') String? markedBy,
      @JsonKey(name: 'marked_at') String? markedAt,
      List<AttendanceResponseDto> attendances});
}

/// @nodoc
class __$$AttendanceSessionDtoImplCopyWithImpl<$Res>
    extends _$AttendanceSessionDtoCopyWithImpl<$Res, _$AttendanceSessionDtoImpl>
    implements _$$AttendanceSessionDtoImplCopyWith<$Res> {
  __$$AttendanceSessionDtoImplCopyWithImpl(_$AttendanceSessionDtoImpl _value,
      $Res Function(_$AttendanceSessionDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AttendanceSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? timetableId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? teacherId = freezed,
    Object? subjectId = freezed,
    Object? attendanceDate = null,
    Object? status = null,
    Object? markedBy = freezed,
    Object? markedAt = freezed,
    Object? attendances = null,
  }) {
    return _then(_$AttendanceSessionDtoImpl(
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendanceSessionStatus,
      markedBy: freezed == markedBy
          ? _value.markedBy
          : markedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      markedAt: freezed == markedAt
          ? _value.markedAt
          : markedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      attendances: null == attendances
          ? _value._attendances
          : attendances // ignore: cast_nullable_to_non_nullable
              as List<AttendanceResponseDto>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceSessionDtoImpl implements _AttendanceSessionDto {
  const _$AttendanceSessionDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'timetable_id') required this.timetableId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'teacher_id') this.teacherId,
      @JsonKey(name: 'subject_id') this.subjectId,
      @JsonKey(name: 'attendance_date') required this.attendanceDate,
      required this.status,
      @JsonKey(name: 'marked_by') this.markedBy,
      @JsonKey(name: 'marked_at') this.markedAt,
      final List<AttendanceResponseDto> attendances = const []})
      : _attendances = attendances;

  factory _$AttendanceSessionDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceSessionDtoImplFromJson(json);

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
  final AttendanceSessionStatus status;
  @override
  @JsonKey(name: 'marked_by')
  final String? markedBy;
  @override
  @JsonKey(name: 'marked_at')
  final String? markedAt;
  final List<AttendanceResponseDto> _attendances;
  @override
  @JsonKey()
  List<AttendanceResponseDto> get attendances {
    if (_attendances is EqualUnmodifiableListView) return _attendances;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attendances);
  }

  @override
  String toString() {
    return 'AttendanceSessionDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, timetableId: $timetableId, classId: $classId, sectionId: $sectionId, teacherId: $teacherId, subjectId: $subjectId, attendanceDate: $attendanceDate, status: $status, markedBy: $markedBy, markedAt: $markedAt, attendances: $attendances)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceSessionDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
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
            (identical(other.status, status) || other.status == status) &&
            (identical(other.markedBy, markedBy) ||
                other.markedBy == markedBy) &&
            (identical(other.markedAt, markedAt) ||
                other.markedAt == markedAt) &&
            const DeepCollectionEquality()
                .equals(other._attendances, _attendances));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      schoolId,
      academicYearId,
      timetableId,
      classId,
      sectionId,
      teacherId,
      subjectId,
      attendanceDate,
      status,
      markedBy,
      markedAt,
      const DeepCollectionEquality().hash(_attendances));

  /// Create a copy of AttendanceSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceSessionDtoImplCopyWith<_$AttendanceSessionDtoImpl>
      get copyWith =>
          __$$AttendanceSessionDtoImplCopyWithImpl<_$AttendanceSessionDtoImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceSessionDtoImplToJson(
      this,
    );
  }
}

abstract class _AttendanceSessionDto implements AttendanceSessionDto {
  const factory _AttendanceSessionDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'timetable_id') required final String timetableId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'teacher_id') final String? teacherId,
      @JsonKey(name: 'subject_id') final String? subjectId,
      @JsonKey(name: 'attendance_date') required final String attendanceDate,
      required final AttendanceSessionStatus status,
      @JsonKey(name: 'marked_by') final String? markedBy,
      @JsonKey(name: 'marked_at') final String? markedAt,
      final List<AttendanceResponseDto>
          attendances}) = _$AttendanceSessionDtoImpl;

  factory _AttendanceSessionDto.fromJson(Map<String, dynamic> json) =
      _$AttendanceSessionDtoImpl.fromJson;

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
  AttendanceSessionStatus get status;
  @override
  @JsonKey(name: 'marked_by')
  String? get markedBy;
  @override
  @JsonKey(name: 'marked_at')
  String? get markedAt;
  @override
  List<AttendanceResponseDto> get attendances;

  /// Create a copy of AttendanceSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceSessionDtoImplCopyWith<_$AttendanceSessionDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
