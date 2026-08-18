// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marks_wizard_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StudentShortInfoDto _$StudentShortInfoDtoFromJson(Map<String, dynamic> json) {
  return _StudentShortInfoDto.fromJson(json);
}

/// @nodoc
mixin _$StudentShortInfoDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_name')
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_name')
  String get lastName => throw _privateConstructorUsedError;
  @JsonKey(name: 'roll_number')
  String get rollNumber => throw _privateConstructorUsedError;

  /// Serializes this StudentShortInfoDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudentShortInfoDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentShortInfoDtoCopyWith<StudentShortInfoDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentShortInfoDtoCopyWith<$Res> {
  factory $StudentShortInfoDtoCopyWith(
          StudentShortInfoDto value, $Res Function(StudentShortInfoDto) then) =
      _$StudentShortInfoDtoCopyWithImpl<$Res, StudentShortInfoDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'last_name') String lastName,
      @JsonKey(name: 'roll_number') String rollNumber});
}

/// @nodoc
class _$StudentShortInfoDtoCopyWithImpl<$Res, $Val extends StudentShortInfoDto>
    implements $StudentShortInfoDtoCopyWith<$Res> {
  _$StudentShortInfoDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudentShortInfoDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? rollNumber = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentShortInfoDtoImplCopyWith<$Res>
    implements $StudentShortInfoDtoCopyWith<$Res> {
  factory _$$StudentShortInfoDtoImplCopyWith(_$StudentShortInfoDtoImpl value,
          $Res Function(_$StudentShortInfoDtoImpl) then) =
      __$$StudentShortInfoDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'first_name') String firstName,
      @JsonKey(name: 'last_name') String lastName,
      @JsonKey(name: 'roll_number') String rollNumber});
}

/// @nodoc
class __$$StudentShortInfoDtoImplCopyWithImpl<$Res>
    extends _$StudentShortInfoDtoCopyWithImpl<$Res, _$StudentShortInfoDtoImpl>
    implements _$$StudentShortInfoDtoImplCopyWith<$Res> {
  __$$StudentShortInfoDtoImplCopyWithImpl(_$StudentShortInfoDtoImpl _value,
      $Res Function(_$StudentShortInfoDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudentShortInfoDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? rollNumber = null,
  }) {
    return _then(_$StudentShortInfoDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      rollNumber: null == rollNumber
          ? _value.rollNumber
          : rollNumber // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudentShortInfoDtoImpl extends _StudentShortInfoDto {
  const _$StudentShortInfoDtoImpl(
      {required this.id,
      @JsonKey(name: 'first_name') required this.firstName,
      @JsonKey(name: 'last_name') required this.lastName,
      @JsonKey(name: 'roll_number') required this.rollNumber})
      : super._();

  factory _$StudentShortInfoDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentShortInfoDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'first_name')
  final String firstName;
  @override
  @JsonKey(name: 'last_name')
  final String lastName;
  @override
  @JsonKey(name: 'roll_number')
  final String rollNumber;

  @override
  String toString() {
    return 'StudentShortInfoDto(id: $id, firstName: $firstName, lastName: $lastName, rollNumber: $rollNumber)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentShortInfoDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.rollNumber, rollNumber) ||
                other.rollNumber == rollNumber));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, firstName, lastName, rollNumber);

  /// Create a copy of StudentShortInfoDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentShortInfoDtoImplCopyWith<_$StudentShortInfoDtoImpl> get copyWith =>
      __$$StudentShortInfoDtoImplCopyWithImpl<_$StudentShortInfoDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentShortInfoDtoImplToJson(
      this,
    );
  }
}

abstract class _StudentShortInfoDto extends StudentShortInfoDto {
  const factory _StudentShortInfoDto(
          {required final String id,
          @JsonKey(name: 'first_name') required final String firstName,
          @JsonKey(name: 'last_name') required final String lastName,
          @JsonKey(name: 'roll_number') required final String rollNumber}) =
      _$StudentShortInfoDtoImpl;
  const _StudentShortInfoDto._() : super._();

