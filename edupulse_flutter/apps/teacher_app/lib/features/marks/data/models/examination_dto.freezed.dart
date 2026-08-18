// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'examination_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExaminationDto _$ExaminationDtoFromJson(Map<String, dynamic> json) {
  return _ExaminationDto.fromJson(json);
}

/// @nodoc
mixin _$ExaminationDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'exam_name')
  String get examName => throw _privateConstructorUsedError;
  @JsonKey(name: 'exam_type')
  String get examType => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  String get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  String get endDate => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  Map<String, dynamic> get settings => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  String get updatedAt => throw _privateConstructorUsedError;
  List<ExamScheduleDto> get schedules => throw _privateConstructorUsedError;

  /// Serializes this ExaminationDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExaminationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExaminationDtoCopyWith<ExaminationDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExaminationDtoCopyWith<$Res> {
  factory $ExaminationDtoCopyWith(
          ExaminationDto value, $Res Function(ExaminationDto) then) =
      _$ExaminationDtoCopyWithImpl<$Res, ExaminationDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'exam_name') String examName,
      @JsonKey(name: 'exam_type') String examType,
      @JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      String status,
      String? description,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt,
      List<ExamScheduleDto> schedules});
}

/// @nodoc
class _$ExaminationDtoCopyWithImpl<$Res, $Val extends ExaminationDto>
    implements $ExaminationDtoCopyWith<$Res> {
  _$ExaminationDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExaminationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? examName = null,
    Object? examType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? status = null,
    Object? description = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? isActive = null,
    Object? version = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? schedules = null,
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
      academicYearId: null == academicYearId
          ? _value.academicYearId
          : academicYearId // ignore: cast_nullable_to_non_nullable
              as String,
      examName: null == examName
          ? _value.examName
          : examName // ignore: cast_nullable_to_non_nullable
              as String,
      examType: null == examType
          ? _value.examType
          : examType // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value.aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      schedules: null == schedules
          ? _value.schedules
          : schedules // ignore: cast_nullable_to_non_nullable
              as List<ExamScheduleDto>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExaminationDtoImplCopyWith<$Res>
    implements $ExaminationDtoCopyWith<$Res> {
  factory _$$ExaminationDtoImplCopyWith(_$ExaminationDtoImpl value,
          $Res Function(_$ExaminationDtoImpl) then) =
      __$$ExaminationDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'exam_name') String examName,
      @JsonKey(name: 'exam_type') String examType,
      @JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      String status,
      String? description,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt,
      List<ExamScheduleDto> schedules});
}

