// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timetable_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TimetableDto _$TimetableDtoFromJson(Map<String, dynamic> json) {
  return _TimetableDto.fromJson(json);
}

/// @nodoc
mixin _$TimetableDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'day_of_week')
  String get dayOfWeek => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_number')
  int get periodNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_time')
  String get startTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_time')
  String get endTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_type')
  String get periodType => throw _privateConstructorUsedError;
  @JsonKey(name: 'room_id')
  String? get roomId => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_available')
  bool get isAvailable => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String? get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String? get teacherId => throw _privateConstructorUsedError;

  /// Serializes this TimetableDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimetableDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimetableDtoCopyWith<TimetableDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimetableDtoCopyWith<$Res> {
  factory $TimetableDtoCopyWith(
          TimetableDto value, $Res Function(TimetableDto) then) =
      _$TimetableDtoCopyWithImpl<$Res, TimetableDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'day_of_week') String dayOfWeek,
      @JsonKey(name: 'period_number') int periodNumber,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'period_type') String periodType,
      @JsonKey(name: 'room_id') String? roomId,
      @JsonKey(name: 'is_available') bool isAvailable,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'teacher_id') String? teacherId});
}

/// @nodoc
class _$TimetableDtoCopyWithImpl<$Res, $Val extends TimetableDto>
    implements $TimetableDtoCopyWith<$Res> {
  _$TimetableDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimetableDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? dayOfWeek = null,
    Object? periodNumber = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? periodType = null,
    Object? roomId = freezed,
    Object? isAvailable = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? subjectId = freezed,
    Object? teacherId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _value.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as String,
      periodNumber: null == periodNumber
          ? _value.periodNumber
          : periodNumber // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      periodType: null == periodType
          ? _value.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: freezed == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String?,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimetableDtoImplCopyWith<$Res>
    implements $TimetableDtoCopyWith<$Res> {
  factory _$$TimetableDtoImplCopyWith(
          _$TimetableDtoImpl value, $Res Function(_$TimetableDtoImpl) then) =
      __$$TimetableDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'day_of_week') String dayOfWeek,
      @JsonKey(name: 'period_number') int periodNumber,
      @JsonKey(name: 'start_time') String startTime,
      @JsonKey(name: 'end_time') String endTime,
      @JsonKey(name: 'period_type') String periodType,
      @JsonKey(name: 'room_id') String? roomId,
      @JsonKey(name: 'is_available') bool isAvailable,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId,
      @JsonKey(name: 'subject_id') String? subjectId,
      @JsonKey(name: 'teacher_id') String? teacherId});
}

