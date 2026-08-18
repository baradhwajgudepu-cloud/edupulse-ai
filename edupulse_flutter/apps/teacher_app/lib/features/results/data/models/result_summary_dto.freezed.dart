// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ResultSummaryDto _$ResultSummaryDtoFromJson(Map<String, dynamic> json) {
  return _ResultSummaryDto.fromJson(json);
}

/// @nodoc
mixin _$ResultSummaryDto {
  @JsonKey(name: 'class_average')
  double get classAverage => throw _privateConstructorUsedError;
  @JsonKey(name: 'pass_percentage')
  double get passPercentage => throw _privateConstructorUsedError;
  @JsonKey(name: 'highest_score')
  double get highestScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'lowest_score')
  double get lowestScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'missing_count')
  int get missingCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'absent_count')
  int get absentCount => throw _privateConstructorUsedError;

  /// Serializes this ResultSummaryDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ResultSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ResultSummaryDtoCopyWith<ResultSummaryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResultSummaryDtoCopyWith<$Res> {
  factory $ResultSummaryDtoCopyWith(
          ResultSummaryDto value, $Res Function(ResultSummaryDto) then) =
      _$ResultSummaryDtoCopyWithImpl<$Res, ResultSummaryDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'class_average') double classAverage,
      @JsonKey(name: 'pass_percentage') double passPercentage,
      @JsonKey(name: 'highest_score') double highestScore,
      @JsonKey(name: 'lowest_score') double lowestScore,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'absent_count') int absentCount});
}

/// @nodoc
class _$ResultSummaryDtoCopyWithImpl<$Res, $Val extends ResultSummaryDto>
    implements $ResultSummaryDtoCopyWith<$Res> {
  _$ResultSummaryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ResultSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? classAverage = null,
    Object? passPercentage = null,
    Object? highestScore = null,
    Object? lowestScore = null,
    Object? missingCount = null,
    Object? absentCount = null,
  }) {
    return _then(_value.copyWith(
      classAverage: null == classAverage
          ? _value.classAverage
          : classAverage // ignore: cast_nullable_to_non_nullable
              as double,
      passPercentage: null == passPercentage
          ? _value.passPercentage
          : passPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      highestScore: null == highestScore
          ? _value.highestScore
          : highestScore // ignore: cast_nullable_to_non_nullable
              as double,
      lowestScore: null == lowestScore
          ? _value.lowestScore
          : lowestScore // ignore: cast_nullable_to_non_nullable
              as double,
      missingCount: null == missingCount
          ? _value.missingCount
          : missingCount // ignore: cast_nullable_to_non_nullable
              as int,
      absentCount: null == absentCount
          ? _value.absentCount
          : absentCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ResultSummaryDtoImplCopyWith<$Res>
    implements $ResultSummaryDtoCopyWith<$Res> {
  factory _$$ResultSummaryDtoImplCopyWith(_$ResultSummaryDtoImpl value,
          $Res Function(_$ResultSummaryDtoImpl) then) =
      __$$ResultSummaryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'class_average') double classAverage,
      @JsonKey(name: 'pass_percentage') double passPercentage,
      @JsonKey(name: 'highest_score') double highestScore,
      @JsonKey(name: 'lowest_score') double lowestScore,
      @JsonKey(name: 'missing_count') int missingCount,
      @JsonKey(name: 'absent_count') int absentCount});
}

