// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marks_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MarksDto _$MarksDtoFromJson(Map<String, dynamic> json) {
  return _MarksDto.fromJson(json);
}

/// @nodoc
mixin _$MarksDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'examination_id')
  String get examinationId => throw _privateConstructorUsedError;
  @JsonKey(name: 'exam_schedule_id')
  String get examScheduleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'maximum_marks')
  int get maximumMarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'marks_obtained')
  double? get marksObtained => throw _privateConstructorUsedError;
  @JsonKey(name: 'result_status')
  String get resultStatus => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get grade => throw _privateConstructorUsedError;
  String? get remarks => throw _privateConstructorUsedError;
  Map<String, dynamic> get settings => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics => throw _privateConstructorUsedError;
  @JsonKey(name: 'audit_history')
  List<dynamic> get auditHistory => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  String get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MarksDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarksDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarksDtoCopyWith<MarksDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarksDtoCopyWith<$Res> {
  factory $MarksDtoCopyWith(MarksDto value, $Res Function(MarksDto) then) =
      _$MarksDtoCopyWithImpl<$Res, MarksDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'examination_id') String examinationId,
      @JsonKey(name: 'exam_schedule_id') String examScheduleId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'maximum_marks') int maximumMarks,
      @JsonKey(name: 'marks_obtained') double? marksObtained,
      @JsonKey(name: 'result_status') String resultStatus,
      String status,
      String? grade,
      String? remarks,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'audit_history') List<dynamic> auditHistory,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class _$MarksDtoCopyWithImpl<$Res, $Val extends MarksDto>
    implements $MarksDtoCopyWith<$Res> {
  _$MarksDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarksDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? examinationId = null,
    Object? examScheduleId = null,
    Object? studentId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? teacherId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? maximumMarks = null,
    Object? marksObtained = freezed,
    Object? resultStatus = null,
    Object? status = null,
    Object? grade = freezed,
    Object? remarks = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? auditHistory = null,
    Object? isActive = null,
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
      examinationId: null == examinationId
          ? _value.examinationId
          : examinationId // ignore: cast_nullable_to_non_nullable
              as String,
      examScheduleId: null == examScheduleId
          ? _value.examScheduleId
          : examScheduleId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
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
      maximumMarks: null == maximumMarks
          ? _value.maximumMarks
          : maximumMarks // ignore: cast_nullable_to_non_nullable
              as int,
      marksObtained: freezed == marksObtained
          ? _value.marksObtained
          : marksObtained // ignore: cast_nullable_to_non_nullable
              as double?,
      resultStatus: null == resultStatus
          ? _value.resultStatus
          : resultStatus // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      grade: freezed == grade
          ? _value.grade
          : grade // ignore: cast_nullable_to_non_nullable
              as String?,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value.aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      auditHistory: null == auditHistory
          ? _value.auditHistory
          : auditHistory // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
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
abstract class _$$MarksDtoImplCopyWith<$Res>
    implements $MarksDtoCopyWith<$Res> {
  factory _$$MarksDtoImplCopyWith(
          _$MarksDtoImpl value, $Res Function(_$MarksDtoImpl) then) =
      __$$MarksDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'examination_id') String examinationId,
      @JsonKey(name: 'exam_schedule_id') String examScheduleId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'maximum_marks') int maximumMarks,
      @JsonKey(name: 'marks_obtained') double? marksObtained,
      @JsonKey(name: 'result_status') String resultStatus,
      String status,
      String? grade,
      String? remarks,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'audit_history') List<dynamic> auditHistory,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class __$$MarksDtoImplCopyWithImpl<$Res>
    extends _$MarksDtoCopyWithImpl<$Res, _$MarksDtoImpl>
    implements _$$MarksDtoImplCopyWith<$Res> {
  __$$MarksDtoImplCopyWithImpl(
      _$MarksDtoImpl _value, $Res Function(_$MarksDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarksDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? examinationId = null,
    Object? examScheduleId = null,
    Object? studentId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? teacherId = null,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? maximumMarks = null,
    Object? marksObtained = freezed,
    Object? resultStatus = null,
    Object? status = null,
    Object? grade = freezed,
    Object? remarks = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? auditHistory = null,
    Object? isActive = null,
    Object? version = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$MarksDtoImpl(
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
      examinationId: null == examinationId
          ? _value.examinationId
          : examinationId // ignore: cast_nullable_to_non_nullable
              as String,
      examScheduleId: null == examScheduleId
          ? _value.examScheduleId
          : examScheduleId // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
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
      maximumMarks: null == maximumMarks
          ? _value.maximumMarks
          : maximumMarks // ignore: cast_nullable_to_non_nullable
              as int,
      marksObtained: freezed == marksObtained
          ? _value.marksObtained
          : marksObtained // ignore: cast_nullable_to_non_nullable
              as double?,
      resultStatus: null == resultStatus
          ? _value.resultStatus
          : resultStatus // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      grade: freezed == grade
          ? _value.grade
          : grade // ignore: cast_nullable_to_non_nullable
              as String?,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value._aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      auditHistory: null == auditHistory
          ? _value._auditHistory
          : auditHistory // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
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
class _$MarksDtoImpl extends _MarksDto {
  const _$MarksDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'examination_id') required this.examinationId,
      @JsonKey(name: 'exam_schedule_id') required this.examScheduleId,
      @JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required this.teacherSubjectAssignmentId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'subject_id') required this.subjectId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'maximum_marks') required this.maximumMarks,
      @JsonKey(name: 'marks_obtained') this.marksObtained,
      @JsonKey(name: 'result_status') required this.resultStatus,
      required this.status,
      this.grade,
      this.remarks,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'audit_history') required final List<dynamic> auditHistory,
      @JsonKey(name: 'is_active') required this.isActive,
      required this.version,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt})
      : _settings = settings,
        _aiMetrics = aiMetrics,
        _auditHistory = auditHistory,
        super._();

  factory _$MarksDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarksDtoImplFromJson(json);

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
  @JsonKey(name: 'examination_id')
  final String examinationId;
  @override
  @JsonKey(name: 'exam_schedule_id')
  final String examScheduleId;
  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'teacher_subject_assignment_id')
  final String teacherSubjectAssignmentId;
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
  @JsonKey(name: 'maximum_marks')
  final int maximumMarks;
  @override
  @JsonKey(name: 'marks_obtained')
  final double? marksObtained;
  @override
  @JsonKey(name: 'result_status')
  final String resultStatus;
  @override
  final String status;
  @override
  final String? grade;
  @override
  final String? remarks;
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

  final List<dynamic> _auditHistory;
  @override
  @JsonKey(name: 'audit_history')
  List<dynamic> get auditHistory {
    if (_auditHistory is EqualUnmodifiableListView) return _auditHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_auditHistory);
  }

  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
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
    return 'MarksDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, examinationId: $examinationId, examScheduleId: $examScheduleId, studentId: $studentId, teacherSubjectAssignmentId: $teacherSubjectAssignmentId, teacherId: $teacherId, subjectId: $subjectId, classId: $classId, sectionId: $sectionId, maximumMarks: $maximumMarks, marksObtained: $marksObtained, resultStatus: $resultStatus, status: $status, grade: $grade, remarks: $remarks, settings: $settings, aiMetrics: $aiMetrics, auditHistory: $auditHistory, isActive: $isActive, version: $version, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarksDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.examinationId, examinationId) ||
                other.examinationId == examinationId) &&
            (identical(other.examScheduleId, examScheduleId) ||
                other.examScheduleId == examScheduleId) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.teacherSubjectAssignmentId,
                    teacherSubjectAssignmentId) ||
                other.teacherSubjectAssignmentId ==
                    teacherSubjectAssignmentId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.maximumMarks, maximumMarks) ||
                other.maximumMarks == maximumMarks) &&
            (identical(other.marksObtained, marksObtained) ||
                other.marksObtained == marksObtained) &&
            (identical(other.resultStatus, resultStatus) ||
                other.resultStatus == resultStatus) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.grade, grade) || other.grade == grade) &&
            (identical(other.remarks, remarks) || other.remarks == remarks) &&
            const DeepCollectionEquality().equals(other._settings, _settings) &&
            const DeepCollectionEquality()
                .equals(other._aiMetrics, _aiMetrics) &&
            const DeepCollectionEquality()
                .equals(other._auditHistory, _auditHistory) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
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
        examinationId,
        examScheduleId,
        studentId,
        teacherSubjectAssignmentId,
        teacherId,
        subjectId,
        classId,
        sectionId,
        maximumMarks,
        marksObtained,
        resultStatus,
        status,
        grade,
        remarks,
        const DeepCollectionEquality().hash(_settings),
        const DeepCollectionEquality().hash(_aiMetrics),
        const DeepCollectionEquality().hash(_auditHistory),
        isActive,
        version,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of MarksDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarksDtoImplCopyWith<_$MarksDtoImpl> get copyWith =>
      __$$MarksDtoImplCopyWithImpl<_$MarksDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarksDtoImplToJson(
      this,
    );
  }
}

