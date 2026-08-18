// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_card_preview_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReportCardSubjectMarkRowDto _$ReportCardSubjectMarkRowDtoFromJson(
    Map<String, dynamic> json) {
  return _ReportCardSubjectMarkRowDto.fromJson(json);
}

/// @nodoc
mixin _$ReportCardSubjectMarkRowDto {
  @JsonKey(name: 'subject_name')
  String get subjectName => throw _privateConstructorUsedError;
  @JsonKey(name: 'maximum_marks')
  int get maximumMarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'marks_obtained')
  double? get marksObtained => throw _privateConstructorUsedError;
  @JsonKey(name: 'result_status')
  String get resultStatus => throw _privateConstructorUsedError;
  String get grade => throw _privateConstructorUsedError;
  String? get remarks => throw _privateConstructorUsedError;

  /// Serializes this ReportCardSubjectMarkRowDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReportCardSubjectMarkRowDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportCardSubjectMarkRowDtoCopyWith<ReportCardSubjectMarkRowDto>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportCardSubjectMarkRowDtoCopyWith<$Res> {
  factory $ReportCardSubjectMarkRowDtoCopyWith(
          ReportCardSubjectMarkRowDto value,
          $Res Function(ReportCardSubjectMarkRowDto) then) =
      _$ReportCardSubjectMarkRowDtoCopyWithImpl<$Res,
          ReportCardSubjectMarkRowDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'maximum_marks') int maximumMarks,
      @JsonKey(name: 'marks_obtained') double? marksObtained,
      @JsonKey(name: 'result_status') String resultStatus,
      String grade,
      String? remarks});
}

/// @nodoc
class _$ReportCardSubjectMarkRowDtoCopyWithImpl<$Res,
        $Val extends ReportCardSubjectMarkRowDto>
    implements $ReportCardSubjectMarkRowDtoCopyWith<$Res> {
  _$ReportCardSubjectMarkRowDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportCardSubjectMarkRowDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subjectName = null,
    Object? maximumMarks = null,
    Object? marksObtained = freezed,
    Object? resultStatus = null,
    Object? grade = null,
    Object? remarks = freezed,
  }) {
    return _then(_value.copyWith(
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
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
      grade: null == grade
          ? _value.grade
          : grade // ignore: cast_nullable_to_non_nullable
              as String,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReportCardSubjectMarkRowDtoImplCopyWith<$Res>
    implements $ReportCardSubjectMarkRowDtoCopyWith<$Res> {
  factory _$$ReportCardSubjectMarkRowDtoImplCopyWith(
          _$ReportCardSubjectMarkRowDtoImpl value,
          $Res Function(_$ReportCardSubjectMarkRowDtoImpl) then) =
      __$$ReportCardSubjectMarkRowDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'maximum_marks') int maximumMarks,
      @JsonKey(name: 'marks_obtained') double? marksObtained,
      @JsonKey(name: 'result_status') String resultStatus,
      String grade,
      String? remarks});
}

