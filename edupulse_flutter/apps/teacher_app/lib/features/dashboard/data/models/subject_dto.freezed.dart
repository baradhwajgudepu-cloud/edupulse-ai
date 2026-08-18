// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subject_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SubjectDto _$SubjectDtoFromJson(Map<String, dynamic> json) {
  return _SubjectDto.fromJson(json);
}

/// @nodoc
mixin _$SubjectDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_name')
  String get subjectName => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_code')
  String get subjectCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_name')
  String? get shortName => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_color')
  String? get displayColor => throw _privateConstructorUsedError;

  /// Serializes this SubjectDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubjectDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubjectDtoCopyWith<SubjectDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubjectDtoCopyWith<$Res> {
  factory $SubjectDtoCopyWith(
          SubjectDto value, $Res Function(SubjectDto) then) =
      _$SubjectDtoCopyWithImpl<$Res, SubjectDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'subject_code') String subjectCode,
      @JsonKey(name: 'short_name') String? shortName,
      @JsonKey(name: 'display_color') String? displayColor});
}

/// @nodoc
class _$SubjectDtoCopyWithImpl<$Res, $Val extends SubjectDto>
    implements $SubjectDtoCopyWith<$Res> {
  _$SubjectDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubjectDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subjectName = null,
    Object? subjectCode = null,
    Object? shortName = freezed,
    Object? displayColor = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
              as String,
      subjectCode: null == subjectCode
          ? _value.subjectCode
          : subjectCode // ignore: cast_nullable_to_non_nullable
              as String,
      shortName: freezed == shortName
          ? _value.shortName
          : shortName // ignore: cast_nullable_to_non_nullable
              as String?,
      displayColor: freezed == displayColor
          ? _value.displayColor
          : displayColor // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubjectDtoImplCopyWith<$Res>
    implements $SubjectDtoCopyWith<$Res> {
  factory _$$SubjectDtoImplCopyWith(
          _$SubjectDtoImpl value, $Res Function(_$SubjectDtoImpl) then) =
      __$$SubjectDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'subject_name') String subjectName,
      @JsonKey(name: 'subject_code') String subjectCode,
      @JsonKey(name: 'short_name') String? shortName,
      @JsonKey(name: 'display_color') String? displayColor});
}

/// @nodoc
class __$$SubjectDtoImplCopyWithImpl<$Res>
    extends _$SubjectDtoCopyWithImpl<$Res, _$SubjectDtoImpl>
    implements _$$SubjectDtoImplCopyWith<$Res> {
  __$$SubjectDtoImplCopyWithImpl(
      _$SubjectDtoImpl _value, $Res Function(_$SubjectDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of SubjectDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subjectName = null,
    Object? subjectCode = null,
    Object? shortName = freezed,
    Object? displayColor = freezed,
  }) {
    return _then(_$SubjectDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      subjectName: null == subjectName
          ? _value.subjectName
          : subjectName // ignore: cast_nullable_to_non_nullable
              as String,
      subjectCode: null == subjectCode
          ? _value.subjectCode
          : subjectCode // ignore: cast_nullable_to_non_nullable
              as String,
      shortName: freezed == shortName
          ? _value.shortName
          : shortName // ignore: cast_nullable_to_non_nullable
              as String?,
      displayColor: freezed == displayColor
          ? _value.displayColor
          : displayColor // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubjectDtoImpl implements _SubjectDto {
  const _$SubjectDtoImpl(
      {required this.id,
      @JsonKey(name: 'subject_name') required this.subjectName,
      @JsonKey(name: 'subject_code') required this.subjectCode,
      @JsonKey(name: 'short_name') this.shortName,
      @JsonKey(name: 'display_color') this.displayColor});

  factory _$SubjectDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubjectDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'subject_name')
  final String subjectName;
  @override
  @JsonKey(name: 'subject_code')
  final String subjectCode;
  @override
  @JsonKey(name: 'short_name')
  final String? shortName;
  @override
  @JsonKey(name: 'display_color')
  final String? displayColor;

  @override
  String toString() {
    return 'SubjectDto(id: $id, subjectName: $subjectName, subjectCode: $subjectCode, shortName: $shortName, displayColor: $displayColor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubjectDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.subjectCode, subjectCode) ||
                other.subjectCode == subjectCode) &&
            (identical(other.shortName, shortName) ||
                other.shortName == shortName) &&
            (identical(other.displayColor, displayColor) ||
                other.displayColor == displayColor));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, subjectName, subjectCode, shortName, displayColor);

  /// Create a copy of SubjectDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubjectDtoImplCopyWith<_$SubjectDtoImpl> get copyWith =>
      __$$SubjectDtoImplCopyWithImpl<_$SubjectDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubjectDtoImplToJson(
      this,
    );
  }
}

abstract class _SubjectDto implements SubjectDto {
  const factory _SubjectDto(
          {required final String id,
          @JsonKey(name: 'subject_name') required final String subjectName,
          @JsonKey(name: 'subject_code') required final String subjectCode,
          @JsonKey(name: 'short_name') final String? shortName,
          @JsonKey(name: 'display_color') final String? displayColor}) =
      _$SubjectDtoImpl;

  factory _SubjectDto.fromJson(Map<String, dynamic> json) =
      _$SubjectDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'subject_name')
  String get subjectName;
  @override
  @JsonKey(name: 'subject_code')
  String get subjectCode;
  @override
  @JsonKey(name: 'short_name')
  String? get shortName;
  @override
  @JsonKey(name: 'display_color')
  String? get displayColor;

  /// Create a copy of SubjectDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubjectDtoImplCopyWith<_$SubjectDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