abstract class _MarksDto extends MarksDto {
  const factory _MarksDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'examination_id') required final String examinationId,
      @JsonKey(name: 'exam_schedule_id') required final String examScheduleId,
      @JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required final String teacherSubjectAssignmentId,
      @JsonKey(name: 'teacher_id') required final String teacherId,
      @JsonKey(name: 'subject_id') required final String subjectId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'maximum_marks') required final int maximumMarks,
      @JsonKey(name: 'marks_obtained') final double? marksObtained,
      @JsonKey(name: 'result_status') required final String resultStatus,
      required final String status,
      final String? grade,
      final String? remarks,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'audit_history') required final List<dynamic> auditHistory,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final int version,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'updated_at')
      required final String updatedAt}) = _$MarksDtoImpl;
  const _MarksDto._() : super._();

  factory _MarksDto.fromJson(Map<String, dynamic> json) =
      _$MarksDtoImpl.fromJson;

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
  @JsonKey(name: 'examination_id')
  String get examinationId;
  @override
  @JsonKey(name: 'exam_schedule_id')
  String get examScheduleId;
  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId;
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
  @JsonKey(name: 'maximum_marks')
  int get maximumMarks;
  @override
  @JsonKey(name: 'marks_obtained')
  double? get marksObtained;
  @override
  @JsonKey(name: 'result_status')
  String get resultStatus;
  @override
  String get status;
  @override
  String? get grade;
  @override
  String? get remarks;
  @override
  Map<String, dynamic> get settings;
  @override
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics;
  @override
  @JsonKey(name: 'audit_history')
  List<dynamic> get auditHistory;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  int get version;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  String get updatedAt;

  /// Create a copy of MarksDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarksDtoImplCopyWith<_$MarksDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