/// @nodoc
class __$$ReportCardSubjectMarkRowDtoImplCopyWithImpl<$Res>
    extends _$ReportCardSubjectMarkRowDtoCopyWithImpl<$Res,
        _$ReportCardSubjectMarkRowDtoImpl>
    implements _$$ReportCardSubjectMarkRowDtoImplCopyWith<$Res> {
  __$$ReportCardSubjectMarkRowDtoImplCopyWithImpl(
      _$ReportCardSubjectMarkRowDtoImpl _value,
      $Res Function(_$ReportCardSubjectMarkRowDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReportCardSubjectMarkRowDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subjectName = null,
    Object? maximumMarks = null,
    Object? marksObtained = freezed,
    Object? resultStatus = null,
    Object? grade = null,
    Object? remarks = freezed,
  }) {
    return _then(_$ReportCardSubjectMarkRowDtoImpl(
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
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
      grade: null == grade
          ? _value.grade
          : grade // ignore: cast_nullable_to_non_nullable
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
class _$ReportCardSubjectMarkRowDtoImpl extends _ReportCardSubjectMarkRowDto {
  const _$ReportCardSubjectMarkRowDtoImpl(
      {@JsonKey(name: 'subject_name') required this.subjectName,
      @JsonKey(name: 'maximum_marks') required this.maximumMarks,
      @JsonKey(name: 'marks_obtained') this.marksObtained,
      @JsonKey(name: 'result_status') required this.resultStatus,
      required this.grade,
      this.remarks})
      : super._();

  factory _$ReportCardSubjectMarkRowDtoImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$ReportCardSubjectMarkRowDtoImplFromJson(json);

  @override
  @JsonKey(name: 'subject_name')
  final String subjectName;
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
  final String grade;
  @override
  final String? remarks;

  @override
  String toString() {
    return 'ReportCardSubjectMarkRowDto(subjectName: $subjectName, maximumMarks: $maximumMarks, marksObtained: $marksObtained, resultStatus: $resultStatus, grade: $grade, remarks: $remarks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportCardSubjectMarkRowDtoImpl &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.maximumMarks, maximumMarks) ||
                other.maximumMarks == maximumMarks) &&
            (identical(other.marksObtained, marksObtained) ||
                other.marksObtained == marksObtained) &&
            (identical(other.resultStatus, resultStatus) ||
                other.resultStatus == resultStatus) &&
            (identical(other.grade, grade) || other.grade == grade) &&
            (identical(other.remarks, remarks) || other.remarks == remarks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, subjectName, maximumMarks,
      marksObtained, resultStatus, grade, remarks);

  /// Create a copy of ReportCardSubjectMarkRowDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportCardSubjectMarkRowDtoImplCopyWith<_$ReportCardSubjectMarkRowDtoImpl>
      get copyWith => __$$ReportCardSubjectMarkRowDtoImplCopyWithImpl<
          _$ReportCardSubjectMarkRowDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReportCardSubjectMarkRowDtoImplToJson(
      this,
    );
  }
}

abstract class _ReportCardSubjectMarkRowDto
    extends ReportCardSubjectMarkRowDto {
  const factory _ReportCardSubjectMarkRowDto(
      {@JsonKey(name: 'subject_name') required final String subjectName,
      @JsonKey(name: 'maximum_marks') required final int maximumMarks,
      @JsonKey(name: 'marks_obtained') final double? marksObtained,
      @JsonKey(name: 'result_status') required final String resultStatus,
      required final String grade,
      final String? remarks}) = _$ReportCardSubjectMarkRowDtoImpl;
  const _ReportCardSubjectMarkRowDto._() : super._();

  factory _ReportCardSubjectMarkRowDto.fromJson(Map<String, dynamic> json) =
      _$ReportCardSubjectMarkRowDtoImpl.fromJson;

  @override
  @JsonKey(name: 'subject_name')
  String get subjectName;
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
  String get grade;
  @override
  String? get remarks;

  /// Create a copy of ReportCardSubjectMarkRowDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportCardSubjectMarkRowDtoImplCopyWith<_$ReportCardSubjectMarkRowDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}

ReportCardPreviewDto _$ReportCardPreviewDtoFromJson(Map<String, dynamic> json) {
  return _ReportCardPreviewDto.fromJson(json);
}

/// @nodoc
mixin _$ReportCardPreviewDto {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_name')
  String get studentName => throw _privateConstructorUsedError;
  @JsonKey(name: 'admission_number')
  String get admissionNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'roll_number')
  String get rollNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_name')
  String get className => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_name')
  String get sectionName => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_total')
  int get attendanceTotal => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_present')
  int get attendancePresent => throw _privateConstructorUsedError;
  @JsonKey(name: 'attendance_percentage')
  double get attendancePercentage => throw _privateConstructorUsedError;
  @JsonKey(name: 'overall_percentage')
  double get overallPercentage => throw _privateConstructorUsedError;
  @JsonKey(name: 'overall_grade')
  String get overallGrade => throw _privateConstructorUsedError;
  @JsonKey(name: 'promotion_status')
  String get promotionStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_marks')
  List<ReportCardSubjectMarkRowDto> get subjectMarks =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_remarks')
  String? get teacherRemarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'principal_remarks')
  String? get principalRemarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_narrative')
  String get aiNarrative => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_valid')
  bool get isValid => throw _privateConstructorUsedError;
  @JsonKey(name: 'missing_reasons')
  List<String> get missingReasons => throw _privateConstructorUsedError;

  /// Serializes this ReportCardPreviewDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReportCardPreviewDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportCardPreviewDtoCopyWith<ReportCardPreviewDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportCardPreviewDtoCopyWith<$Res> {
  factory $ReportCardPreviewDtoCopyWith(ReportCardPreviewDto value,
          $Res Function(ReportCardPreviewDto) then) =
      _$ReportCardPreviewDtoCopyWithImpl<$Res, ReportCardPreviewDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'student_name') String studentName,
      @JsonKey(name: 'admission_number') String admissionNumber,
      @JsonKey(name: 'roll_number') String rollNumber,
      @JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'section_name') String sectionName,
      @JsonKey(name: 'attendance_total') int attendanceTotal,
      @JsonKey(name: 'attendance_present') int attendancePresent,
      @JsonKey(name: 'attendance_percentage') double attendancePercentage,
      @JsonKey(name: 'overall_percentage') double overallPercentage,
      @JsonKey(name: 'overall_grade') String overallGrade,
      @JsonKey(name: 'promotion_status') String promotionStatus,
      @JsonKey(name: 'subject_marks')
      List<ReportCardSubjectMarkRowDto> subjectMarks,
      @JsonKey(name: 'teacher_remarks') String? teacherRemarks,
      @JsonKey(name: 'principal_remarks') String? principalRemarks,
      @JsonKey(name: 'ai_narrative') String aiNarrative,
      @JsonKey(name: 'is_valid') bool isValid,
      @JsonKey(name: 'missing_reasons') List<String> missingReasons});
}

