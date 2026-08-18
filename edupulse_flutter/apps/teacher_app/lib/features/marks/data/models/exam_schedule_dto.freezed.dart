// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_schedule_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExamScheduleDto _$ExamScheduleDtoFromJson(Map<String, dynamic> json) {
  return _ExamScheduleDto.fromJson(json);
}

/// @nodoc
mixin _$ExamScheduleDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'exam_id')
  String get examId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'exam_date')
  String get examDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  String get startTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_time')
  String get endTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_marks')
  int get maxMarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'pass_marks')
  int get passMarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'room_number')
  String? get roomNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;

  /// Serializes this ExamScheduleDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamScheduleDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamScheduleDtoCopyWith<ExamScheduleDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamScheduleDtoCopyWith<$Res> {
  factory $ExamScheduleDtoCopyWith(
          ExamScheduleDto value, $Res Function(ExamScheduleDto) then) =
      _$ExamScheduleDtoCopyWithImpl<$Res, ExamScheduleDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'exam_id') String examId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'exam_date') String examDate,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'max_marks') int maxMarks,
      @JsonKey(name: 'pass_marks') int passMarks,
      @JsonKey(name: 'room_number') String? roomNumber,
      @JsonKey(name: 'is_active') bool isActive,
      int version});
}

/// @nodoc
class _$ExamScheduleDtoCopyWithImpl<$Res, $Val extends ExamScheduleDto>
    implements $ExamScheduleDtoCopyWith<$Res> {
  _$ExamScheduleDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamScheduleDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? subjectId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? examDate = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? maxMarks = null,
    Object? passMarks = null,
    Object? roomNumber = freezed,
    Object? isActive = null,
    Object? version = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: null == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      maxMarks: null == maxMarks
          ? _value.maxMarks
          : maxMarks // ignore: cast_nullable_to_non_nullable
              as int,
      passMarks: null == passMarks
          ? _value.passMarks
          : passMarks // ignore: cast_nullable_to_non_nullable
              as int,
      roomNumber: freezed == roomNumber
          ? _value.roomNumber
          : roomNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamScheduleDtoImplCopyWith<$Res>
    implements $ExamScheduleDtoCopyWith<$Res> {
  factory _$$ExamScheduleDtoImplCopyWith(_$ExamScheduleDtoImpl value,
          $Res Function(_$ExamScheduleDtoImpl) then) =
      __$$ExamScheduleDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'exam_id') String examId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      String teacherSubjectAssignmentId,
      @JsonKey(name: 'exam_date') String examDate,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'max_marks') int maxMarks,
      @JsonKey(name: 'pass_marks') int passMarks,
      @JsonKey(name: 'room_number') String? roomNumber,
      @JsonKey(name: 'is_active') bool isActive,
      int version});
}