  factory _StudentShortInfoDto.fromJson(Map<String, dynamic> json) =
      _$StudentShortInfoDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'first_name')
  String get firstName;
  @override
  @JsonKey(name: 'last_name')
  String get lastName;
  @override
  @JsonKey(name: 'roll_number')
  String get rollNumber;

  /// Create a copy of StudentShortInfoDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentShortInfoDtoImplCopyWith<_$StudentShortInfoDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MarkWizardItemDto _$MarkWizardItemDtoFromJson(Map<String, dynamic> json) {
  return _MarkWizardItemDto.fromJson(json);
}

/// @nodoc
mixin _$MarkWizardItemDto {
  StudentShortInfoDto get student => throw _privateConstructorUsedError;
  @JsonKey(name: 'mark_record')
  MarksDto? get markRecord => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_missing')
  bool get isMissing => throw _privateConstructorUsedError;

  /// Serializes this MarkWizardItemDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarkWizardItemDtoCopyWith<MarkWizardItemDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarkWizardItemDtoCopyWith<$Res> {
  factory $MarkWizardItemDtoCopyWith(
          MarkWizardItemDto value, $Res Function(MarkWizardItemDto) then) =
      _$MarkWizardItemDtoCopyWithImpl<$Res, MarkWizardItemDto>;
  @useResult
  $Res call(
      {StudentShortInfoDto student,
      @JsonKey(name: 'mark_record') MarksDto? markRecord,
      @JsonKey(name: 'is_missing') bool isMissing});

  $StudentShortInfoDtoCopyWith<$Res> get student;
  $MarksDtoCopyWith<$Res>? get markRecord;
}

