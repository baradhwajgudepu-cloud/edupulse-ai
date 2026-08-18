// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teacher_subject_assignment_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TeacherSubjectAssignmentDto _$TeacherSubjectAssignmentDtoFromJson(
    Map<String, dynamic> json) {
  return _TeacherSubjectAssignmentDto.fromJson(json);
}

/// @nodoc
mixin _$TeacherSubjectAssignmentDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'assignment_type')
  String get assignmentType => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  @JsonKey(name: 'weekly_periods')
  int get weeklyPeriods => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_class_teacher')
  bool get isClassTeacher => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this TeacherSubjectAssignmentDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeacherSubjectAssignmentDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeacherSubjectAssignmentDtoCopyWith<TeacherSubjectAssignmentDto>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeacherSubjectAssignmentDtoCopyWith<$Res> {
  factory $TeacherSubjectAssignmentDtoCopyWith(
          TeacherSubjectAssignmentDto value,
          $Res Function(TeacherSubjectAssignmentDto) then) =
      _$TeacherSubjectAssignmentDtoCopyWithImpl<$Res,
          TeacherSubjectAssignmentDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'assignment_type') String assignmentType,
      int priority,
      @JsonKey(name: 'weekly_periods') int weeklyPeriods,
      @JsonKey(name: 'is_class_teacher') bool isClassTeacher,
      @JsonKey(name: 'is_active') bool isActive,
      String status});
}

/// @nodoc
class _$TeacherSubjectAssignmentDtoCopyWithImpl<$Res,
        $Val extends TeacherSubjectAssignmentDto>
    implements $TeacherSubjectAssignmentDtoCopyWith<$Res> {
  _$TeacherSubjectAssignmentDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeacherSubjectAssignmentDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? teacherId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? assignmentType = null,
    Object? priority = null,
    Object? weeklyPeriods = null,
    Object? isClassTeacher = null,
    Object? isActive = null,
    Object? status = null,
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
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      assignmentType: null == assignmentType
          ? _value.assignmentType
          : assignmentType // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      weeklyPeriods: null == weeklyPeriods
          ? _value.weeklyPeriods
          : weeklyPeriods // ignore: cast_nullable_to_non_nullable
              as int,
      isClassTeacher: null == isClassTeacher
          ? _value.isClassTeacher
          : isClassTeacher // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TeacherSubjectAssignmentDtoImplCopyWith<$Res>
    implements $TeacherSubjectAssignmentDtoCopyWith<$Res> {
  factory _$$TeacherSubjectAssignmentDtoImplCopyWith(
          _$TeacherSubjectAssignmentDtoImpl value,
          $Res Function(_$TeacherSubjectAssignmentDtoImpl) then) =
      __$$TeacherSubjectAssignmentDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'assignment_type') String assignmentType,
      int priority,
      @JsonKey(name: 'weekly_periods') int weeklyPeriods,
      @JsonKey(name: 'is_class_teacher') bool isClassTeacher,
      @JsonKey(name: 'is_active') bool isActive,
      String status});
}

