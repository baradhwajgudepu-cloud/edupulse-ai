// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_card_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReportCardDto _$ReportCardDtoFromJson(Map<String, dynamic> json) {
  return _ReportCardDto.fromJson(json);
}

/// @nodoc
mixin _$ReportCardDto {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'verification_uuid')
  String get verificationUuid => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'pdf_url')
  String? get pdfUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'pdf_history')
  List<Map<String, dynamic>> get pdfHistory =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'generated_at')
  String? get generatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'published_at')
  String? get publishedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'approved_at')
  String? get approvedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'generated_by')
  String? get generatedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'published_by')
  String? get publishedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'approved_by')
  String? get approvedBy => throw _privateConstructorUsedError;
  Map<String, dynamic> get settings => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_metrics')
  Map<String, dynamic> get aiMetrics => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_id')
  String get schoolId => throw _privateConstructorUsedError;
  @JsonKey(name: 'academic_year_id')
  String get academicYearId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  String get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ReportCardDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReportCardDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportCardDtoCopyWith<ReportCardDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportCardDtoCopyWith<$Res> {
  factory $ReportCardDtoCopyWith(
          ReportCardDto value, $Res Function(ReportCardDto) then) =
      _$ReportCardDtoCopyWithImpl<$Res, ReportCardDto>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'verification_uuid') String verificationUuid,
      String status,
      @JsonKey(name: 'pdf_url') String? pdfUrl,
      @JsonKey(name: 'pdf_history') List<Map<String, dynamic>> pdfHistory,
      @JsonKey(name: 'generated_at') String? generatedAt,
      @JsonKey(name: 'published_at') String? publishedAt,
      @JsonKey(name: 'approved_at') String? approvedAt,
      @JsonKey(name: 'generated_by') String? generatedBy,
      @JsonKey(name: 'published_by') String? publishedBy,
      @JsonKey(name: 'approved_by') String? approvedBy,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class _$ReportCardDtoCopyWithImpl<$Res, $Val extends ReportCardDto>
    implements $ReportCardDtoCopyWith<$Res> {
  _$ReportCardDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportCardDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? verificationUuid = null,
    Object? status = null,
    Object? pdfUrl = freezed,
    Object? pdfHistory = null,
    Object? generatedAt = freezed,
    Object? publishedAt = freezed,
    Object? approvedAt = freezed,
    Object? generatedBy = freezed,
    Object? publishedBy = freezed,
    Object? approvedBy = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? isActive = null,
    Object? version = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? studentId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      verificationUuid: null == verificationUuid
          ? _value.verificationUuid
          : verificationUuid // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      pdfUrl: freezed == pdfUrl
          ? _value.pdfUrl
          : pdfUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pdfHistory: null == pdfHistory
          ? _value.pdfHistory
          : pdfHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedAt: freezed == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _value.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      generatedBy: freezed == generatedBy
          ? _value.generatedBy
          : generatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedBy: freezed == publishedBy
          ? _value.publishedBy
          : publishedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _value.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
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
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReportCardDtoImplCopyWith<$Res>
    implements $ReportCardDtoCopyWith<$Res> {
  factory _$$ReportCardDtoImplCopyWith(
          _$ReportCardDtoImpl value, $Res Function(_$ReportCardDtoImpl) then) =
      __$$ReportCardDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'verification_uuid') String verificationUuid,
      String status,
      @JsonKey(name: 'pdf_url') String? pdfUrl,
      @JsonKey(name: 'pdf_history') List<Map<String, dynamic>> pdfHistory,
      @JsonKey(name: 'generated_at') String? generatedAt,
      @JsonKey(name: 'published_at') String? publishedAt,
      @JsonKey(name: 'approved_at') String? approvedAt,
      @JsonKey(name: 'generated_by') String? generatedBy,
      @JsonKey(name: 'published_by') String? publishedBy,
      @JsonKey(name: 'approved_by') String? approvedBy,
      Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics') Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') bool isActive,
      int version,
      @JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'school_id') String schoolId,
      @JsonKey(name: 'academic_year_id') String academicYearId,
      @JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class __$$ReportCardDtoImplCopyWithImpl<$Res>
    extends _$ReportCardDtoCopyWithImpl<$Res, _$ReportCardDtoImpl>
    implements _$$ReportCardDtoImplCopyWith<$Res> {
  __$$ReportCardDtoImplCopyWithImpl(
      _$ReportCardDtoImpl _value, $Res Function(_$ReportCardDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReportCardDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? verificationUuid = null,
    Object? status = null,
    Object? pdfUrl = freezed,
    Object? pdfHistory = null,
    Object? generatedAt = freezed,
    Object? publishedAt = freezed,
    Object? approvedAt = freezed,
    Object? generatedBy = freezed,
    Object? publishedBy = freezed,
    Object? approvedBy = freezed,
    Object? settings = null,
    Object? aiMetrics = null,
    Object? isActive = null,
    Object? version = null,
    Object? tenantId = null,
    Object? schoolId = null,
    Object? academicYearId = null,
    Object? studentId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$ReportCardDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      verificationUuid: null == verificationUuid
          ? _value.verificationUuid
          : verificationUuid // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      pdfUrl: freezed == pdfUrl
          ? _value.pdfUrl
          : pdfUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pdfHistory: null == pdfHistory
          ? _value._pdfHistory
          : pdfHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedAt: freezed == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _value.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as String?,
      generatedBy: freezed == generatedBy
          ? _value.generatedBy
          : generatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      publishedBy: freezed == publishedBy
          ? _value.publishedBy
          : publishedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _value.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
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
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReportCardDtoImpl extends _ReportCardDto {
  const _$ReportCardDtoImpl(
      {required this.id,
      @JsonKey(name: 'verification_uuid') required this.verificationUuid,
      required this.status,
      @JsonKey(name: 'pdf_url') this.pdfUrl,
      @JsonKey(name: 'pdf_history')
      required final List<Map<String, dynamic>> pdfHistory,
      @JsonKey(name: 'generated_at') this.generatedAt,
      @JsonKey(name: 'published_at') this.publishedAt,
      @JsonKey(name: 'approved_at') this.approvedAt,
      @JsonKey(name: 'generated_by') this.generatedBy,
      @JsonKey(name: 'published_by') this.publishedBy,
      @JsonKey(name: 'approved_by') this.approvedBy,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') required this.isActive,
      required this.version,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'school_id') required this.schoolId,
      @JsonKey(name: 'academic_year_id') required this.academicYearId,
      @JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt})
      : _pdfHistory = pdfHistory,
        _settings = settings,
        _aiMetrics = aiMetrics,
        super._();

  factory _$ReportCardDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReportCardDtoImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'verification_uuid')
  final String verificationUuid;
  @override
  final String status;
  @override
  @JsonKey(name: 'pdf_url')
  final String? pdfUrl;
  final List<Map<String, dynamic>> _pdfHistory;
  @override
  @JsonKey(name: 'pdf_history')
  List<Map<String, dynamic>> get pdfHistory {
    if (_pdfHistory is EqualUnmodifiableListView) return _pdfHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pdfHistory);
  }

  @override
  @JsonKey(name: 'generated_at')
  final String? generatedAt;
  @override
  @JsonKey(name: 'published_at')
  final String? publishedAt;
  @override
  @JsonKey(name: 'approved_at')
  final String? approvedAt;
  @override
  @JsonKey(name: 'generated_by')
  final String? generatedBy;
  @override
  @JsonKey(name: 'published_by')
  final String? publishedBy;
  @override
  @JsonKey(name: 'approved_by')
  final String? approvedBy;
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
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'school_id')
  final String schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  final String academicYearId;
  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  @override
  String toString() {
    return 'ReportCardDto(id: $id, verificationUuid: $verificationUuid, status: $status, pdfUrl: $pdfUrl, pdfHistory: $pdfHistory, generatedAt: $generatedAt, publishedAt: $publishedAt, approvedAt: $approvedAt, generatedBy: $generatedBy, publishedBy: $publishedBy, approvedBy: $approvedBy, settings: $settings, aiMetrics: $aiMetrics, isActive: $isActive, version: $version, tenantId: $tenantId, schoolId: $schoolId, academicYearId: $academicYearId, studentId: $studentId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportCardDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.verificationUuid, verificationUuid) ||
                other.verificationUuid == verificationUuid) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.pdfUrl, pdfUrl) || other.pdfUrl == pdfUrl) &&
            const DeepCollectionEquality()
                .equals(other._pdfHistory, _pdfHistory) &&
            (identical(other.generatedAt, generatedAt) ||
                other.generatedAt == generatedAt) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.generatedBy, generatedBy) ||
                other.generatedBy == generatedBy) &&
            (identical(other.publishedBy, publishedBy) ||
                other.publishedBy == publishedBy) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            const DeepCollectionEquality().equals(other._settings, _settings) &&
            const DeepCollectionEquality()
                .equals(other._aiMetrics, _aiMetrics) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.schoolId, schoolId) ||
                other.schoolId == schoolId) &&
            (identical(other.academicYearId, academicYearId) ||
                other.academicYearId == academicYearId) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        verificationUuid,
        status,
        pdfUrl,
        const DeepCollectionEquality().hash(_pdfHistory),
        generatedAt,
        publishedAt,
        approvedAt,
        generatedBy,
        publishedBy,
        approvedBy,
        const DeepCollectionEquality().hash(_settings),
        const DeepCollectionEquality().hash(_aiMetrics),
        isActive,
        version,
        tenantId,
        schoolId,
        academicYearId,
        studentId,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of ReportCardDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportCardDtoImplCopyWith<_$ReportCardDtoImpl> get copyWith =>
      __$$ReportCardDtoImplCopyWithImpl<_$ReportCardDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReportCardDtoImplToJson(
      this,
    );
  }
}

