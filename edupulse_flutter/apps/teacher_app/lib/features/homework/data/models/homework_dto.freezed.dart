// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'homework_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

HomeworkDto _$HomeworkDtoFromJson(Map<String, dynamic> json) {
  return _HomeworkDto.fromJson(json);
}

/// @nodoc
mixin _$HomeworkDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'timetable_id')
  String? get timetableId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'due_date')
  String get dueDate => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_url')
  String? get attachmentUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'estimated_minutes')
  int? get estimatedMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  Map<String, dynamic> get settings => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  String get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this HomeworkDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeworkDtoCopyWith<HomeworkDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeworkDtoCopyWith<$Res> {
  factory $HomeworkDtoCopyWith(
          HomeworkDto value, $Res Function(HomeworkDto) then) =
      _$HomeworkDtoCopyWithImpl<$Res, HomeworkDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'timetable_id') String? timetableId,
      String title,
      String description,
      @JsonKey(name: 'due_date') String dueDate,
      String priority,
      String status,
      @JsonKey(name: 'attachment_url') String? attachmentUrl,
      @JsonKey(name: 'estimated_minutes') int? estimatedMinutes,
      @JsonKey(name: 'is_active') bool isActive,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class _$HomeworkDtoCopyWithImpl<$Res, $Val extends HomeworkDto>
    implements $HomeworkDtoCopyWith<$Res> {
  _$HomeworkDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? teacherId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? timetableId = freezed,
    Object? title = null,
    Object? description = null,
    Object? dueDate = null,
    Object? priority = null,
    Object? status = null,
    Object? attachmentUrl = freezed,
    Object? estimatedMinutes = freezed,
    Object? isActive = null,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? version = null,
    Object? createdAt = null,
    Object? updatedAt = null,
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
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
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
      timetableId: freezed == timetableId
          ? _value.timetableId
          : timetableId // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      attachmentUrl: freezed == attachmentUrl
          ? _value.attachmentUrl
          : attachmentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedMinutes: freezed == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value.aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HomeworkDtoImplCopyWith<$Res>
    implements $HomeworkDtoCopyWith<$Res> {
  factory _$$HomeworkDtoImplCopyWith(
          _$HomeworkDtoImpl value, $Res Function(_$HomeworkDtoImpl) then) =
      __$$HomeworkDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'timetable_id') String? timetableId,
      String title,
      String description,
      @JsonKey(name: 'due_date') String dueDate,
      String priority,
      String status,
      @JsonKey(name: 'attachment_url') String? attachmentUrl,
      @JsonKey(name: 'estimated_minutes') int? estimatedMinutes,
      @JsonKey(name: 'is_active') bool isActive,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class __$$HomeworkDtoImplCopyWithImpl<$Res>
    extends _$HomeworkDtoCopyWithImpl<$Res, _$HomeworkDtoImpl>
    implements _$$HomeworkDtoImplCopyWith<$Res> {
  __$$HomeworkDtoImplCopyWithImpl(
      _$HomeworkDtoImpl _value, $Res Function(_$HomeworkDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? teacherId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? timetableId = freezed,
    Object? title = null,
    Object? description = null,
    Object? dueDate = null,
    Object? priority = null,
    Object? status = null,
    Object? attachmentUrl = freezed,
    Object? estimatedMinutes = freezed,
    Object? isActive = null,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? version = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$HomeworkDtoImpl(
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
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
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
      timetableId: freezed == timetableId
          ? _value.timetableId
          : timetableId // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      attachmentUrl: freezed == attachmentUrl
          ? _value.attachmentUrl
          : attachmentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedMinutes: freezed == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      settings: null == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value._aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HomeworkDtoImpl extends _HomeworkDto {
  const _$HomeworkDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required this.teacherSubjectAssignmentId,
      @JsonKey(name: 'subject_id') required this.subjectId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'timetable_id') this.timetableId,
      required this.title,
      required this.description,
      @JsonKey(name: 'due_date') required this.dueDate,
      required this.priority,
      required this.status,
      @JsonKey(name: 'attachment_url') this.attachmentUrl,
      @JsonKey(name: 'estimated_minutes') this.estimatedMinutes,
      @JsonKey(name: 'is_active') required this.isActive,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      required this.version,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt})
      : _settings = settings,
        _aiMetrics = aiMetrics,
        super._();

  factory _$HomeworkDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$HomeworkDtoImplFromJson(json);

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
  @JsonKey(name: 'teacher_subject_assignment_id')
  final String teacherSubjectAssignmentId;
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
  @JsonKey(name: 'timetable_id')
  final String? timetableId;
  @override
  final String title;
  @override
  final String description;
  @override
  @JsonKey(name: 'due_date')
  final String dueDate;
  @override
  final String priority;
  @override
  final String status;
  @override
  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;
  @override
  @JsonKey(name: 'estimated_minutes')
  final int? estimatedMinutes;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  final Map<String, dynamic> _settings;
  @override
  Map<String, dynamic> get settings {
    if (_settings is EqualUnmodifiableMapView) return _settings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_settings);
  }

  final Map<String, dynamic> _aiMetrics;
  @override
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics {
    if (_aiMetrics is EqualUnmodifiableMapView) return _aiMetrics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_aiMetrics);
  }

  @override
  final int version;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  @override
  String toString() {
    return 'HomeworkDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, teacherId: $teacherId, teacherSubjectAssignmentId: $teacherSubjectAssignmentId, subjectId: $subjectId, classId: $classId, sectionId: $sectionId, timetableId: $timetableId, title: $title, description: $description, dueDate: $dueDate, priority: $priority, status: $status, attachmentUrl: $attachmentUrl, estimatedMinutes: $estimatedMinutes, isActive: $isActive, settings: $settings, aiMetrics: $aiMetrics, version: $version, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeworkDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.teacherSubjectAssignmentId,
                    teacherSubjectAssignmentId) ||
                other.teacherSubjectAssignmentId ==
                    teacherSubjectAssignmentId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.timetableId, timetableId) ||
                other.timetableId == timetableId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.attachmentUrl, attachmentUrl) ||
                other.attachmentUrl == attachmentUrl) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality().equals(other._settings, _settings) &&
            const DeepCollectionEquality()
                .equals(other._aiMetrics, _aiMetrics) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        tenantId,
        schoolId,
        academicYearId,
        teacherId,
        teacherSubjectAssignmentId,
        subjectId,
        classId,
        sectionId,
        timetableId,
        title,
        description,
        dueDate,
        priority,
        status,
        attachmentUrl,
        estimatedMinutes,
        isActive,
        const DeepCollectionEquality().hash(_settings),
        const DeepCollectionEquality().hash(_aiMetrics),
        version,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeworkDtoImplCopyWith<_$HomeworkDtoImpl> get copyWith =>
      __$$HomeworkDtoImplCopyWithImpl<_$HomeworkDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HomeworkDtoImplToJson(
      this,
    );
  }
}