/// @nodoc
class __$$TeacherSubjectAssignmentDtoImplCopyWithImpl<$Res>
    extends _$TeacherSubjectAssignmentDtoCopyWithImpl<$Res,
        _$TeacherSubjectAssignmentDtoImpl>
    implements _$$TeacherSubjectAssignmentDtoImplCopyWith<$Res> {
  __$$TeacherSubjectAssignmentDtoImplCopyWithImpl(
      _$TeacherSubjectAssignmentDtoImpl _value,
      $Res Function(_$TeacherSubjectAssignmentDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TeacherSubjectAssignmentDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? teacherId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? assignmentType = null,
    Object? priority = null,
    Object? weeklyPeriods = null,
    Object? isClassTeacher = null,
    Object? isActive = null,
    Object? status = null,
  }) {
    return _then(_$TeacherSubjectAssignmentDtoImpl(
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
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      assignmentType: null == assignmentType
          ? _value.assignmentType
          : assignmentType // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      weeklyPeriods: null == weeklyPeriods
          ? _value.weeklyPeriods
          : weeklyPeriods // ignore: cast_nullable_to_non_nullable
              as int,
      isClassTeacher: null == isClassTeacher
          ? _value.isClassTeacher
          : isClassTeacher // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TeacherSubjectAssignmentDtoImpl
    implements _TeacherSubjectAssignmentDto {
  const _$TeacherSubjectAssignmentDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'subject_id') required this.subjectId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'assignment_type') required this.assignmentType,
      required this.priority,
      @JsonKey(name: 'weekly_periods') required this.weeklyPeriods,
      @JsonKey(name: 'is_class_teacher') required this.isClassTeacher,
      @JsonKey(name: 'is_active') required this.isActive,
      required this.status});

  factory _$TeacherSubjectAssignmentDtoImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$TeacherSubjectAssignmentDtoImplFromJson(json);

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
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @override
  @JsonKey(name: 'subject_id')
  final String subjectId;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;
  @override
  @JsonKey(name: 'assignment_type')
  final String assignmentType;
  @override
  final int priority;
  @override
  @JsonKey(name: 'weekly_periods')
  final int weeklyPeriods;
  @override
  @JsonKey(name: 'is_class_teacher')
  final bool isClassTeacher;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  final String status;

  @override
  String toString() {
    return 'TeacherSubjectAssignmentDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, teacherId: $teacherId, subjectId: $subjectId, classId: $classId, sectionId: $sectionId, assignmentType: $assignmentType, priority: $priority, weeklyPeriods: $weeklyPeriods, isClassTeacher: $isClassTeacher, isActive: $isActive, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeacherSubjectAssignmentDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.assignmentType, assignmentType) ||
                other.assignmentType == assignmentType) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.weeklyPeriods, weeklyPeriods) ||
                other.weeklyPeriods == weeklyPeriods) &&
            (identical(other.isClassTeacher, isClassTeacher) ||
                other.isClassTeacher == isClassTeacher) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      schoolId,
      academicYearId,
      teacherId,
      subjectId,
      classId,
      sectionId,
      assignmentType,
      priority,
      weeklyPeriods,
      isClassTeacher,
      isActive,
      status);

  /// Create a copy of TeacherSubjectAssignmentDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeacherSubjectAssignmentDtoImplCopyWith<_$TeacherSubjectAssignmentDtoImpl>
      get copyWith => __$$TeacherSubjectAssignmentDtoImplCopyWithImpl<
          _$TeacherSubjectAssignmentDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeacherSubjectAssignmentDtoImplToJson(
      this,
    );
  }
}

abstract class _TeacherSubjectAssignmentDto
    implements TeacherSubjectAssignmentDto {
  const factory _TeacherSubjectAssignmentDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'teacher_id') required final String teacherId,
      @JsonKey(name: 'subject_id') required final String subjectId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'assignment_type') required final String assignmentType,
      required final int priority,
      @JsonKey(name: 'weekly_periods') required final int weeklyPeriods,
      @JsonKey(name: 'is_class_teacher') required final bool isClassTeacher,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final String status}) = _$TeacherSubjectAssignmentDtoImpl;

  factory _TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic> json) =
      _$TeacherSubjectAssignmentDtoImpl.fromJson;

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
  @JsonKey(name: 'teacher_id')
  String get teacherId;
  @override
  @JsonKey(name: 'subject_id')
  String get subjectId;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;
  @override
  @JsonKey(name: 'assignment_type')
  String get assignmentType;
  @override
  int get priority;
  @override
  @JsonKey(name: 'weekly_periods')
  int get weeklyPeriods;
  @override
  @JsonKey(name: 'is_class_teacher')
  bool get isClassTeacher;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  String get status;

  /// Create a copy of TeacherSubjectAssignmentDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeacherSubjectAssignmentDtoImplCopyWith<_$TeacherSubjectAssignmentDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