/// @nodoc
class _$ReportCardPreviewDtoCopyWithImpl<$Res,
        $Val extends ReportCardPreviewDto>
    implements $ReportCardPreviewDtoCopyWith<$Res> {
  _$ReportCardPreviewDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportCardPreviewDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? studentName = null,
    Object? admissionNumber = null,
    Object? rollNumber = null,
    Object? className = null,
    Object? sectionName = null,
    Object? attendanceTotal = null,
    Object? attendancePresent = null,
    Object? attendancePercentage = null,
    Object? overallPercentage = null,
    Object? overallGrade = null,
    Object? promotionStatus = null,
    Object? subjectMarks = null,
    Object? teacherRemarks = freezed,
    Object? principalRemarks = freezed,
    Object? aiNarrative = null,
    Object? isValid = null,
    Object? missingReasons = null,
  }) {
    return _then(_value.copyWith(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      studentName: null == studentName
          ? _value.studentName
          : studentName // ignore: cast_nullable_to_non_nullable
              as String,
      admissionNumber: null == admissionNumber
          ? _value.admissionNumber
          : admissionNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
      sectionName: null == sectionName
          ? _value.sectionName
          : sectionName // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceTotal: null == attendanceTotal
          ? _value.attendanceTotal
          : attendanceTotal // ignore: cast_nullable_to_non_nullable
              as int,
      attendancePresent: null == attendancePresent
          ? _value.attendancePresent
          : attendancePresent // ignore: cast_nullable_to_non_nullable
              as int,
      attendancePercentage: null == attendancePercentage
          ? _value.attendancePercentage
          : attendancePercentage // ignore: cast_nullable_to_non_nullable
              as double,
      overallPercentage: null == overallPercentage
          ? _value.overallPercentage
          : overallPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      overallGrade: null == overallGrade
          ? _value.overallGrade
          : overallGrade // ignore: cast_nullable_to_non_nullable
              as String,
      promotionStatus: null == promotionStatus
          ? _value.promotionStatus
          : promotionStatus // ignore: cast_nullable_to_non_nullable
              as String,
      subjectMarks: null == subjectMarks
          ? _value.subjectMarks
          : subjectMarks // ignore: cast_nullable_to_non_nullable
              as List<ReportCardSubjectMarkRowDto>,
      teacherRemarks: freezed == teacherRemarks
          ? _value.teacherRemarks
          : teacherRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      principalRemarks: freezed == principalRemarks
          ? _value.principalRemarks
          : principalRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      aiNarrative: null == aiNarrative
          ? _value.aiNarrative
          : aiNarrative // ignore: cast_nullable_to_non_nullable
              as String,
      isValid: null == isValid
          ? _value.isValid
          : isValid // ignore: cast_nullable_to_non_nullable
              as bool,
      missingReasons: null == missingReasons
          ? _value.missingReasons
          : missingReasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReportCardPreviewDtoImplCopyWith<$Res>
    implements $ReportCardPreviewDtoCopyWith<$Res> {
  factory _$$ReportCardPreviewDtoImplCopyWith(_$ReportCardPreviewDtoImpl value,
          $Res Function(_$ReportCardPreviewDtoImpl) then) =
      __$$ReportCardPreviewDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'student_name') String studentName,
      @JsonKey(name: 'admission_number') String admissionNumber,
      @JsonKey(name: 'roll_number') String rollNumber,
      @JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'section_name') String sectionName,
      @JsonKey(name: 'attendance_total') int attendanceTotal,
      @JsonKey(name: 'attendance_present') int attendancePresent,
      @JsonKey(name: 'attendance_percentage') double attendancePercentage,
      @JsonKey(name: 'overall_percentage') double overallPercentage,
      @JsonKey(name: 'overall_grade') String overallGrade,
      @JsonKey(name: 'promotion_status') String promotionStatus,
      @JsonKey(name: 'subject_marks')
      List<ReportCardSubjectMarkRowDto> subjectMarks,
      @JsonKey(name: 'teacher_remarks') String? teacherRemarks,
      @JsonKey(name: 'principal_remarks') String? principalRemarks,
      @JsonKey(name: 'ai_narrative') String aiNarrative,
      @JsonKey(name: 'is_valid') bool isValid,
      @JsonKey(name: 'missing_reasons') List<String> missingReasons});
}

