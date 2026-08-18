import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/marks_publish_summary_entity.dart';

part 'marks_publish_summary_dto.freezed.dart';
part 'marks_publish_summary_dto.g.dart';

@freezed
class MarksPublishSummaryDto with _$MarksPublishSummaryDto {
  const factory MarksPublishSummaryDto({
    @JsonKey(name: 'exam_name') required String examName,
    @JsonKey(name: 'subject_name') required String subjectName,
    @JsonKey(name: 'class_name') required String className,
    @JsonKey(name: 'total_students') required int totalStudents,
    @JsonKey(name: 'entered_count') required int enteredCount,
    @JsonKey(name: 'missing_count') required int missingCount,
    @JsonKey(name: 'pass_percentage') required double passPercentage,
  }) = _MarksPublishSummaryDto;

  const MarksPublishSummaryDto._();

  factory MarksPublishSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$MarksPublishSummaryDtoFromJson(json);

  MarksPublishSummaryEntity toEntity() {
    return MarksPublishSummaryEntity(
      examName: examName,
      subjectName: subjectName,
      className: className,
      totalStudents: totalStudents,
      enteredCount: enteredCount,
      missingCount: missingCount,
      passPercentage: passPercentage,
    );
  }
}