/// @nodoc
class _$MarkWizardItemDtoCopyWithImpl<$Res, $Val extends MarkWizardItemDto>
    implements $MarkWizardItemDtoCopyWith<$Res> {
  _$MarkWizardItemDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? student = null,
    Object? markRecord = freezed,
    Object? isMissing = null,
  }) {
    return _then(_value.copyWith(
      student: null == student
          ? _value.student
          : student // ignore: cast_nullable_to_non_nullable
              as StudentShortInfoDto,
      markRecord: freezed == markRecord
          ? _value.markRecord
          : markRecord // ignore: cast_nullable_to_non_nullable
              as MarksDto?,
      isMissing: null == isMissing
          ? _value.isMissing
          : isMissing // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StudentShortInfoDtoCopyWith<$Res> get student {
    return $StudentShortInfoDtoCopyWith<$Res>(_value.student, (value) {
      return _then(_value.copyWith(student: value) as $Val);
    });
  }

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MarksDtoCopyWith<$Res>? get markRecord {
    if (_value.markRecord == null) {
      return null;
    }

    return $MarksDtoCopyWith<$Res>(_value.markRecord!, (value) {
      return _then(_value.copyWith(markRecord: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MarkWizardItemDtoImplCopyWith<$Res>
    implements $MarkWizardItemDtoCopyWith<$Res> {
  factory _$$MarkWizardItemDtoImplCopyWith(_$MarkWizardItemDtoImpl value,
          $Res Function(_$MarkWizardItemDtoImpl) then) =
      __$$MarkWizardItemDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {StudentShortInfoDto student,
      @JsonKey(name: 'mark_record') MarksDto? markRecord,
      @JsonKey(name: 'is_missing') bool isMissing});

  @override
  $StudentShortInfoDtoCopyWith<$Res> get student;
  @override
  $MarksDtoCopyWith<$Res>? get markRecord;
}

/// @nodoc
class __$$MarkWizardItemDtoImplCopyWithImpl<$Res>
    extends _$MarkWizardItemDtoCopyWithImpl<$Res, _$MarkWizardItemDtoImpl>
    implements _$$MarkWizardItemDtoImplCopyWith<$Res> {
  __$$MarkWizardItemDtoImplCopyWithImpl(_$MarkWizardItemDtoImpl _value,
      $Res Function(_$MarkWizardItemDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? student = null,
    Object? markRecord = freezed,
    Object? isMissing = null,
  }) {
    return _then(_$MarkWizardItemDtoImpl(
      student: null == student
          ? _value.student
          : student // ignore: cast_nullable_to_non_nullable
              as StudentShortInfoDto,
      markRecord: freezed == markRecord
          ? _value.markRecord
          : markRecord // ignore: cast_nullable_to_non_nullable
              as MarksDto?,
      isMissing: null == isMissing
          ? _value.isMissing
          : isMissing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MarkWizardItemDtoImpl extends _MarkWizardItemDto {
  const _$MarkWizardItemDtoImpl(
      {required this.student,
      @JsonKey(name: 'mark_record') this.markRecord,
      @JsonKey(name: 'is_missing') required this.isMissing})
      : super._();

  factory _$MarkWizardItemDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarkWizardItemDtoImplFromJson(json);

  @override
  final StudentShortInfoDto student;
  @override
  @JsonKey(name: 'mark_record')
  final MarksDto? markRecord;
  @override
  @JsonKey(name: 'is_missing')
  final bool isMissing;

  @override
  String toString() {
    return 'MarkWizardItemDto(student: $student, markRecord: $markRecord, isMissing: $isMissing)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarkWizardItemDtoImpl &&
            (identical(other.student, student) || other.student == student) &&
            (identical(other.markRecord, markRecord) ||
                other.markRecord == markRecord) &&
            (identical(other.isMissing, isMissing) ||
                other.isMissing == isMissing));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, student, markRecord, isMissing);

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarkWizardItemDtoImplCopyWith<_$MarkWizardItemDtoImpl> get copyWith =>
      __$$MarkWizardItemDtoImplCopyWithImpl<_$MarkWizardItemDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarkWizardItemDtoImplToJson(
      this,
    );
  }
}

abstract class _MarkWizardItemDto extends MarkWizardItemDto {
  const factory _MarkWizardItemDto(
          {required final StudentShortInfoDto student,
          @JsonKey(name: 'mark_record') final MarksDto? markRecord,
          @JsonKey(name: 'is_missing') required final bool isMissing}) =
      _$MarkWizardItemDtoImpl;
  const _MarkWizardItemDto._() : super._();

  factory _MarkWizardItemDto.fromJson(Map<String, dynamic> json) =
      _$MarkWizardItemDtoImpl.fromJson;

  @override
  StudentShortInfoDto get student;
  @override
  @JsonKey(name: 'mark_record')
  MarksDto? get markRecord;
  @override
  @JsonKey(name: 'is_missing')
  bool get isMissing;

  /// Create a copy of MarkWizardItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarkWizardItemDtoImplCopyWith<_$MarkWizardItemDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MarksWizardDto _$MarksWizardDtoFromJson(Map<String, dynamic> json) {
  return _MarksWizardDto.fromJson(json);
}

/// @nodoc
mixin _$MarksWizardDto {
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'entered_count')
  int get enteredCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'missing_count')
  int get missingCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'average_score')
  double? get averageScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'highest_score')
  double? get highestScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'lowest_score')
  double? get lowestScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'missing_students')
  List<StudentShortInfoDto> get missingStudents =>
      throw _privateConstructorUsedError;
  List<MarkWizardItemDto> get entries => throw _privateConstructorUsedError;

  /// Serializes this MarksWizardDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarksWizardDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarksWizardDtoCopyWith<MarksWizardDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarksWizardDtoCopyWith<$Res> {
  factory $MarksWizardDtoCopyWith(
          MarksWizardDto value, $Res Function(MarksWizardDto) then) =
      _$MarksWizardDtoCopyWithImpl<$Res, MarksWizardDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'entered_count') int enteredCount,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'average_score') double? averageScore,
      @JsonKey(name: 'highest_score') double? highestScore,
      @JsonKey(name: 'lowest_score') double? lowestScore,
      @JsonKey(name: 'missing_students')
      List<StudentShortInfoDto> missingStudents,
      List<MarkWizardItemDto> entries});
}