/// @nodoc
class __$$ReportCardPreviewDtoImplCopyWithImpl<$Res>
    extends _$ReportCardPreviewDtoCopyWithImpl<$Res, _$ReportCardPreviewDtoImpl>
    implements _$$ReportCardPreviewDtoImplCopyWith<$Res> {
  __$$ReportCardPreviewDtoImplCopyWithImpl(_$ReportCardPreviewDtoImpl _value,
      $Res Function(_$ReportCardPreviewDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReportCardPreviewDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? studentName = null,
    Object? admissionNumber = null,
    Object? rollNumber = null,
    Object? className = null,
    Object? sectionName = null,
    Object? attendanceTotal = null,
    Object? attendancePresent = null,
    Object? attendancePercentage = null,
    Object? overallPercentage = null,
    Object? overallGrade = null,
    Object? promotionStatus = null,
    Object? subjectMarks = null,
    Object? teacherRemarks = freezed,
    Object? principalRemarks = freezed,
    Object? aiNarrative = null,
    Object? isValid = null,
    Object? missingReasons = null,
  }) {
    return _then(_$ReportCardPreviewDtoImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      studentName: null == studentName
          ? _value.studentName
          : studentName // ignore: cast_nullable_to_non_nullable
              as String,
      admissionNumber: null == admissionNumber
          ? _value.admissionNumber
          : admissionNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
      sectionName: null == sectionName
          ? _value.sectionName
          : sectionName // ignore: cast_nullable_to_non_nullable
              as String,
      attendanceTotal: null == attendanceTotal
          ? _value.attendanceTotal
          : attendanceTotal // ignore: cast_nullable_to_non_nullable
              as int,
      attendancePresent: null == attendancePresent
          ? _value.attendancePresent
          : attendancePresent // ignore: cast_nullable_to_non_nullable
              as int,
      attendancePercentage: null == attendancePercentage
          ? _value.attendancePercentage
          : attendancePercentage // ignore: cast_nullable_to_non_nullable
              as double,
      overallPercentage: null == overallPercentage
          ? _value.overallPercentage
          : overallPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      overallGrade: null == overallGrade
          ? _value.overallGrade
          : overallGrade // ignore: cast_nullable_to_non_nullable
              as String,
      promotionStatus: null == promotionStatus
          ? _value.promotionStatus
          : promotionStatus // ignore: cast_nullable_to_non_nullable
              as String,
      subjectMarks: null == subjectMarks
          ? _value._subjectMarks
          : subjectMarks // ignore: cast_nullable_to_non_nullable
              as List<ReportCardSubjectMarkRowDto>,
      teacherRemarks: freezed == teacherRemarks
          ? _value.teacherRemarks
          : teacherRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      principalRemarks: freezed == principalRemarks
          ? _value.principalRemarks
          : principalRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      aiNarrative: null == aiNarrative
          ? _value.aiNarrative
          : aiNarrative // ignore: cast_nullable_to_non_nullable
              as String,
      isValid: null == isValid
          ? _value.isValid
          : isValid // ignore: cast_nullable_to_non_nullable
              as bool,
      missingReasons: null == missingReasons
          ? _value._missingReasons
          : missingReasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReportCardPreviewDtoImpl extends _ReportCardPreviewDto {
  const _$ReportCardPreviewDtoImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'student_name') required this.studentName,
      @JsonKey(name: 'admission_number') required this.admissionNumber,
      @JsonKey(name: 'roll_number') required this.rollNumber,
      @JsonKey(name: 'class_name') required this.className,
      @JsonKey(name: 'section_name') required this.sectionName,
      @JsonKey(name: 'attendance_total') required this.attendanceTotal,
      @JsonKey(name: 'attendance_present') required this.attendancePresent,
      @JsonKey(name: 'attendance_percentage')
      required this.attendancePercentage,
      @JsonKey(name: 'overall_percentage') required this.overallPercentage,
      @JsonKey(name: 'overall_grade') required this.overallGrade,
      @JsonKey(name: 'promotion_status') required this.promotionStatus,
      @JsonKey(name: 'subject_marks')
      required final List<ReportCardSubjectMarkRowDto> subjectMarks,
      @JsonKey(name: 'teacher_remarks') this.teacherRemarks,
      @JsonKey(name: 'principal_remarks') this.principalRemarks,
      @JsonKey(name: 'ai_narrative') required this.aiNarrative,
      @JsonKey(name: 'is_valid') required this.isValid,
      @JsonKey(name: 'missing_reasons')
      required final List<String> missingReasons})
      : _subjectMarks = subjectMarks,
        _missingReasons = missingReasons,
        super._();

  factory _$ReportCardPreviewDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReportCardPreviewDtoImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'student_name')
  final String studentName;
  @override
  @JsonKey(name: 'admission_number')
  final String admissionNumber;
  @override
  @JsonKey(name: 'roll_number')
  final String rollNumber;
  @override
  @JsonKey(name: 'class_name')
  final String className;
  @override
  @JsonKey(name: 'section_name')
  final String sectionName;
  @override
  @JsonKey(name: 'attendance_total')
  final int attendanceTotal;
  @override
  @JsonKey(name: 'attendance_present')
  final int attendancePresent;
  @override
  @JsonKey(name: 'attendance_percentage')
  final double attendancePercentage;
  @override
  @JsonKey(name: 'overall_percentage')
  final double overallPercentage;
  @override
  @JsonKey(name: 'overall_grade')
  final String overallGrade;
  @override
  @JsonKey(name: 'promotion_status')
  final String promotionStatus;
  final List<ReportCardSubjectMarkRowDto> _subjectMarks;
  @override
  @JsonKey(name: 'subject_marks')
  List<ReportCardSubjectMarkRowDto> get subjectMarks {
    if (_subjectMarks is EqualUnmodifiableListView) return _subjectMarks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subjectMarks);
  }

  @override
  @JsonKey(name: 'teacher_remarks')
  final String? teacherRemarks;
  @override
  @JsonKey(name: 'principal_remarks')
  final String? principalRemarks;
  @override
  @JsonKey(name: 'ai_narrative')
  final String aiNarrative;
  @override
  @JsonKey(name: 'is_valid')
  final bool isValid;
  final List<String> _missingReasons;
  @override
  @JsonKey(name: 'missing_reasons')
  List<String> get missingReasons {
    if (_missingReasons is EqualUnmodifiableListView) return _missingReasons;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_missingReasons);
  }

  @override
  String toString() {
    return 'ReportCardPreviewDto(studentId: $studentId, studentName: $studentName, admissionNumber: $admissionNumber, rollNumber: $rollNumber, className: $className, sectionName: $sectionName, attendanceTotal: $attendanceTotal, attendancePresent: $attendancePresent, attendancePercentage: $attendancePercentage, overallPercentage: $overallPercentage, overallGrade: $overallGrade, promotionStatus: $promotionStatus, subjectMarks: $subjectMarks, teacherRemarks: $teacherRemarks, principalRemarks: $principalRemarks, aiNarrative: $aiNarrative, isValid: $isValid, missingReasons: $missingReasons)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportCardPreviewDtoImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.studentName, studentName) ||
                other.studentName == studentName) &&
            (identical(other.admissionNumber, admissionNumber) ||
                other.admissionNumber == admissionNumber) &&
            (identical(other.rollNumber, rollNumber) ||
                other.rollNumber == rollNumber) &&
            (identical(other.className, className) ||
                other.className == className) &&
            (identical(other.sectionName, sectionName) ||
                other.sectionName == sectionName) &&
            (identical(other.attendanceTotal, attendanceTotal) ||
                other.attendanceTotal == attendanceTotal) &&
            (identical(other.attendancePresent, attendancePresent) ||
                other.attendancePresent == attendancePresent) &&
            (identical(other.attendancePercentage, attendancePercentage) ||
                other.attendancePercentage == attendancePercentage) &&
            (identical(other.overallPercentage, overallPercentage) ||
                other.overallPercentage == overallPercentage) &&
            (identical(other.overallGrade, overallGrade) ||
                other.overallGrade == overallGrade) &&
            (identical(other.promotionStatus, promotionStatus) ||
                other.promotionStatus == promotionStatus) &&
            const DeepCollectionEquality()
                .equals(other._subjectMarks, _subjectMarks) &&
            (identical(other.teacherRemarks, teacherRemarks) ||
                other.teacherRemarks == teacherRemarks) &&
            (identical(other.principalRemarks, principalRemarks) ||
                other.principalRemarks == principalRemarks) &&
            (identical(other.aiNarrative, aiNarrative) ||
                other.aiNarrative == aiNarrative) &&
            (identical(other.isValid, isValid) || other.isValid == isValid) &&
            const DeepCollectionEquality()
                .equals(other._missingReasons, _missingReasons));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      studentId,
      studentName,
      admissionNumber,
      rollNumber,
      className,
      sectionName,
      attendanceTotal,
      attendancePresent,
      attendancePercentage,
      overallPercentage,
      overallGrade,
      promotionStatus,
      const DeepCollectionEquality().hash(_subjectMarks),
      teacherRemarks,
      principalRemarks,
      aiNarrative,
      isValid,
      const DeepCollectionEquality().hash(_missingReasons));

  /// Create a copy of ReportCardPreviewDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportCardPreviewDtoImplCopyWith<_$ReportCardPreviewDtoImpl>
      get copyWith =>
          __$$ReportCardPreviewDtoImplCopyWithImpl<_$ReportCardPreviewDtoImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReportCardPreviewDtoImplToJson(
      this,
    );
  }
}