/// @nodoc
class __$$TimetableDtoImplCopyWithImpl<$Res>
    extends _$TimetableDtoCopyWithImpl<$Res, _$TimetableDtoImpl>
    implements _$$TimetableDtoImplCopyWith<$Res> {
  __$$TimetableDtoImplCopyWithImpl(
      _$TimetableDtoImpl _value, $Res Function(_$TimetableDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TimetableDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? dayOfWeek = null,
    Object? periodNumber = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? periodType = null,
    Object? roomId = freezed,
    Object? isAvailable = null,
    Object? classId = null,
    Object? sectionId = null,
    Object? subjectId = freezed,
    Object? teacherId = freezed,
  }) {
    return _then(_$TimetableDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      dayOfWeek: null == dayOfWeek
          ? _value.dayOfWeek
          : dayOfWeek // ignore: cast_nullable_to_non_nullable
              as String,
      periodNumber: null == periodNumber
          ? _value.periodNumber
          : periodNumber // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      periodType: null == periodType
          ? _value.periodType
          : periodType // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: freezed == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String?,
      teacherId: freezed == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimetableDtoImpl implements _TimetableDto {
  const _$TimetableDtoImpl(
      {required this.id,
      @JsonKey(name: 'day_of_week') required this.dayOfWeek,
      @JsonKey(name: 'period_number') required this.periodNumber,
      @JsonKey(name: 'start_time') required this.startTime,
      @JsonKey(name: 'end_time') required this.endTime,
      @JsonKey(name: 'period_type') required this.periodType,
      @JsonKey(name: 'room_id') this.roomId,
      @JsonKey(name: 'is_available') required this.isAvailable,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId,
      @JsonKey(name: 'subject_id') this.subjectId,
      @JsonKey(name: 'teacher_id') this.teacherId});

  factory _$TimetableDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimetableDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'day_of_week')
  final String dayOfWeek;
  @override
  @JsonKey(name: 'period_number')
  final int periodNumber;
  @override
  @JsonKey(name: 'start_time')
  final String startTime;
  @override
  @JsonKey(name: 'end_time')
  final String endTime;
  @override
  @JsonKey(name: 'period_type')
  final String periodType;
  @override
  @JsonKey(name: 'room_id')
  final String? roomId;
  @override
  @JsonKey(name: 'is_available')
  final bool isAvailable;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;
  @override
  @JsonKey(name: 'subject_id')
  final String? subjectId;
  @override
  @JsonKey(name: 'teacher_id')
  final String? teacherId;

  @override
  String toString() {
    return 'TimetableDto(id: $id, dayOfWeek: $dayOfWeek, periodNumber: $periodNumber, startTime: $startTime, endTime: $endTime, periodType: $periodType, roomId: $roomId, isAvailable: $isAvailable, classId: $classId, sectionId: $sectionId, subjectId: $subjectId, teacherId: $teacherId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimetableDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.periodNumber, periodNumber) ||
                other.periodNumber == periodNumber) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.periodType, periodType) ||
                other.periodType == periodType) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      dayOfWeek,
      periodNumber,
      startTime,
      endTime,
      periodType,
      roomId,
      isAvailable,
      classId,
      sectionId,
      subjectId,
      teacherId);

  /// Create a copy of TimetableDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimetableDtoImplCopyWith<_$TimetableDtoImpl> get copyWith =>
      __$$TimetableDtoImplCopyWithImpl<_$TimetableDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimetableDtoImplToJson(
      this,
    );
  }
}

abstract class _TimetableDto implements TimetableDto {
  const factory _TimetableDto(
          {required final String id,
          @JsonKey(name: 'day_of_week') required final String dayOfWeek,
          @JsonKey(name: 'period_number') required final int periodNumber,
          @JsonKey(name: 'start_time') required final String startTime,
          @JsonKey(name: 'end_time') required final String endTime,
          @JsonKey(name: 'period_type') required final String periodType,
          @JsonKey(name: 'room_id') final String? roomId,
          @JsonKey(name: 'is_available') required final bool isAvailable,
          @JsonKey(name: 'class_id') required final String classId,
          @JsonKey(name: 'section_id') required final String sectionId,
          @JsonKey(name: 'subject_id') final String? subjectId,
          @JsonKey(name: 'teacher_id') final String? teacherId}) =
      _$TimetableDtoImpl;

  factory _TimetableDto.fromJson(Map<String, dynamic> json) =
      _$TimetableDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'day_of_week')
  String get dayOfWeek;
  @override
  @JsonKey(name: 'period_number')
  int get periodNumber;
  @override
  @JsonKey(name: 'start_time')
  String get startTime;
  @override
  @JsonKey(name: 'end_time')
  String get endTime;
  @override
  @JsonKey(name: 'period_type')
  String get periodType;
  @override
  @JsonKey(name: 'room_id')
  String? get roomId;
  @override
  @JsonKey(name: 'is_available')
  bool get isAvailable;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;
  @override
  @JsonKey(name: 'subject_id')
  String? get subjectId;
  @override
  @JsonKey(name: 'teacher_id')
  String? get teacherId;

  /// Create a copy of TimetableDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimetableDtoImplCopyWith<_$TimetableDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
