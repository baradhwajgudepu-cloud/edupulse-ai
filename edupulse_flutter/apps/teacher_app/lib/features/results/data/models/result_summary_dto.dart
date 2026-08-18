import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/result_summary_entity.dart';

part 'result_summary_dto.freezed.dart';
part 'result_summary_dto.g.dart';

@freezed
class ResultSummaryDto with _$ResultSummaryDto {
  const factory ResultSummaryDto({
    @JsonKey(name: 'class_average') required double classAverage,
    @JsonKey(name: 'pass_percentage') required double passPercentage,
    @JsonKey(name: 'highest_score') required double highestScore,
    @JsonKey(name: 'lowest_score') required double lowestScore,
    @JsonKey(name: 'missing_count') required int missingCount,
    @JsonKey(name: 'absent_count') required int absentCount,
  }) = _ResultSummaryDto;

  const ResultSummaryDto._();

  factory ResultSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ResultSummaryDtoFromJson(json);

  ResultSummaryEntity toEntity() {
    return ResultSummaryEntity(
      classAverage: classAverage,
      passPercentage: passPercentage,
      highestScore: highestScore,
      lowestScore: lowestScore,
      missingCount: missingCount,
      absentCount: absentCount,
    );
  }
}