/// @nodoc
class _$MarksWizardDtoCopyWithImpl<$Res, $Val extends MarksWizardDto>
    implements $MarksWizardDtoCopyWith<$Res> {
  _$MarksWizardDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarksWizardDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalStudents = null,
    Object? enteredCount = null,
    Object? missingCount = null,
    Object? averageScore = freezed,
    Object? highestScore = freezed,
    Object? lowestScore = freezed,
    Object? missingStudents = null,
    Object? entries = null,
  }) {
    return _then(_value.copyWith(
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      enteredCount: null == enteredCount
          ? _value.enteredCount
          : enteredCount // ignore: cast_nullable_to_non_nullable
              as int,
      missingCount: null == missingCount
          ? _value.missingCount
          : missingCount // ignore: cast_nullable_to_non_nullable
              as int,
      averageScore: freezed == averageScore
          ? _value.averageScore
          : averageScore // ignore: cast_nullable_to_non_nullable
              as double?,
      highestScore: freezed == highestScore
          ? _value.highestScore
          : highestScore // ignore: cast_nullable_to_non_nullable
              as double?,
      lowestScore: freezed == lowestScore
          ? _value.lowestScore
          : lowestScore // ignore: cast_nullable_to_non_nullable
              as double?,
      missingStudents: null == missingStudents
          ? _value.missingStudents
          : missingStudents // ignore: cast_nullable_to_non_nullable
              as List<StudentShortInfoDto>,
      entries: null == entries
          ? _value.entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<MarkWizardItemDto>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MarksWizardDtoImplCopyWith<$Res>
    implements $MarksWizardDtoCopyWith<$Res> {
  factory _$$MarksWizardDtoImplCopyWith(_$MarksWizardDtoImpl value,
          $Res Function(_$MarksWizardDtoImpl) then) =
      __$$MarksWizardDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'entered_count') int enteredCount,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'average_score') double? averageScore,
      @JsonKey(name: 'highest_score') double? highestScore,
      @JsonKey(name: 'lowest_score') double? lowestScore,
      @JsonKey(name: 'missing_students')
      List<StudentShortInfoDto> missingStudents,
      List<MarkWizardItemDto> entries});
}

