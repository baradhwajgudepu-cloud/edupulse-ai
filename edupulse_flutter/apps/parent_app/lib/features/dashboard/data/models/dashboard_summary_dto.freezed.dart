// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DashboardSummaryDto _$DashboardSummaryDtoFromJson(Map<String, dynamic> json) {
  return _DashboardSummaryDto.fromJson(json);
}

/// @nodoc
mixin _$DashboardSummaryDto {
  @JsonKey(name: 'today_collection')
  double get todayCollection => throw _privateConstructorUsedError;
  @JsonKey(name: 'month_collection')
  double get monthCollection => throw _privateConstructorUsedError;
  @JsonKey(name: 'pending_dues')
  double get pendingDues => throw _privateConstructorUsedError;
  @JsonKey(name: 'collection_percentage')
  double get collectionPercentage => throw _privateConstructorUsedError;
  @JsonKey(name: 'defaulters_count')
  int get defaultersCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'top_outstanding_classes')
  List<OutstandingClassDto> get topOutstandingClasses =>
      throw _privateConstructorUsedError;

  /// Serializes this DashboardSummaryDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardSummaryDtoCopyWith<DashboardSummaryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardSummaryDtoCopyWith<$Res> {
  factory $DashboardSummaryDtoCopyWith(
          DashboardSummaryDto value, $Res Function(DashboardSummaryDto) then) =
      _$DashboardSummaryDtoCopyWithImpl<$Res, DashboardSummaryDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'today_collection') double todayCollection,
      @JsonKey(name: 'month_collection') double monthCollection,
      @JsonKey(name: 'pending_dues') double pendingDues,
      @JsonKey(name: 'collection_percentage') double collectionPercentage,
      @JsonKey(name: 'defaulters_count') int defaultersCount,
      @JsonKey(name: 'top_outstanding_classes')
      List<OutstandingClassDto> topOutstandingClasses});
}

/// @nodoc
class _$DashboardSummaryDtoCopyWithImpl<$Res, $Val extends DashboardSummaryDto>
    implements $DashboardSummaryDtoCopyWith<$Res> {
  _$DashboardSummaryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayCollection = null,
    Object? monthCollection = null,
    Object? pendingDues = null,
    Object? collectionPercentage = null,
    Object? defaultersCount = null,
    Object? topOutstandingClasses = null,
  }) {
    return _then(_value.copyWith(
      todayCollection: null == todayCollection
          ? _value.todayCollection
          : todayCollection // ignore: cast_nullable_to_non_nullable
              as double,
      monthCollection: null == monthCollection
          ? _value.monthCollection
          : monthCollection // ignore: cast_nullable_to_non_nullable
              as double,
      pendingDues: null == pendingDues
          ? _value.pendingDues
          : pendingDues // ignore: cast_nullable_to_non_nullable
              as double,
      collectionPercentage: null == collectionPercentage
          ? _value.collectionPercentage
          : collectionPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      defaultersCount: null == defaultersCount
          ? _value.defaultersCount
          : defaultersCount // ignore: cast_nullable_to_non_nullable
              as int,
      topOutstandingClasses: null == topOutstandingClasses
          ? _value.topOutstandingClasses
          : topOutstandingClasses // ignore: cast_nullable_to_non_nullable
              as List<OutstandingClassDto>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardSummaryDtoImplCopyWith<$Res>
    implements $DashboardSummaryDtoCopyWith<$Res> {
  factory _$$DashboardSummaryDtoImplCopyWith(_$DashboardSummaryDtoImpl value,
          $Res Function(_$DashboardSummaryDtoImpl) then) =
      __$$DashboardSummaryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'today_collection') double todayCollection,
      @JsonKey(name: 'month_collection') double monthCollection,
      @JsonKey(name: 'pending_dues') double pendingDues,
      @JsonKey(name: 'collection_percentage') double collectionPercentage,
      @JsonKey(name: 'defaulters_count') int defaultersCount,
      @JsonKey(name: 'top_outstanding_classes')
      List<OutstandingClassDto> topOutstandingClasses});
}