abstract class _ReportCardPreviewDto extends ReportCardPreviewDto {
  const factory _ReportCardPreviewDto(
      {@JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'student_name') required final String studentName,
      @JsonKey(name: 'admission_number') required final String admissionNumber,
      @JsonKey(name: 'roll_number') required final String rollNumber,
      @JsonKey(name: 'class_name') required final String className,
      @JsonKey(name: 'section_name') required final String sectionName,
      @JsonKey(name: 'attendance_total') required final int attendanceTotal,
      @JsonKey(name: 'attendance_present') required final int attendancePresent,
      @JsonKey(name: 'attendance_percentage')
      required final double attendancePercentage,
      @JsonKey(name: 'overall_percentage')
      required final double overallPercentage,
      @JsonKey(name: 'overall_grade') required final String overallGrade,
      @JsonKey(name: 'promotion_status') required final String promotionStatus,
      @JsonKey(name: 'subject_marks')
      required final List<ReportCardSubjectMarkRowDto> subjectMarks,
      @JsonKey(name: 'teacher_remarks') final String? teacherRemarks,
      @JsonKey(name: 'principal_remarks') final String? principalRemarks,
      @JsonKey(name: 'ai_narrative') required final String aiNarrative,
      @JsonKey(name: 'is_valid') required final bool isValid,
      @JsonKey(name: 'missing_reasons')
      required final List<String> missingReasons}) = _$ReportCardPreviewDtoImpl;
  const _ReportCardPreviewDto._() : super._();

  factory _ReportCardPreviewDto.fromJson(Map<String, dynamic> json) =
      _$ReportCardPreviewDtoImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'student_name')
  String get studentName;
  @override
  @JsonKey(name: 'admission_number')
  String get admissionNumber;
  @override
  @JsonKey(name: 'roll_number')
  String get rollNumber;
  @override
  @JsonKey(name: 'class_name')
  String get className;
  @override
  @JsonKey(name: 'section_name')
  String get sectionName;
  @override
  @JsonKey(name: 'attendance_total')
  int get attendanceTotal;
  @override
  @JsonKey(name: 'attendance_present')
  int get attendancePresent;
  @override
  @JsonKey(name: 'attendance_percentage')
  double get attendancePercentage;
  @override
  @JsonKey(name: 'overall_percentage')
  double get overallPercentage;
  @override
  @JsonKey(name: 'overall_grade')
  String get overallGrade;
  @override
  @JsonKey(name: 'promotion_status')
  String get promotionStatus;
  @override
  @JsonKey(name: 'subject_marks')
  List<ReportCardSubjectMarkRowDto> get subjectMarks;
  @override
  @JsonKey(name: 'teacher_remarks')
  String? get teacherRemarks;
  @override
  @JsonKey(name: 'principal_remarks')
  String? get principalRemarks;
  @override
  @JsonKey(name: 'ai_narrative')
  String get aiNarrative;
  @override
  @JsonKey(name: 'is_valid')
  bool get isValid;
  @override
  @JsonKey(name: 'missing_reasons')
  List<String> get missingReasons;

  /// Create a copy of ReportCardPreviewDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportCardPreviewDtoImplCopyWith<_$ReportCardPreviewDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