/// @nodoc
class __$$ExamScheduleDtoImplCopyWithImpl<$Res>
    extends _$ExamScheduleDtoCopyWithImpl<$Res, _$ExamScheduleDtoImpl>
    implements _$$ExamScheduleDtoImplCopyWith<$Res> {
  __$$ExamScheduleDtoImplCopyWithImpl(
      _$ExamScheduleDtoImpl _value, $Res Function(_$ExamScheduleDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamScheduleDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? subjectId = null,
    Object? teacherSubjectAssignmentId = null,
    Object? examDate = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? maxMarks = null,
    Object? passMarks = null,
    Object? roomNumber = freezed,
    Object? isActive = null,
    Object? version = null,
  }) {
    return _then(_$ExamScheduleDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherSubjectAssignmentId: null == teacherSubjectAssignmentId
          ? _value.teacherSubjectAssignmentId
          : teacherSubjectAssignmentId // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: null == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      maxMarks: null == maxMarks
          ? _value.maxMarks
          : maxMarks // ignore: cast_nullable_to_non_nullable
              as int,
      passMarks: null == passMarks
          ? _value.passMarks
          : passMarks // ignore: cast_nullable_to_non_nullable
              as int,
      roomNumber: freezed == roomNumber
          ? _value.roomNumber
          : roomNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamScheduleDtoImpl extends _ExamScheduleDto {
  const _$ExamScheduleDtoImpl(
      {required this.id,
      @JsonKey(name: 'exam_id') required this.examId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'subject_id') required this.subjectId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required this.teacherSubjectAssignmentId,
      @JsonKey(name: 'exam_date') required this.examDate,
      @JsonKey(name: 'start_time') required this.startTime,
      @JsonKey(name: 'end_time') required this.endTime,
      @JsonKey(name: 'max_marks') required this.maxMarks,
      @JsonKey(name: 'pass_marks') required this.passMarks,
      @JsonKey(name: 'room_number') this.roomNumber,
      @JsonKey(name: 'is_active') required this.isActive,
      required this.version})
      : super._();

  factory _$ExamScheduleDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamScheduleDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'exam_id')
  final String examId;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;
  @override
  @JsonKey(name: 'subject_id')
  final String subjectId;
  @override
  @JsonKey(name: 'teacher_subject_assignment_id')
  final String teacherSubjectAssignmentId;
  @override
  @JsonKey(name: 'exam_date')
  final String examDate;
  @override
  @JsonKey(name: 'start_time')
  final String startTime;
  @override
  @JsonKey(name: 'end_time')
  final String endTime;
  @override
  @JsonKey(name: 'max_marks')
  final int maxMarks;
  @override
  @JsonKey(name: 'pass_marks')
  final int passMarks;
  @override
  @JsonKey(name: 'room_number')
  final String? roomNumber;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  final int version;

  @override
  String toString() {
    return 'ExamScheduleDto(id: $id, examId: $examId, classId: $classId, sectionId: $sectionId, subjectId: $subjectId, teacherSubjectAssignmentId: $teacherSubjectAssignmentId, examDate: $examDate, startTime: $startTime, endTime: $endTime, maxMarks: $maxMarks, passMarks: $passMarks, roomNumber: $roomNumber, isActive: $isActive, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamScheduleDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.examId, examId) || other.examId == examId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.teacherSubjectAssignmentId,
                    teacherSubjectAssignmentId) ||
                other.teacherSubjectAssignmentId ==
                    teacherSubjectAssignmentId) &&
            (identical(other.examDate, examDate) ||
                other.examDate == examDate) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.maxMarks, maxMarks) ||
                other.maxMarks == maxMarks) &&
            (identical(other.passMarks, passMarks) ||
                other.passMarks == passMarks) &&
            (identical(other.roomNumber, roomNumber) ||
                other.roomNumber == roomNumber) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.version, version) || other.version == version));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      examId,
      classId,
      sectionId,
      subjectId,
      teacherSubjectAssignmentId,
      examDate,
      startTime,
      endTime,
      maxMarks,
      passMarks,
      roomNumber,
      isActive,
      version);

  /// Create a copy of ExamScheduleDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamScheduleDtoImplCopyWith<_$ExamScheduleDtoImpl> get copyWith =>
      __$$ExamScheduleDtoImplCopyWithImpl<_$ExamScheduleDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamScheduleDtoImplToJson(
      this,
    );
  }
}

abstract class _ExamScheduleDto extends ExamScheduleDto {
  const factory _ExamScheduleDto(
      {required final String id,
      @JsonKey(name: 'exam_id') required final String examId,
      @JsonKey(name: 'class_id') required final String classId,
      @JsonKey(name: 'section_id') required final String sectionId,
      @JsonKey(name: 'subject_id') required final String subjectId,
      @JsonKey(name: 'teacher_subject_assignment_id')
      required final String teacherSubjectAssignmentId,
      @JsonKey(name: 'exam_date') required final String examDate,
      @JsonKey(name: 'start_time') required final String startTime,
      @JsonKey(name: 'end_time') required final String endTime,
      @JsonKey(name: 'max_marks') required final int maxMarks,
      @JsonKey(name: 'pass_marks') required final int passMarks,
      @JsonKey(name: 'room_number') final String? roomNumber,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final int version}) = _$ExamScheduleDtoImpl;
  const _ExamScheduleDto._() : super._();

  factory _ExamScheduleDto.fromJson(Map<String, dynamic> json) =
      _$ExamScheduleDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'exam_id')
  String get examId;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;
  @override
  @JsonKey(name: 'subject_id')
  String get subjectId;
  @override
  @JsonKey(name: 'teacher_subject_assignment_id')
  String get teacherSubjectAssignmentId;
  @override
  @JsonKey(name: 'exam_date')
  String get examDate;
  @override
  @JsonKey(name: 'start_time')
  String get startTime;
  @override
  @JsonKey(name: 'end_time')
  String get endTime;
  @override
  @JsonKey(name: 'max_marks')
  int get maxMarks;
  @override
  @JsonKey(name: 'pass_marks')
  int get passMarks;
  @override
  @JsonKey(name: 'room_number')
  String? get roomNumber;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  int get version;

  /// Create a copy of ExamScheduleDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamScheduleDtoImplCopyWith<_$ExamScheduleDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