abstract class _HomeworkDto extends HomeworkDto {
  const factory _HomeworkDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'teacher_id') required final String teacherId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required final String teacherSubjectAssignmentId,
      @JsonKey(name: 'subject_id') required final String subjectId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'timetable_id') final String? timetableId,
      required final String title,
      required final String description,
      @JsonKey(name: 'due_date') required final String dueDate,
      required final String priority,
      required final String status,
      @JsonKey(name: 'attachment_url') final String? attachmentUrl,
      @JsonKey(name: 'estimated_minutes') final int? estimatedMinutes,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      required final int version,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'updated_at')
      required final String updatedAt}) = _$HomeworkDtoImpl;
  const _HomeworkDto._() : super._();

  factory _HomeworkDto.fromJson(Map<String, dynamic> json) =
      _$HomeworkDtoImpl.fromJson;

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
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId;
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
  @JsonKey(name: 'timetable_id')
  String? get timetableId;
  @override
  String get title;
  @override
  String get description;
  @override
  @JsonKey(name: 'due_date')
  String get dueDate;
  @override
  String get priority;
  @override
  String get status;
  @override
  @JsonKey(name: 'attachment_url')
  String? get attachmentUrl;
  @override
  @JsonKey(name: 'estimated_minutes')
  int? get estimatedMinutes;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  Map<String, dynamic> get settings;
  @override
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics;
  @override
  int get version;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  String get updatedAt;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeworkDtoImplCopyWith<_$HomeworkDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
