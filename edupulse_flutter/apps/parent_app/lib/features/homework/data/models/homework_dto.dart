import 'package:freezed_annotation/freezed_annotation.dart';

part 'homework_dto.freezed.dart';
part 'homework_dto.g.dart';

@freezed
class HomeworkDto with _$HomeworkDto {
  const factory HomeworkDto({
    required String id,
    required String title,
    required String description,
    @JsonKey(name: 'due_date') required String dueDate,
    required String priority,
    required String status,
    @JsonKey(name: 'attachment_url') String? attachmentUrl,
    @JsonKey(name: 'subject_id') required String subjectId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
  }) = _HomeworkDto;

  factory HomeworkDto.fromJson(Map<String, dynamic> json) =>
      _$HomeworkDtoFromJson(json);
}