/// @nodoc
class __$$ResultSummaryDtoImplCopyWithImpl<$Res>
    extends _$ResultSummaryDtoCopyWithImpl<$Res, _$ResultSummaryDtoImpl>
    implements _$$ResultSummaryDtoImplCopyWith<$Res> {
  __$$ResultSummaryDtoImplCopyWithImpl(_$ResultSummaryDtoImpl _value,
      $Res Function(_$ResultSummaryDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ResultSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? classAverage = null,
    Object? passPercentage = null,
    Object? highestScore = null,
    Object? lowestScore = null,
    Object? missingCount = null,
    Object? absentCount = null,
  }) {
    return _then(_$ResultSummaryDtoImpl(
      classAverage: null == classAverage
          ? _value.classAverage
          : classAverage // ignore: cast_nullable_to_non_nullable
              as double,
      passPercentage: null == passPercentage
          ? _value.passPercentage
          : passPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      highestScore: null == highestScore
          ? _value.highestScore
          : highestScore // ignore: cast_nullable_to_non_nullable
              as double,
      lowestScore: null == lowestScore
          ? _value.lowestScore
          : lowestScore // ignore: cast_nullable_to_non_nullable
              as double,
      missingCount: null == missingCount
          ? _value.missingCount
          : missingCount // ignore: cast_nullable_to_non_nullable
              as int,
      absentCount: null == absentCount
          ? _value.absentCount
          : absentCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ResultSummaryDtoImpl extends _ResultSummaryDto {
  const _$ResultSummaryDtoImpl(
      {@JsonKey(name: 'class_average') required this.classAverage,
      @JsonKey(name: 'pass_percentage') required this.passPercentage,
      @JsonKey(name: 'highest_score') required this.highestScore,
      @JsonKey(name: 'lowest_score') required this.lowestScore,
      @JsonKey(name: 'missing_count') required this.missingCount,
      @JsonKey(name: 'absent_count') required this.absentCount})
      : super._();

  factory _$ResultSummaryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ResultSummaryDtoImplFromJson(json);

  @override
  @JsonKey(name: 'class_average')
  final double classAverage;
  @override
  @JsonKey(name: 'pass_percentage')
  final double passPercentage;
  @override
  @JsonKey(name: 'highest_score')
  final double highestScore;
  @override
  @JsonKey(name: 'lowest_score')
  final double lowestScore;
  @override
  @JsonKey(name: 'missing_count')
  final int missingCount;
  @override
  @JsonKey(name: 'absent_count')
  final int absentCount;

  @override
  String toString() {
    return 'ResultSummaryDto(classAverage: $classAverage, passPercentage: $passPercentage, highestScore: $highestScore, lowestScore: $lowestScore, missingCount: $missingCount, absentCount: $absentCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ResultSummaryDtoImpl &&
            (identical(other.classAverage, classAverage) ||
                other.classAverage == classAverage) &&
            (identical(other.passPercentage, passPercentage) ||
                other.passPercentage == passPercentage) &&
            (identical(other.highestScore, highestScore) ||
                other.highestScore == highestScore) &&
            (identical(other.lowestScore, lowestScore) ||
                other.lowestScore == lowestScore) &&
            (identical(other.missingCount, missingCount) ||
                other.missingCount == missingCount) &&
            (identical(other.absentCount, absentCount) ||
                other.absentCount == absentCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, classAverage, passPercentage,
      highestScore, lowestScore, missingCount, absentCount);

  /// Create a copy of ResultSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ResultSummaryDtoImplCopyWith<_$ResultSummaryDtoImpl> get copyWith =>
      __$$ResultSummaryDtoImplCopyWithImpl<_$ResultSummaryDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ResultSummaryDtoImplToJson(
      this,
    );
  }
}

abstract class _ResultSummaryDto extends ResultSummaryDto {
  const factory _ResultSummaryDto(
      {@JsonKey(name: 'class_average') required final double classAverage,
      @JsonKey(name: 'pass_percentage') required final double passPercentage,
      @JsonKey(name: 'highest_score') required final double highestScore,
      @JsonKey(name: 'lowest_score') required final double lowestScore,
      @JsonKey(name: 'missing_count') required final int missingCount,
      @JsonKey(name: 'absent_count')
      required final int absentCount}) = _$ResultSummaryDtoImpl;
  const _ResultSummaryDto._() : super._();

  factory _ResultSummaryDto.fromJson(Map<String, dynamic> json) =
      _$ResultSummaryDtoImpl.fromJson;

  @override
  @JsonKey(name: 'class_average')
  double get classAverage;
  @override
  @JsonKey(name: 'pass_percentage')
  double get passPercentage;
  @override
  @JsonKey(name: 'highest_score')
  double get highestScore;
  @override
  @JsonKey(name: 'lowest_score')
  double get lowestScore;
  @override
  @JsonKey(name: 'missing_count')
  int get missingCount;
  @override
  @JsonKey(name: 'absent_count')
  int get absentCount;

  /// Create a copy of ResultSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ResultSummaryDtoImplCopyWith<_$ResultSummaryDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
