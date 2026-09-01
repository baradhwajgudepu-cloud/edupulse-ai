// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'homework_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

HomeworkDto _$HomeworkDtoFromJson(Map<String, dynamic> json) {
  return _HomeworkDto.fromJson(json);
}

/// @nodoc
mixin _$HomeworkDto {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'due_date')
  String get dueDate => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_url')
  String? get attachmentUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'section_id')
  String get sectionId => throw _privateConstructorUsedError;

  /// Serializes this HomeworkDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeworkDtoCopyWith<HomeworkDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeworkDtoCopyWith<$Res> {
  factory $HomeworkDtoCopyWith(
          HomeworkDto value, $Res Function(HomeworkDto) then) =
      _$HomeworkDtoCopyWithImpl<$Res, HomeworkDto>;
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      @JsonKey(name: 'due_date') String dueDate,
      String priority,
      String status,
      @JsonKey(name: 'attachment_url') String? attachmentUrl,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId});
}

/// @nodoc
class _$HomeworkDtoCopyWithImpl<$Res, $Val extends HomeworkDto>
    implements $HomeworkDtoCopyWith<$Res> {
  _$HomeworkDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? dueDate = null,
    Object? priority = null,
    Object? status = null,
    Object? attachmentUrl = freezed,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      attachmentUrl: freezed == attachmentUrl
          ? _value.attachmentUrl
          : attachmentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HomeworkDtoImplCopyWith<$Res>
    implements $HomeworkDtoCopyWith<$Res> {
  factory _$$HomeworkDtoImplCopyWith(
          _$HomeworkDtoImpl value, $Res Function(_$HomeworkDtoImpl) then) =
      __$$HomeworkDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      @JsonKey(name: 'due_date') String dueDate,
      String priority,
      String status,
      @JsonKey(name: 'attachment_url') String? attachmentUrl,
      @JsonKey(name: 'subject_id') String subjectId,
      @JsonKey(name: 'class_id') String classId,
      @JsonKey(name: 'section_id') String sectionId});
}

/// @nodoc
class __$$HomeworkDtoImplCopyWithImpl<$Res>
    extends _$HomeworkDtoCopyWithImpl<$Res, _$HomeworkDtoImpl>
    implements _$$HomeworkDtoImplCopyWith<$Res> {
  __$$HomeworkDtoImplCopyWithImpl(
      _$HomeworkDtoImpl _value, $Res Function(_$HomeworkDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? dueDate = null,
    Object? priority = null,
    Object? status = null,
    Object? attachmentUrl = freezed,
    Object? subjectId = null,
    Object? classId = null,
    Object? sectionId = null,
  }) {
    return _then(_$HomeworkDtoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      dueDate: null == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      attachmentUrl: freezed == attachmentUrl
          ? _value.attachmentUrl
          : attachmentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      classId: null == classId
          ? _value.classId
          : classId // ignore: cast_nullable_to_non_nullable
              as String,
      sectionId: null == sectionId
          ? _value.sectionId
          : sectionId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HomeworkDtoImpl implements _HomeworkDto {
  const _$HomeworkDtoImpl(
      {required this.id,
      required this.title,
      required this.description,
      @JsonKey(name: 'due_date') required this.dueDate,
      required this.priority,
      required this.status,
      @JsonKey(name: 'attachment_url') this.attachmentUrl,
      @JsonKey(name: 'subject_id') required this.subjectId,
      @JsonKey(name: 'class_id') required this.classId,
      @JsonKey(name: 'section_id') required this.sectionId});

  factory _$HomeworkDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$HomeworkDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  @JsonKey(name: 'due_date')
  final String dueDate;
  @override
  final String priority;
  @override
  final String status;
  @override
  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;
  @override
  @JsonKey(name: 'subject_id')
  final String subjectId;
  @override
  @JsonKey(name: 'class_id')
  final String classId;
  @override
  @JsonKey(name: 'section_id')
  final String sectionId;

  @override
  String toString() {
    return 'HomeworkDto(id: $id, title: $title, description: $description, dueDate: $dueDate, priority: $priority, status: $status, attachmentUrl: $attachmentUrl, subjectId: $subjectId, classId: $classId, sectionId: $sectionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeworkDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.attachmentUrl, attachmentUrl) ||
                other.attachmentUrl == attachmentUrl) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.sectionId, sectionId) ||
                other.sectionId == sectionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, description, dueDate,
      priority, status, attachmentUrl, subjectId, classId, sectionId);

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeworkDtoImplCopyWith<_$HomeworkDtoImpl> get copyWith =>
      __$$HomeworkDtoImplCopyWithImpl<_$HomeworkDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HomeworkDtoImplToJson(
      this,
    );
  }
}

abstract class _HomeworkDto implements HomeworkDto {
  const factory _HomeworkDto(
          {required final String id,
          required final String title,
          required final String description,
          @JsonKey(name: 'due_date') required final String dueDate,
          required final String priority,
          required final String status,
          @JsonKey(name: 'attachment_url') final String? attachmentUrl,
          @JsonKey(name: 'subject_id') required final String subjectId,
          @JsonKey(name: 'class_id') required final String classId,
          @JsonKey(name: 'section_id') required final String sectionId}) =
      _$HomeworkDtoImpl;

  factory _HomeworkDto.fromJson(Map<String, dynamic> json) =
      _$HomeworkDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  @JsonKey(name: 'due_date')
  String get dueDate;
  @override
  String get priority;
  @override
  String get status;
  @override
  @JsonKey(name: 'attachment_url')
  String? get attachmentUrl;
  @override
  @JsonKey(name: 'subject_id')
  String get subjectId;
  @override
  @JsonKey(name: 'class_id')
  String get classId;
  @override
  @JsonKey(name: 'section_id')
  String get sectionId;

  /// Create a copy of HomeworkDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeworkDtoImplCopyWith<_$HomeworkDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
