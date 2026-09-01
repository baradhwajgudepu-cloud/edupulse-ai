// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'outstanding_class_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OutstandingClassDto _$OutstandingClassDtoFromJson(Map<String, dynamic> json) {
  return _OutstandingClassDto.fromJson(json);
}

/// @nodoc
mixin _$OutstandingClassDto {
  @JsonKey(name: 'class_name')
  String get className => throw _privateConstructorUsedError;
  @JsonKey(name: 'outstanding_amount')
  double get outstandingAmount => throw _privateConstructorUsedError;

  /// Serializes this OutstandingClassDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OutstandingClassDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OutstandingClassDtoCopyWith<OutstandingClassDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OutstandingClassDtoCopyWith<$Res> {
  factory $OutstandingClassDtoCopyWith(
          OutstandingClassDto value, $Res Function(OutstandingClassDto) then) =
      _$OutstandingClassDtoCopyWithImpl<$Res, OutstandingClassDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'outstanding_amount') double outstandingAmount});
}

/// @nodoc
class _$OutstandingClassDtoCopyWithImpl<$Res, $Val extends OutstandingClassDto>
    implements $OutstandingClassDtoCopyWith<$Res> {
  _$OutstandingClassDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OutstandingClassDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? className = null,
    Object? outstandingAmount = null,
  }) {
    return _then(_value.copyWith(
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
      outstandingAmount: null == outstandingAmount
          ? _value.outstandingAmount
          : outstandingAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OutstandingClassDtoImplCopyWith<$Res>
    implements $OutstandingClassDtoCopyWith<$Res> {
  factory _$$OutstandingClassDtoImplCopyWith(_$OutstandingClassDtoImpl value,
          $Res Function(_$OutstandingClassDtoImpl) then) =
      __$$OutstandingClassDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'class_name') String className,
      @JsonKey(name: 'outstanding_amount') double outstandingAmount});
}

/// @nodoc
class __$$OutstandingClassDtoImplCopyWithImpl<$Res>
    extends _$OutstandingClassDtoCopyWithImpl<$Res, _$OutstandingClassDtoImpl>
    implements _$$OutstandingClassDtoImplCopyWith<$Res> {
  __$$OutstandingClassDtoImplCopyWithImpl(_$OutstandingClassDtoImpl _value,
      $Res Function(_$OutstandingClassDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of OutstandingClassDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? className = null,
    Object? outstandingAmount = null,
  }) {
    return _then(_$OutstandingClassDtoImpl(
      className: null == className
          ? _value.className
          : className // ignore: cast_nullable_to_non_nullable
              as String,
      outstandingAmount: null == outstandingAmount
          ? _value.outstandingAmount
          : outstandingAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OutstandingClassDtoImpl implements _OutstandingClassDto {
  const _$OutstandingClassDtoImpl(
      {@JsonKey(name: 'class_name') required this.className,
      @JsonKey(name: 'outstanding_amount') required this.outstandingAmount});

  factory _$OutstandingClassDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$OutstandingClassDtoImplFromJson(json);

  @override
  @JsonKey(name: 'class_name')
  final String className;
  @override
  @JsonKey(name: 'outstanding_amount')
  final double outstandingAmount;

  @override
  String toString() {
    return 'OutstandingClassDto(className: $className, outstandingAmount: $outstandingAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OutstandingClassDtoImpl &&
            (identical(other.className, className) ||
                other.className == className) &&
            (identical(other.outstandingAmount, outstandingAmount) ||
                other.outstandingAmount == outstandingAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, className, outstandingAmount);

  /// Create a copy of OutstandingClassDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OutstandingClassDtoImplCopyWith<_$OutstandingClassDtoImpl> get copyWith =>
      __$$OutstandingClassDtoImplCopyWithImpl<_$OutstandingClassDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OutstandingClassDtoImplToJson(
      this,
    );
  }
}

abstract class _OutstandingClassDto implements OutstandingClassDto {
  const factory _OutstandingClassDto(
      {@JsonKey(name: 'class_name') required final String className,
      @JsonKey(name: 'outstanding_amount')
      required final double outstandingAmount}) = _$OutstandingClassDtoImpl;

  factory _OutstandingClassDto.fromJson(Map<String, dynamic> json) =
      _$OutstandingClassDtoImpl.fromJson;

  @override
  @JsonKey(name: 'class_name')
  String get className;
  @override
  @JsonKey(name: 'outstanding_amount')
  double get outstandingAmount;

  /// Create a copy of OutstandingClassDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OutstandingClassDtoImplCopyWith<_$OutstandingClassDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
