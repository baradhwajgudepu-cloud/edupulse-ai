// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bulk_class_generate_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StudentFailureDetailDto _$StudentFailureDetailDtoFromJson(
    Map<String, dynamic> json) {
  return _StudentFailureDetailDto.fromJson(json);
}

/// @nodoc
mixin _$StudentFailureDetailDto {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_name')
  String get studentName => throw _privateConstructorUsedError;
  List<String> get reasons => throw _privateConstructorUsedError;

  /// Serializes this StudentFailureDetailDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudentFailureDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentFailureDetailDtoCopyWith<StudentFailureDetailDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentFailureDetailDtoCopyWith<$Res> {
  factory $StudentFailureDetailDtoCopyWith(StudentFailureDetailDto value,
          $Res Function(StudentFailureDetailDto) then) =
      _$StudentFailureDetailDtoCopyWithImpl<$Res, StudentFailureDetailDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'student_name') String studentName,
      List<String> reasons});
}

/// @nodoc
class _$StudentFailureDetailDtoCopyWithImpl<$Res,
        $Val extends StudentFailureDetailDto>
    implements $StudentFailureDetailDtoCopyWith<$Res> {
  _$StudentFailureDetailDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudentFailureDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? studentName = null,
    Object? reasons = null,
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
      reasons: null == reasons
          ? _value.reasons
          : reasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentFailureDetailDtoImplCopyWith<$Res>
    implements $StudentFailureDetailDtoCopyWith<$Res> {
  factory _$$StudentFailureDetailDtoImplCopyWith(
          _$StudentFailureDetailDtoImpl value,
          $Res Function(_$StudentFailureDetailDtoImpl) then) =
      __$$StudentFailureDetailDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'student_name') String studentName,
      List<String> reasons});
}

/// @nodoc
class __$$StudentFailureDetailDtoImplCopyWithImpl<$Res>
    extends _$StudentFailureDetailDtoCopyWithImpl<$Res,
        _$StudentFailureDetailDtoImpl>
    implements _$$StudentFailureDetailDtoImplCopyWith<$Res> {
  __$$StudentFailureDetailDtoImplCopyWithImpl(
      _$StudentFailureDetailDtoImpl _value,
      $Res Function(_$StudentFailureDetailDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudentFailureDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? studentName = null,
    Object? reasons = null,
  }) {
    return _then(_$StudentFailureDetailDtoImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      studentName: null == studentName
          ? _value.studentName
          : studentName // ignore: cast_nullable_to_non_nullable
              as String,
      reasons: null == reasons
          ? _value._reasons
          : reasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudentFailureDetailDtoImpl extends _StudentFailureDetailDto {
  const _$StudentFailureDetailDtoImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'student_name') required this.studentName,
      required final List<String> reasons})
      : _reasons = reasons,
        super._();

  factory _$StudentFailureDetailDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentFailureDetailDtoImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'student_name')
  final String studentName;
  final List<String> _reasons;
  @override
  List<String> get reasons {
    if (_reasons is EqualUnmodifiableListView) return _reasons;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reasons);
  }

  @override
  String toString() {
    return 'StudentFailureDetailDto(studentId: $studentId, studentName: $studentName, reasons: $reasons)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentFailureDetailDtoImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.studentName, studentName) ||
                other.studentName == studentName) &&
            const DeepCollectionEquality().equals(other._reasons, _reasons));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, studentId, studentName,
      const DeepCollectionEquality().hash(_reasons));

  /// Create a copy of StudentFailureDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentFailureDetailDtoImplCopyWith<_$StudentFailureDetailDtoImpl>
      get copyWith => __$$StudentFailureDetailDtoImplCopyWithImpl<
          _$StudentFailureDetailDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentFailureDetailDtoImplToJson(
      this,
    );
  }
}

abstract class _StudentFailureDetailDto extends StudentFailureDetailDto {
  const factory _StudentFailureDetailDto(
      {@JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'student_name') required final String studentName,
      required final List<String> reasons}) = _$StudentFailureDetailDtoImpl;
  const _StudentFailureDetailDto._() : super._();

  factory _StudentFailureDetailDto.fromJson(Map<String, dynamic> json) =
      _$StudentFailureDetailDtoImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'student_name')
  String get studentName;
  @override
  List<String> get reasons;

  /// Create a copy of StudentFailureDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentFailureDetailDtoImplCopyWith<_$StudentFailureDetailDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}

BulkClassGenerateDto _$BulkClassGenerateDtoFromJson(Map<String, dynamic> json) {
  return _BulkClassGenerateDto.fromJson(json);
}

/// @nodoc
mixin _$BulkClassGenerateDto {
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'generated_count')
  int get generatedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'failed_count')
  int get failedCount => throw _privateConstructorUsedError;
  List<StudentFailureDetailDto> get failures =>
      throw _privateConstructorUsedError;

  /// Serializes this BulkClassGenerateDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BulkClassGenerateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BulkClassGenerateDtoCopyWith<BulkClassGenerateDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BulkClassGenerateDtoCopyWith<$Res> {
  factory $BulkClassGenerateDtoCopyWith(BulkClassGenerateDto value,
          $Res Function(BulkClassGenerateDto) then) =
      _$BulkClassGenerateDtoCopyWithImpl<$Res, BulkClassGenerateDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'generated_count') int generatedCount,
      @JsonKey(name: 'failed_count') int failedCount,
      List<StudentFailureDetailDto> failures});
}