/// @nodoc
class __$$MarksWizardDtoImplCopyWithImpl<$Res>
    extends _$MarksWizardDtoCopyWithImpl<$Res, _$MarksWizardDtoImpl>
    implements _$$MarksWizardDtoImplCopyWith<$Res> {
  __$$MarksWizardDtoImplCopyWithImpl(
      _$MarksWizardDtoImpl _value, $Res Function(_$MarksWizardDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarksWizardDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalStudents = null,
    Object? enteredCount = null,
    Object? missingCount = null,
    Object? averageScore = freezed,
    Object? highestScore = freezed,
    Object? lowestScore = freezed,
    Object? missingStudents = null,
    Object? entries = null,
  }) {
    return _then(_$MarksWizardDtoImpl(
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      enteredCount: null == enteredCount
          ? _value.enteredCount
          : enteredCount // ignore: cast_nullable_to_non_nullable
              as int,
      missingCount: null == missingCount
          ? _value.missingCount
          : missingCount // ignore: cast_nullable_to_non_nullable
              as int,
      averageScore: freezed == averageScore
          ? _value.averageScore
          : averageScore // ignore: cast_nullable_to_non_nullable
              as double?,
      highestScore: freezed == highestScore
          ? _value.highestScore
          : highestScore // ignore: cast_nullable_to_non_nullable
              as double?,
      lowestScore: freezed == lowestScore
          ? _value.lowestScore
          : lowestScore // ignore: cast_nullable_to_non_nullable
              as double?,
      missingStudents: null == missingStudents
          ? _value._missingStudents
          : missingStudents // ignore: cast_nullable_to_non_nullable
              as List<StudentShortInfoDto>,
      entries: null == entries
          ? _value._entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<MarkWizardItemDto>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MarksWizardDtoImpl extends _MarksWizardDto {
  const _$MarksWizardDtoImpl(
      {@JsonKey(name: 'total_students') required this.totalStudents,
      @JsonKey(name: 'entered_count') required this.enteredCount,
      @JsonKey(name: 'missing_count') required this.missingCount,
      @JsonKey(name: 'average_score') this.averageScore,
      @JsonKey(name: 'highest_score') this.highestScore,
      @JsonKey(name: 'lowest_score') this.lowestScore,
      @JsonKey(name: 'missing_students')
      required final List<StudentShortInfoDto> missingStudents,
      required final List<MarkWizardItemDto> entries})
      : _missingStudents = missingStudents,
        _entries = entries,
        super._();

  factory _$MarksWizardDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarksWizardDtoImplFromJson(json);

  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'entered_count')
  final int enteredCount;
  @override
  @JsonKey(name: 'missing_count')
  final int missingCount;
  @override
  @JsonKey(name: 'average_score')
  final double? averageScore;
  @override
  @JsonKey(name: 'highest_score')
  final double? highestScore;
  @override
  @JsonKey(name: 'lowest_score')
  final double? lowestScore;
  final List<StudentShortInfoDto> _missingStudents;
  @override
  @JsonKey(name: 'missing_students')
  List<StudentShortInfoDto> get missingStudents {
    if (_missingStudents is EqualUnmodifiableListView) return _missingStudents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_missingStudents);
  }

  final List<MarkWizardItemDto> _entries;
  @override
  List<MarkWizardItemDto> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  String toString() {
    return 'MarksWizardDto(totalStudents: $totalStudents, enteredCount: $enteredCount, missingCount: $missingCount, averageScore: $averageScore, highestScore: $highestScore, lowestScore: $lowestScore, missingStudents: $missingStudents, entries: $entries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarksWizardDtoImpl &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.enteredCount, enteredCount) ||
                other.enteredCount == enteredCount) &&
            (identical(other.missingCount, missingCount) ||
                other.missingCount == missingCount) &&
            (identical(other.averageScore, averageScore) ||
                other.averageScore == averageScore) &&
            (identical(other.highestScore, highestScore) ||
                other.highestScore == highestScore) &&
            (identical(other.lowestScore, lowestScore) ||
                other.lowestScore == lowestScore) &&
            const DeepCollectionEquality()
                .equals(other._missingStudents, _missingStudents) &&
            const DeepCollectionEquality().equals(other._entries, _entries));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalStudents,
      enteredCount,
      missingCount,
      averageScore,
      highestScore,
      lowestScore,
      const DeepCollectionEquality().hash(_missingStudents),
      const DeepCollectionEquality().hash(_entries));

  /// Create a copy of MarksWizardDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarksWizardDtoImplCopyWith<_$MarksWizardDtoImpl> get copyWith =>
      __$$MarksWizardDtoImplCopyWithImpl<_$MarksWizardDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarksWizardDtoImplToJson(
      this,
    );
  }
}

abstract class _MarksWizardDto extends MarksWizardDto {
  const factory _MarksWizardDto(
      {@JsonKey(name: 'total_students') required final int totalStudents,
      @JsonKey(name: 'entered_count') required final int enteredCount,
      @JsonKey(name: 'missing_count') required final int missingCount,
      @JsonKey(name: 'average_score') final double? averageScore,
      @JsonKey(name: 'highest_score') final double? highestScore,
      @JsonKey(name: 'lowest_score') final double? lowestScore,
      @JsonKey(name: 'missing_students')
      required final List<StudentShortInfoDto> missingStudents,
      required final List<MarkWizardItemDto> entries}) = _$MarksWizardDtoImpl;
  const _MarksWizardDto._() : super._();

  factory _MarksWizardDto.fromJson(Map<String, dynamic> json) =
      _$MarksWizardDtoImpl.fromJson;

  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'entered_count')
  int get enteredCount;
  @override
  @JsonKey(name: 'missing_count')
  int get missingCount;
  @override
  @JsonKey(name: 'average_score')
  double? get averageScore;
  @override
  @JsonKey(name: 'highest_score')
  double? get highestScore;
  @override
  @JsonKey(name: 'lowest_score')
  double? get lowestScore;
  @override
  @JsonKey(name: 'missing_students')
  List<StudentShortInfoDto> get missingStudents;
  @override
  List<MarkWizardItemDto> get entries;

  /// Create a copy of MarksWizardDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarksWizardDtoImplCopyWith<_$MarksWizardDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
