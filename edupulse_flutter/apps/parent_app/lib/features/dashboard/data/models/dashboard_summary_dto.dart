import 'package:freezed_annotation/freezed_annotation.dart';
import 'outstanding_class_dto.dart';

part 'dashboard_summary_dto.freezed.dart';
part 'dashboard_summary_dto.g.dart';

@freezed
class DashboardSummaryDto with _$DashboardSummaryDto {
  const factory DashboardSummaryDto({
    @JsonKey(name: 'today_collection') required double todayCollection,
    @JsonKey(name: 'month_collection') required double monthCollection,
    @JsonKey(name: 'pending_dues') required double pendingDues,
    @JsonKey(name: 'collection_percentage')
    required double collectionPercentage,
    @JsonKey(name: 'defaulters_count') required int defaultersCount,
    @JsonKey(name: 'top_outstanding_classes')
    required List<OutstandingClassDto> topOutstandingClasses,
  }) = _DashboardSummaryDto;

  factory DashboardSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryDtoFromJson(json);
}