abstract class _ReportCardDto extends ReportCardDto {
  const factory _ReportCardDto(
      {required final String id,
      @JsonKey(name: 'verification_uuid')
      required final String verificationUuid,
      required final String status,
      @JsonKey(name: 'pdf_url') final String? pdfUrl,
      @JsonKey(name: 'pdf_history')
      required final List<Map<String, dynamic>> pdfHistory,
      @JsonKey(name: 'generated_at') final String? generatedAt,
      @JsonKey(name: 'published_at') final String? publishedAt,
      @JsonKey(name: 'approved_at') final String? approvedAt,
      @JsonKey(name: 'generated_by') final String? generatedBy,
      @JsonKey(name: 'published_by') final String? publishedBy,
      @JsonKey(name: 'approved_by') final String? approvedBy,
      required final Map<String, dynamic> settings,
      @JsonKey(name: 'ai_metrics')
      required final Map<String, dynamic> aiMetrics,
      @JsonKey(name: 'is_active') required final bool isActive,
      required final int version,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'school_id') required final String schoolId,
      @JsonKey(name: 'academic_year_id') required final String academicYearId,
      @JsonKey(name: 'student_id') required final String studentId,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'updated_at')
      required final String updatedAt}) = _$ReportCardDtoImpl;
  const _ReportCardDto._() : super._();

  factory _ReportCardDto.fromJson(Map<String, dynamic> json) =
      _$ReportCardDtoImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'verification_uuid')
  String get verificationUuid;
  @override
  String get status;
  @override
  @JsonKey(name: 'pdf_url')
  String? get pdfUrl;
  @override
  @JsonKey(name: 'pdf_history')
  List<Map<String, dynamic>> get pdfHistory;
  @override
  @JsonKey(name: 'generated_at')
  String? get generatedAt;
  @override
  @JsonKey(name: 'published_at')
  String? get publishedAt;
  @override
  @JsonKey(name: 'approved_at')
  String? get approvedAt;
  @override
  @JsonKey(name: 'generated_by')
  String? get generatedBy;
  @override
  @JsonKey(name: 'published_by')
  String? get publishedBy;
  @override
  @JsonKey(name: 'approved_by')
  String? get approvedBy;
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
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'school_id')
  String get schoolId;
  @override
  @JsonKey(name: 'academic_year_id')
  String get academicYearId;
  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  String get updatedAt;

  /// Create a copy of ReportCardDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportCardDtoImplCopyWith<_$ReportCardDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
