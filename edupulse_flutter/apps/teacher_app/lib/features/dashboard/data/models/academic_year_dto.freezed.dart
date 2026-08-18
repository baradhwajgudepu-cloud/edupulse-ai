// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'academic_year_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AcademicYearDto _$AcademicYearDtoFromJson(Map<String, dynamic> json) {
  return _AcademicYearDto.fromJson(json);
}

/// @nodoc
mixin _$AcademicYearDto {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this AcademicYearDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcademicYearDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcademicYearDtoCopyWith<AcademicYearDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcademicYearDtoCopyWith<$Res> {
  factory $AcademicYearDtoCopyWith(
          AcademicYearDto value, $Res Function(AcademicYearDto) then) =
      _$AcademicYearDtoCopyWithImpl<$Res, AcademicYearDto>;
  @useResult
  $Res call({String id, String name, String code, String status});
}

/// @nodoc
class _$AcademicYearDtoCopyWithImpl<$Res, $Val extends AcademicYearDto>
    implements $AcademicYearDtoCopyWith<$Res> {
  _$AcademicYearDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcademicYearDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? code = null,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AcademicYearDtoImplCopyWith<$Res>
    implements $AcademicYearDtoCopyWith<$Res> {
  factory _$$AcademicYearDtoImplCopyWith(_$AcademicYearDtoImpl value,
          $Res Function(_$AcademicYearDtoImpl) then) =
      __$$AcademicYearDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, String code, String status});
}

/// @nodoc
class __$$AcademicYearDtoImplCopyWithImpl<$Res>
    extends _$AcademicYearDtoCopyWithImpl<$Res, _$AcademicYearDtoImpl>
    implements _$$AcademicYearDtoImplCopyWith<$Res> {
  __$$AcademicYearDtoImplCopyWithImpl(
      _$AcademicYearDtoImpl _value, $Res Function(_$AcademicYearDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AcademicYearDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? code = null,
    Object? status = null,
  }) {
    return _then(_$AcademicYearDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AcademicYearDtoImpl implements _AcademicYearDto {
  const _$AcademicYearDtoImpl(
      {required this.id,
      required this.name,
      required this.code,
      required this.status});

  factory _$AcademicYearDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AcademicYearDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String code;
  @override
  final String status;

  @override
  String toString() {
    return 'AcademicYearDto(id: $id, name: $name, code: $code, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcademicYearDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, code, status);

  /// Create a copy of AcademicYearDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcademicYearDtoImplCopyWith<_$AcademicYearDtoImpl> get copyWith =>
      __$$AcademicYearDtoImplCopyWithImpl<_$AcademicYearDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AcademicYearDtoImplToJson(
      this,
    );
  }
}

abstract class _AcademicYearDto implements AcademicYearDto {
  const factory _AcademicYearDto(
      {required final String id,
      required final String name,
      required final String code,
      required final String status}) = _$AcademicYearDtoImpl;

  factory _AcademicYearDto.fromJson(Map<String, dynamic> json) =
      _$AcademicYearDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get code;
  @override
  String get status;

  /// Create a copy of AcademicYearDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcademicYearDtoImplCopyWith<_$AcademicYearDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
