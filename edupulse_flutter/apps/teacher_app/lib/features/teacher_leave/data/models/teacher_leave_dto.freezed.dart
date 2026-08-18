// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teacher_leave_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TeacherLeaveDto _$TeacherLeaveDtoFromJson(Map<String, dynamic> json) {
  return _TeacherLeaveDto.fromJson(json);
}

/// @nodoc
mixin _$TeacherLeaveDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String get teacherId => throw _privateConstructorUsedError;
  @JsonKey(name: 'leave_type')
  String get leaveType => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  String get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  String get endDate => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  String? get remarks => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'requested_at')
  String get requestedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_at')
  String? get reviewedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_by')
  String? get reviewedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewer_remarks')
  String? get reviewerRemarks => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancelled_at')
  String? get cancelledAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancellation_reason')
  String? get cancellationReason => throw _privateConstructorUsedError;

  /// Serializes this TeacherLeaveDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeacherLeaveDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeacherLeaveDtoCopyWith<TeacherLeaveDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeacherLeaveDtoCopyWith<$Res> {
  factory $TeacherLeaveDtoCopyWith(
          TeacherLeaveDto value, $Res Function(TeacherLeaveDto) then) =
      _$TeacherLeaveDtoCopyWithImpl<$Res, TeacherLeaveDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'leave_type') String leaveType,
      @JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      String reason,
      String? remarks,
      String status,
      @JsonKey(name: 'requested_at') String requestedAt,
      @JsonKey(name: 'reviewed_at') String? reviewedAt,
      @JsonKey(name: 'reviewed_by') String? reviewedBy,
      @JsonKey(name: 'reviewer_remarks') String? reviewerRemarks,
      @JsonKey(name: 'cancelled_at') String? cancelledAt,
      @JsonKey(name: 'cancellation_reason') String? cancellationReason});
}

/// @nodoc
class _$TeacherLeaveDtoCopyWithImpl<$Res, $Val extends TeacherLeaveDto>
    implements $TeacherLeaveDtoCopyWith<$Res> {
  _$TeacherLeaveDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeacherLeaveDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? teacherId = null,
    Object? leaveType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? reason = null,
    Object? remarks = freezed,
    Object? status = null,
    Object? requestedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
    Object? reviewerRemarks = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      leaveType: null == leaveType
          ? _value.leaveType
          : leaveType // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as String,
      reviewedAt: freezed == reviewedAt
          ? _value.reviewedAt
          : reviewedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewedBy: freezed == reviewedBy
          ? _value.reviewedBy
          : reviewedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewerRemarks: freezed == reviewerRemarks
          ? _value.reviewerRemarks
          : reviewerRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as String?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TeacherLeaveDtoImplCopyWith<$Res>
    implements $TeacherLeaveDtoCopyWith<$Res> {
  factory _$$TeacherLeaveDtoImplCopyWith(_$TeacherLeaveDtoImpl value,
          $Res Function(_$TeacherLeaveDtoImpl) then) =
      __$$TeacherLeaveDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'teacher_id') String teacherId,
      @JsonKey(name: 'leave_type') String leaveType,
      @JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      String reason,
      String? remarks,
      String status,
      @JsonKey(name: 'requested_at') String requestedAt,
      @JsonKey(name: 'reviewed_at') String? reviewedAt,
      @JsonKey(name: 'reviewed_by') String? reviewedBy,
      @JsonKey(name: 'reviewer_remarks') String? reviewerRemarks,
      @JsonKey(name: 'cancelled_at') String? cancelledAt,
      @JsonKey(name: 'cancellation_reason') String? cancellationReason});
}

