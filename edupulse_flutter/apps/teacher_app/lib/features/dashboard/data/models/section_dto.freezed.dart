// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'section_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SectionDto _$SectionDtoFromJson(Map<String, dynamic> json) {
  return _SectionDto.fromJson(json);
}

/// @nodoc
mixin _$SectionDto {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;

  /// Serializes this SectionDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SectionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SectionDtoCopyWith<SectionDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SectionDtoCopyWith<$Res> {
  factory $SectionDtoCopyWith(
          SectionDto value, $Res Function(SectionDto) then) =
      _$SectionDtoCopyWithImpl<$Res, SectionDto>;
  @useResult
  $Res call(
      {String id,
      String name,
      String code,
      @JsonKey(name: 'class_id') String classId});
}

/// @nodoc
class _$SectionDtoCopyWithImpl<$Res, $Val extends SectionDto>
    implements $SectionDtoCopyWith<$Res> {
  _$SectionDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SectionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? code = null,
    Object? classId = null,
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
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SectionDtoImplCopyWith<$Res>
    implements $SectionDtoCopyWith<$Res> {
  factory _$$SectionDtoImplCopyWith(
          _$SectionDtoImpl value, $Res Function(_$SectionDtoImpl) then) =
      __$$SectionDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String code,
      @JsonKey(name: 'class_id') String classId});
}

/// @nodoc
class __$$SectionDtoImplCopyWithImpl<$Res>
    extends _$SectionDtoCopyWithImpl<$Res, _$SectionDtoImpl>
    implements _$$SectionDtoImplCopyWith<$Res> {
  __$$SectionDtoImplCopyWithImpl(
      _$SectionDtoImpl _value, $Res Function(_$SectionDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of SectionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? code = null,
    Object? classId = null,
  }) {
    return _then(_$SectionDtoImpl(
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
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SectionDtoImpl implements _SectionDto {
  const _$SectionDtoImpl(
      {required this.id,
      required this.name,
      required this.code,
      @JsonKey(name: 'class_id') required this.classId});

  factory _$SectionDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$SectionDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String code;
  @override
  @JsonKey(name: 'class_id')
  final String classId;

  @override
  String toString() {
    return 'SectionDto(id: $id, name: $name, code: $code, classId: $classId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SectionDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.classId, classId) || other.classId == classId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, code, classId);

  /// Create a copy of SectionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SectionDtoImplCopyWith<_$SectionDtoImpl> get copyWith =>
      __$$SectionDtoImplCopyWithImpl<_$SectionDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SectionDtoImplToJson(
      this,
    );
  }
}

abstract class _SectionDto implements SectionDto {
  const factory _SectionDto(
          {required final String id,
          required final String name,
          required final String code,
          @JsonKey(name: 'class_id') required final String classId}) =
      _$SectionDtoImpl;

  factory _SectionDto.fromJson(Map<String, dynamic> json) =
      _$SectionDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get code;
  @override
  @JsonKey(name: 'class_id')
  String get classId;

  /// Create a copy of SectionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SectionDtoImplCopyWith<_$SectionDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