/// @nodoc
class _$BulkClassGenerateDtoCopyWithImpl<$Res,
        $Val extends BulkClassGenerateDto>
    implements $BulkClassGenerateDtoCopyWith<$Res> {
  _$BulkClassGenerateDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BulkClassGenerateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalStudents = null,
    Object? generatedCount = null,
    Object? failedCount = null,
    Object? failures = null,
  }) {
    return _then(_value.copyWith(
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      generatedCount: null == generatedCount
          ? _value.generatedCount
          : generatedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _value.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failures: null == failures
          ? _value.failures
          : failures // ignore: cast_nullable_to_non_nullable
              as List<StudentFailureDetailDto>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BulkClassGenerateDtoImplCopyWith<$Res>
    implements $BulkClassGenerateDtoCopyWith<$Res> {
  factory _$$BulkClassGenerateDtoImplCopyWith(_$BulkClassGenerateDtoImpl value,
          $Res Function(_$BulkClassGenerateDtoImpl) then) =
      __$$BulkClassGenerateDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'generated_count') int generatedCount,
      @JsonKey(name: 'failed_count') int failedCount,
      List<StudentFailureDetailDto> failures});
}

/// @nodoc
class __$$BulkClassGenerateDtoImplCopyWithImpl<$Res>
    extends _$BulkClassGenerateDtoCopyWithImpl<$Res, _$BulkClassGenerateDtoImpl>
    implements _$$BulkClassGenerateDtoImplCopyWith<$Res> {
  __$$BulkClassGenerateDtoImplCopyWithImpl(_$BulkClassGenerateDtoImpl _value,
      $Res Function(_$BulkClassGenerateDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of BulkClassGenerateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalStudents = null,
    Object? generatedCount = null,
    Object? failedCount = null,
    Object? failures = null,
  }) {
    return _then(_$BulkClassGenerateDtoImpl(
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      generatedCount: null == generatedCount
          ? _value.generatedCount
          : generatedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _value.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failures: null == failures
          ? _value._failures
          : failures // ignore: cast_nullable_to_non_nullable
              as List<StudentFailureDetailDto>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BulkClassGenerateDtoImpl extends _BulkClassGenerateDto {
  const _$BulkClassGenerateDtoImpl(
      {@JsonKey(name: 'total_students') required this.totalStudents,
      @JsonKey(name: 'generated_count') required this.generatedCount,
      @JsonKey(name: 'failed_count') required this.failedCount,
      required final List<StudentFailureDetailDto> failures})
      : _failures = failures,
        super._();

  factory _$BulkClassGenerateDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$BulkClassGenerateDtoImplFromJson(json);

  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'generated_count')
  final int generatedCount;
  @override
  @JsonKey(name: 'failed_count')
  final int failedCount;
  final List<StudentFailureDetailDto> _failures;
  @override
  List<StudentFailureDetailDto> get failures {
    if (_failures is EqualUnmodifiableListView) return _failures;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_failures);
  }

  @override
  String toString() {
    return 'BulkClassGenerateDto(totalStudents: $totalStudents, generatedCount: $generatedCount, failedCount: $failedCount, failures: $failures)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BulkClassGenerateDtoImpl &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.generatedCount, generatedCount) ||
                other.generatedCount == generatedCount) &&
            (identical(other.failedCount, failedCount) ||
                other.failedCount == failedCount) &&
            const DeepCollectionEquality().equals(other._failures, _failures));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, totalStudents, generatedCount,
      failedCount, const DeepCollectionEquality().hash(_failures));

  /// Create a copy of BulkClassGenerateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BulkClassGenerateDtoImplCopyWith<_$BulkClassGenerateDtoImpl>
      get copyWith =>
          __$$BulkClassGenerateDtoImplCopyWithImpl<_$BulkClassGenerateDtoImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BulkClassGenerateDtoImplToJson(
      this,
    );
  }
}

abstract class _BulkClassGenerateDto extends BulkClassGenerateDto {
  const factory _BulkClassGenerateDto(
          {@JsonKey(name: 'total_students') required final int totalStudents,
          @JsonKey(name: 'generated_count') required final int generatedCount,
          @JsonKey(name: 'failed_count') required final int failedCount,
          required final List<StudentFailureDetailDto> failures}) =
      _$BulkClassGenerateDtoImpl;
  const _BulkClassGenerateDto._() : super._();

  factory _BulkClassGenerateDto.fromJson(Map<String, dynamic> json) =
      _$BulkClassGenerateDtoImpl.fromJson;

  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'generated_count')
  int get generatedCount;
  @override
  @JsonKey(name: 'failed_count')
  int get failedCount;
  @override
  List<StudentFailureDetailDto> get failures;

  /// Create a copy of BulkClassGenerateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BulkClassGenerateDtoImplCopyWith<_$BulkClassGenerateDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
