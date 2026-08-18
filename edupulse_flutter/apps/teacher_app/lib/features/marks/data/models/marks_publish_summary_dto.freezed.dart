// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marks_publish_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MarksPublishSummaryDto _$MarksPublishSummaryDtoFromJson(
    Map<String, dynamic> json) {
  return _MarksPublishSummaryDto.fromJson(json);
}

/// @nodoc
mixin _$MarksPublishSummaryDto {
  @JsonKey(name: 'exam_name')
  String get examName => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_name')
  String get subjectName => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_name')
  String get className => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'entered_count')
  int get enteredCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'missing_count')
  int get missingCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'pass_percentage')
  double get passPercentage => throw _privateConstructorUsedError;

  /// Serializes this MarksPublishSummaryDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarksPublishSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarksPublishSummaryDtoCopyWith<MarksPublishSummaryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarksPublishSummaryDtoCopyWith<$Res> {
  factory $MarksPublishSummaryDtoCopyWith(MarksPublishSummaryDto value,
          $Res Function(MarksPublishSummaryDto) then) =
      _$MarksPublishSummaryDtoCopyWithImpl<$Res, MarksPublishSummaryDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'exam_name') String examName,
      @JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'entered_count') int enteredCount,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'pass_percentage') double passPercentage});
}

/// @nodoc
class _$MarksPublishSummaryDtoCopyWithImpl<$Res,
        $Val extends MarksPublishSummaryDto>
    implements $MarksPublishSummaryDtoCopyWith<$Res> {
  _$MarksPublishSummaryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarksPublishSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? examName = null,
    Object? subjectName = null,
    Object? className = null,
    Object? totalStudents = null,
    Object? enteredCount = null,
    Object? missingCount = null,
    Object? passPercentage = null,
  }) {
    return _then(_value.copyWith(
      examName: null == examName
          ? _value.examName
          : examName // ignore: cast_nullable_to_non_nullable
              as String,
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
              as String,
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
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
      passPercentage: null == passPercentage
          ? _value.passPercentage
          : passPercentage // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MarksPublishSummaryDtoImplCopyWith<$Res>
    implements $MarksPublishSummaryDtoCopyWith<$Res> {
  factory _$$MarksPublishSummaryDtoImplCopyWith(
          _$MarksPublishSummaryDtoImpl value,
          $Res Function(_$MarksPublishSummaryDtoImpl) then) =
      __$$MarksPublishSummaryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'exam_name') String examName,
      @JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'entered_count') int enteredCount,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'pass_percentage') double passPercentage});
}

/// @nodoc
class __$$MarksPublishSummaryDtoImplCopyWithImpl<$Res>
    extends _$MarksPublishSummaryDtoCopyWithImpl<$Res,
        _$MarksPublishSummaryDtoImpl>
    implements _$$MarksPublishSummaryDtoImplCopyWith<$Res> {
  __$$MarksPublishSummaryDtoImplCopyWithImpl(
      _$MarksPublishSummaryDtoImpl _value,
      $Res Function(_$MarksPublishSummaryDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarksPublishSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? examName = null,
    Object? subjectName = null,
    Object? className = null,
    Object? totalStudents = null,
    Object? enteredCount = null,
    Object? missingCount = null,
    Object? passPercentage = null,
  }) {
    return _then(_$MarksPublishSummaryDtoImpl(
      examName: null == examName
          ? _value.examName
          : examName // ignore: cast_nullable_to_non_nullable
              as String,
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
              as String,
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
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
      passPercentage: null == passPercentage
          ? _value.passPercentage
          : passPercentage // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MarksPublishSummaryDtoImpl extends _MarksPublishSummaryDto {
  const _$MarksPublishSummaryDtoImpl(
      {@JsonKey(name: 'exam_name') required this.examName,
      @JsonKey(name: 'subject_name') required this.subjectName,
      @JsonKey(name: 'class_name') required this.className,
      @JsonKey(name: 'total_students') required this.totalStudents,
      @JsonKey(name: 'entered_count') required this.enteredCount,
      @JsonKey(name: 'missing_count') required this.missingCount,
      @JsonKey(name: 'pass_percentage') required this.passPercentage})
      : super._();

  factory _$MarksPublishSummaryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarksPublishSummaryDtoImplFromJson(json);

  @override
  @JsonKey(name: 'exam_name')
  final String examName;
  @override
  @JsonKey(name: 'subject_name')
  final String subjectName;
  @override
  @JsonKey(name: 'class_name')
  final String className;
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
  @JsonKey(name: 'pass_percentage')
  final double passPercentage;

  @override
  String toString() {
    return 'MarksPublishSummaryDto(examName: $examName, subjectName: $subjectName, className: $className, totalStudents: $totalStudents, enteredCount: $enteredCount, missingCount: $missingCount, passPercentage: $passPercentage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarksPublishSummaryDtoImpl &&
            (identical(other.examName, examName) ||
                other.examName == examName) &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.className, className) ||
                other.className == className) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.enteredCount, enteredCount) ||
                other.enteredCount == enteredCount) &&
            (identical(other.missingCount, missingCount) ||
                other.missingCount == missingCount) &&
            (identical(other.passPercentage, passPercentage) ||
                other.passPercentage == passPercentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, examName, subjectName, className,
      totalStudents, enteredCount, missingCount, passPercentage);

  /// Create a copy of MarksPublishSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarksPublishSummaryDtoImplCopyWith<_$MarksPublishSummaryDtoImpl>
      get copyWith => __$$MarksPublishSummaryDtoImplCopyWithImpl<
          _$MarksPublishSummaryDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarksPublishSummaryDtoImplToJson(
      this,
    );
  }
}

abstract class _MarksPublishSummaryDto extends MarksPublishSummaryDto {
  const factory _MarksPublishSummaryDto(
      {@JsonKey(name: 'exam_name') required final String examName,
      @JsonKey(name: 'subject_name') required final String subjectName,
      @JsonKey(name: 'class_name') required final String className,
      @JsonKey(name: 'total_students') required final int totalStudents,
      @JsonKey(name: 'entered_count') required final int enteredCount,
      @JsonKey(name: 'missing_count') required final int missingCount,
      @JsonKey(name: 'pass_percentage')
      required final double passPercentage}) = _$MarksPublishSummaryDtoImpl;
  const _MarksPublishSummaryDto._() : super._();

  factory _MarksPublishSummaryDto.fromJson(Map<String, dynamic> json) =
      _$MarksPublishSummaryDtoImpl.fromJson;

  @override
  @JsonKey(name: 'exam_name')
  String get examName;
  @override
  @JsonKey(name: 'subject_name')
  String get subjectName;
  @override
  @JsonKey(name: 'class_name')
  String get className;
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
  @JsonKey(name: 'pass_percentage')
  double get passPercentage;

  /// Create a copy of MarksPublishSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarksPublishSummaryDtoImplCopyWith<_$MarksPublishSummaryDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
