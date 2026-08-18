// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remarks_template_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RemarksTemplateDto _$RemarksTemplateDtoFromJson(Map<String, dynamic> json) {
  return _RemarksTemplateDto.fromJson(json);
}

/// @nodoc
mixin _$RemarksTemplateDto {
  List<String> get templates => throw _privateConstructorUsedError;

  /// Serializes this RemarksTemplateDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RemarksTemplateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RemarksTemplateDtoCopyWith<RemarksTemplateDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RemarksTemplateDtoCopyWith<$Res> {
  factory $RemarksTemplateDtoCopyWith(
          RemarksTemplateDto value, $Res Function(RemarksTemplateDto) then) =
      _$RemarksTemplateDtoCopyWithImpl<$Res, RemarksTemplateDto>;
  @useResult
  $Res call({List<String> templates});
}

/// @nodoc
class _$RemarksTemplateDtoCopyWithImpl<$Res, $Val extends RemarksTemplateDto>
    implements $RemarksTemplateDtoCopyWith<$Res> {
  _$RemarksTemplateDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RemarksTemplateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? templates = null,
  }) {
    return _then(_value.copyWith(
      templates: null == templates
          ? _value.templates
          : templates // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RemarksTemplateDtoImplCopyWith<$Res>
    implements $RemarksTemplateDtoCopyWith<$Res> {
  factory _$$RemarksTemplateDtoImplCopyWith(_$RemarksTemplateDtoImpl value,
          $Res Function(_$RemarksTemplateDtoImpl) then) =
      __$$RemarksTemplateDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> templates});
}

/// @nodoc
class __$$RemarksTemplateDtoImplCopyWithImpl<$Res>
    extends _$RemarksTemplateDtoCopyWithImpl<$Res, _$RemarksTemplateDtoImpl>
    implements _$$RemarksTemplateDtoImplCopyWith<$Res> {
  __$$RemarksTemplateDtoImplCopyWithImpl(_$RemarksTemplateDtoImpl _value,
      $Res Function(_$RemarksTemplateDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of RemarksTemplateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? templates = null,
  }) {
    return _then(_$RemarksTemplateDtoImpl(
      templates: null == templates
          ? _value._templates
          : templates // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RemarksTemplateDtoImpl extends _RemarksTemplateDto {
  const _$RemarksTemplateDtoImpl({required final List<String> templates})
      : _templates = templates,
        super._();

  factory _$RemarksTemplateDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RemarksTemplateDtoImplFromJson(json);

  final List<String> _templates;
  @override
  List<String> get templates {
    if (_templates is EqualUnmodifiableListView) return _templates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_templates);
  }

  @override
  String toString() {
    return 'RemarksTemplateDto(templates: $templates)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemarksTemplateDtoImpl &&
            const DeepCollectionEquality()
                .equals(other._templates, _templates));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_templates));

  /// Create a copy of RemarksTemplateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemarksTemplateDtoImplCopyWith<_$RemarksTemplateDtoImpl> get copyWith =>
      __$$RemarksTemplateDtoImplCopyWithImpl<_$RemarksTemplateDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RemarksTemplateDtoImplToJson(
      this,
    );
  }
}

abstract class _RemarksTemplateDto extends RemarksTemplateDto {
  const factory _RemarksTemplateDto({required final List<String> templates}) =
      _$RemarksTemplateDtoImpl;
  const _RemarksTemplateDto._() : super._();

  factory _RemarksTemplateDto.fromJson(Map<String, dynamic> json) =
      _$RemarksTemplateDtoImpl.fromJson;

  @override
  List<String> get templates;

  /// Create a copy of RemarksTemplateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemarksTemplateDtoImplCopyWith<_$RemarksTemplateDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