/// @nodoc
class __$$TeacherLeaveDtoImplCopyWithImpl<$Res>
    extends _$TeacherLeaveDtoCopyWithImpl<$Res, _$TeacherLeaveDtoImpl>
    implements _$$TeacherLeaveDtoImplCopyWith<$Res> {
  __$$TeacherLeaveDtoImplCopyWithImpl(
      _$TeacherLeaveDtoImpl _value, $Res Function(_$TeacherLeaveDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TeacherLeaveDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? teacherId = null,
    Object? leaveType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? reason = null,
    Object? remarks = freezed,
    Object? status = null,
    Object? requestedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
    Object? reviewerRemarks = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
  }) {
    return _then(_$TeacherLeaveDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      schoolId: null == schoolId
          ? _value.schoolId
          : schoolId // ignore: cast_nullable_to_non_nullable
              as String,
      teacherId: null == teacherId
          ? _value.teacherId
          : teacherId // ignore: cast_nullable_to_non_nullable
              as String,
      leaveType: null == leaveType
          ? _value.leaveType
          : leaveType // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      remarks: freezed == remarks
          ? _value.remarks
          : remarks // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as String,
      reviewedAt: freezed == reviewedAt
          ? _value.reviewedAt
          : reviewedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewedBy: freezed == reviewedBy
          ? _value.reviewedBy
          : reviewedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewerRemarks: freezed == reviewerRemarks
          ? _value.reviewerRemarks
          : reviewerRemarks // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as String?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TeacherLeaveDtoImpl implements _TeacherLeaveDto {
  const _$TeacherLeaveDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'teacher_id') required this.teacherId,
      @JsonKey(name: 'leave_type') required this.leaveType,
      @JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') required this.endDate,
      required this.reason,
      this.remarks,
      required this.status,
      @JsonKey(name: 'requested_at') required this.requestedAt,
      @JsonKey(name: 'reviewed_at') this.reviewedAt,
      @JsonKey(name: 'reviewed_by') this.reviewedBy,
      @JsonKey(name: 'reviewer_remarks') this.reviewerRemarks,
      @JsonKey(name: 'cancelled_at') this.cancelledAt,
      @JsonKey(name: 'cancellation_reason') this.cancellationReason});

  factory _$TeacherLeaveDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeacherLeaveDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'school_id')
  final String schoolId;
  @override
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @override
  @JsonKey(name: 'leave_type')
  final String leaveType;
  @override
  @JsonKey(name: 'start_date')
  final String startDate;
  @override
  @JsonKey(name: 'end_date')
  final String endDate;
  @override
  final String reason;
  @override
  final String? remarks;
  @override
  final String status;
  @override
  @JsonKey(name: 'requested_at')
  final String requestedAt;
  @override
  @JsonKey(name: 'reviewed_at')
  final String? reviewedAt;
  @override
  @JsonKey(name: 'reviewed_by')
  final String? reviewedBy;
  @override
  @JsonKey(name: 'reviewer_remarks')
  final String? reviewerRemarks;
  @override
  @JsonKey(name: 'cancelled_at')
  final String? cancelledAt;
  @override
  @JsonKey(name: 'cancellation_reason')
  final String? cancellationReason;

  @override
  String toString() {
    return 'TeacherLeaveDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, teacherId: $teacherId, leaveType: $leaveType, startDate: $startDate, endDate: $endDate, reason: $reason, remarks: $remarks, status: $status, requestedAt: $requestedAt, reviewedAt: $reviewedAt, reviewedBy: $reviewedBy, reviewerRemarks: $reviewerRemarks, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeacherLeaveDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId) &&
            (identical(other.leaveType, leaveType) ||
                other.leaveType == leaveType) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.remarks, remarks) || other.remarks == remarks) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.requestedAt, requestedAt) ||
                other.requestedAt == requestedAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.reviewerRemarks, reviewerRemarks) ||
                other.reviewerRemarks == reviewerRemarks) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      schoolId,
      teacherId,
      leaveType,
      startDate,
      endDate,
      reason,
      remarks,
      status,
      requestedAt,
      reviewedAt,
      reviewedBy,
      reviewerRemarks,
      cancelledAt,
      cancellationReason);

  /// Create a copy of TeacherLeaveDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeacherLeaveDtoImplCopyWith<_$TeacherLeaveDtoImpl> get copyWith =>
      __$$TeacherLeaveDtoImplCopyWithImpl<_$TeacherLeaveDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeacherLeaveDtoImplToJson(
      this,
    );
  }
}

abstract class _TeacherLeaveDto implements TeacherLeaveDto {
  const factory _TeacherLeaveDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'teacher_id') required final String teacherId,
      @JsonKey(name: 'leave_type') required final String leaveType,
      @JsonKey(name: 'start_date') required final String startDate,
      @JsonKey(name: 'end_date') required final String endDate,
      required final String reason,
      final String? remarks,
      required final String status,
      @JsonKey(name: 'requested_at') required final String requestedAt,
      @JsonKey(name: 'reviewed_at') final String? reviewedAt,
      @JsonKey(name: 'reviewed_by') final String? reviewedBy,
      @JsonKey(name: 'reviewer_remarks') final String? reviewerRemarks,
      @JsonKey(name: 'cancelled_at') final String? cancelledAt,
      @JsonKey(name: 'cancellation_reason')
      final String? cancellationReason}) = _$TeacherLeaveDtoImpl;

  factory _TeacherLeaveDto.fromJson(Map<String, dynamic> json) =
      _$TeacherLeaveDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'school_id')
  String get schoolId;
  @override
  @JsonKey(name: 'teacher_id')
  String get teacherId;
  @override
  @JsonKey(name: 'leave_type')
  String get leaveType;
  @override
  @JsonKey(name: 'start_date')
  String get startDate;
  @override
  @JsonKey(name: 'end_date')
  String get endDate;
  @override
  String get reason;
  @override
  String? get remarks;
  @override
  String get status;
  @override
  @JsonKey(name: 'requested_at')
  String get requestedAt;
  @override
  @JsonKey(name: 'reviewed_at')
  String? get reviewedAt;
  @override
  @JsonKey(name: 'reviewed_by')
  String? get reviewedBy;
  @override
  @JsonKey(name: 'reviewer_remarks')
  String? get reviewerRemarks;
  @override
  @JsonKey(name: 'cancelled_at')
  String? get cancelledAt;
  @override
  @JsonKey(name: 'cancellation_reason')
  String? get cancellationReason;

  /// Create a copy of TeacherLeaveDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeacherLeaveDtoImplCopyWith<_$TeacherLeaveDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