/// @nodoc
class __$$DashboardSummaryDtoImplCopyWithImpl<$Res>
    extends _$DashboardSummaryDtoCopyWithImpl<$Res, _$DashboardSummaryDtoImpl>
    implements _$$DashboardSummaryDtoImplCopyWith<$Res> {
  __$$DashboardSummaryDtoImplCopyWithImpl(_$DashboardSummaryDtoImpl _value,
      $Res Function(_$DashboardSummaryDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayCollection = null,
    Object? monthCollection = null,
    Object? pendingDues = null,
    Object? collectionPercentage = null,
    Object? defaultersCount = null,
    Object? topOutstandingClasses = null,
  }) {
    return _then(_$DashboardSummaryDtoImpl(
      todayCollection: null == todayCollection
          ? _value.todayCollection
          : todayCollection // ignore: cast_nullable_to_non_nullable
              as double,
      monthCollection: null == monthCollection
          ? _value.monthCollection
          : monthCollection // ignore: cast_nullable_to_non_nullable
              as double,
      pendingDues: null == pendingDues
          ? _value.pendingDues
          : pendingDues // ignore: cast_nullable_to_non_nullable
              as double,
      collectionPercentage: null == collectionPercentage
          ? _value.collectionPercentage
          : collectionPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      defaultersCount: null == defaultersCount
          ? _value.defaultersCount
          : defaultersCount // ignore: cast_nullable_to_non_nullable
              as int,
      topOutstandingClasses: null == topOutstandingClasses
          ? _value._topOutstandingClasses
          : topOutstandingClasses // ignore: cast_nullable_to_non_nullable
              as List<OutstandingClassDto>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardSummaryDtoImpl implements _DashboardSummaryDto {
  const _$DashboardSummaryDtoImpl(
      {@JsonKey(name: 'today_collection') required this.todayCollection,
      @JsonKey(name: 'month_collection') required this.monthCollection,
      @JsonKey(name: 'pending_dues') required this.pendingDues,
      @JsonKey(name: 'collection_percentage')
      required this.collectionPercentage,
      @JsonKey(name: 'defaulters_count') required this.defaultersCount,
      @JsonKey(name: 'top_outstanding_classes')
      required final List<OutstandingClassDto> topOutstandingClasses})
      : _topOutstandingClasses = topOutstandingClasses;

  factory _$DashboardSummaryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardSummaryDtoImplFromJson(json);

  @override
  @JsonKey(name: 'today_collection')
  final double todayCollection;
  @override
  @JsonKey(name: 'month_collection')
  final double monthCollection;
  @override
  @JsonKey(name: 'pending_dues')
  final double pendingDues;
  @override
  @JsonKey(name: 'collection_percentage')
  final double collectionPercentage;
  @override
  @JsonKey(name: 'defaulters_count')
  final int defaultersCount;
  final List<OutstandingClassDto> _topOutstandingClasses;
  @override
  @JsonKey(name: 'top_outstanding_classes')
  List<OutstandingClassDto> get topOutstandingClasses {
    if (_topOutstandingClasses is EqualUnmodifiableListView)
      return _topOutstandingClasses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topOutstandingClasses);
  }

  @override
  String toString() {
    return 'DashboardSummaryDto(todayCollection: $todayCollection, monthCollection: $monthCollection, pendingDues: $pendingDues, collectionPercentage: $collectionPercentage, defaultersCount: $defaultersCount, topOutstandingClasses: $topOutstandingClasses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSummaryDtoImpl &&
            (identical(other.todayCollection, todayCollection) ||
                other.todayCollection == todayCollection) &&
            (identical(other.monthCollection, monthCollection) ||
                other.monthCollection == monthCollection) &&
            (identical(other.pendingDues, pendingDues) ||
                other.pendingDues == pendingDues) &&
            (identical(other.collectionPercentage, collectionPercentage) ||
                other.collectionPercentage == collectionPercentage) &&
            (identical(other.defaultersCount, defaultersCount) ||
                other.defaultersCount == defaultersCount) &&
            const DeepCollectionEquality()
                .equals(other._topOutstandingClasses, _topOutstandingClasses));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      todayCollection,
      monthCollection,
      pendingDues,
      collectionPercentage,
      defaultersCount,
      const DeepCollectionEquality().hash(_topOutstandingClasses));

  /// Create a copy of DashboardSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSummaryDtoImplCopyWith<_$DashboardSummaryDtoImpl> get copyWith =>
      __$$DashboardSummaryDtoImplCopyWithImpl<_$DashboardSummaryDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardSummaryDtoImplToJson(
      this,
    );
  }
}

abstract class _DashboardSummaryDto implements DashboardSummaryDto {
  const factory _DashboardSummaryDto(
      {@JsonKey(name: 'today_collection') required final double todayCollection,
      @JsonKey(name: 'month_collection') required final double monthCollection,
      @JsonKey(name: 'pending_dues') required final double pendingDues,
      @JsonKey(name: 'collection_percentage')
      required final double collectionPercentage,
      @JsonKey(name: 'defaulters_count') required final int defaultersCount,
      @JsonKey(name: 'top_outstanding_classes')
      required final List<OutstandingClassDto>
          topOutstandingClasses}) = _$DashboardSummaryDtoImpl;

  factory _DashboardSummaryDto.fromJson(Map<String, dynamic> json) =
      _$DashboardSummaryDtoImpl.fromJson;

  @override
  @JsonKey(name: 'today_collection')
  double get todayCollection;
  @override
  @JsonKey(name: 'month_collection')
  double get monthCollection;
  @override
  @JsonKey(name: 'pending_dues')
  double get pendingDues;
  @override
  @JsonKey(name: 'collection_percentage')
  double get collectionPercentage;
  @override
  @JsonKey(name: 'defaulters_count')
  int get defaultersCount;
  @override
  @JsonKey(name: 'top_outstanding_classes')
  List<OutstandingClassDto> get topOutstandingClasses;

  /// Create a copy of DashboardSummaryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardSummaryDtoImplCopyWith<_$DashboardSummaryDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