/// @nodoc
class __$$ExaminationDtoImplCopyWithImpl<$Res>
    extends _$ExaminationDtoCopyWithImpl<$Res, _$ExaminationDtoImpl>
    implements _$$ExaminationDtoImplCopyWith<$Res> {
  __$$ExaminationDtoImplCopyWithImpl(
      _$ExaminationDtoImpl _value, $Res Function(_$ExaminationDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExaminationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? examName = null,
    Object? examType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? status = null,
    Object? description = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? isActive = null,
    Object? version = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? schedules = null,
  }) {
    return _then(_$ExaminationDtoImpl(
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
      academicYearId: null == academicYearId
          ? _value.academicYearId
          : academicYearId // ignore: cast_nullable_to_non_nullable
              as String,
      examName: null == examName
          ? _value.examName
          : examName // ignore: cast_nullable_to_non_nullable
              as String,
      examType: null == examType
          ? _value.examType
          : examType // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      aiMetrics: null == aiMetrics
          ? _value._aiMetrics
          : aiMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      schedules: null == schedules
          ? _value._schedules
          : schedules // ignore: cast_nullable_to_non_nullable
              as List<ExamScheduleDto>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExaminationDtoImpl extends _ExaminationDto {
  const _$ExaminationDtoImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'exam_name') required this.examName,
      @JsonKey(name: 'exam_type') required this.examType,
      @JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') required this.endDate,
      required this.status,
      this.description,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') required this.isActive,
      required this.version,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      final List<ExamScheduleDto> schedules = const []})
      : _settings = settings,
        _aiMetrics = aiMetrics,
        _schedules = schedules,
        super._();

  factory _$ExaminationDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExaminationDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'school_id')
  final String schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  final String academicYearId;
  @override
  @JsonKey(name: 'exam_name')
  final String examName;
  @override
  @JsonKey(name: 'exam_type')
  final String examType;
  @override
  @JsonKey(name: 'start_date')
  final String startDate;
  @override
  @JsonKey(name: 'end_date')
  final String endDate;
  @override
  final String status;
  @override
  final String? description;
  final Map<String, dynamic> _settings;
  @override
  Map<String, dynamic> get settings {
    if (_settings is EqualUnmodifiableMapView) return _settings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_settings);
  }

  final Map<String, dynamic> _aiMetrics;
  @override
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics {
    if (_aiMetrics is EqualUnmodifiableMapView) return _aiMetrics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_aiMetrics);
  }

  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  final int version;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final String updatedAt;
  final List<ExamScheduleDto> _schedules;
  @override
  @JsonKey()
  List<ExamScheduleDto> get schedules {
    if (_schedules is EqualUnmodifiableListView) return _schedules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_schedules);
  }

  @override
  String toString() {
    return 'ExaminationDto(id: $id, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, examName: $examName, examType: $examType, startDate: $startDate, endDate: $endDate, status: $status, description: $description, settings: $settings, aiMetrics: $aiMetrics, isActive: $isActive, version: $version, createdAt: $createdAt, updatedAt: $updatedAt, schedules: $schedules)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExaminationDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.examName, examName) ||
                other.examName == examName) &&
            (identical(other.examType, examType) ||
                other.examType == examType) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._settings, _settings) &&
            const DeepCollectionEquality()
                .equals(other._aiMetrics, _aiMetrics) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality()
                .equals(other._schedules, _schedules));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      schoolId,
      academicYearId,
      examName,
      examType,
      startDate,
      endDate,
      status,
      description,
      const DeepCollectionEquality().hash(_settings),
      const DeepCollectionEquality().hash(_aiMetrics),
      isActive,
      version,
      createdAt,
      updatedAt,
      const DeepCollectionEquality().hash(_schedules));

  /// Create a copy of ExaminationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExaminationDtoImplCopyWith<_$ExaminationDtoImpl> get copyWith =>
      __$$ExaminationDtoImplCopyWithImpl<_$ExaminationDtoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExaminationDtoImplToJson(
      this,
    );
  }
}

abstract class _ExaminationDto extends ExaminationDto {
  const factory _ExaminationDto(
      {required final String id,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'exam_name') required final String examName,
      @JsonKey(name: 'exam_type') required final String examType,
      @JsonKey(name: 'start_date') required final String startDate,
      @JsonKey(name: 'end_date') required final String endDate,
      required final String status,
      final String? description,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final int version,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'updated_at') required final String updatedAt,
      final List<ExamScheduleDto> schedules}) = _$ExaminationDtoImpl;
  const _ExaminationDto._() : super._();

  factory _ExaminationDto.fromJson(Map<String, dynamic> json) =
      _$ExaminationDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'school_id')
  String get schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  String get academicYearId;
  @override
  @JsonKey(name: 'exam_name')
  String get examName;
  @override
  @JsonKey(name: 'exam_type')
  String get examType;
  @override
  @JsonKey(name: 'start_date')
  String get startDate;
  @override
  @JsonKey(name: 'end_date')
  String get endDate;
  @override
  String get status;
  @override
  String? get description;
  @override
  Map<String, dynamic> get settings;
  @override
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  int get version;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  String get updatedAt;
  @override
  List<ExamScheduleDto> get schedules;

  /// Create a copy of ExaminationDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExaminationDtoImplCopyWith<_$ExaminationDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
