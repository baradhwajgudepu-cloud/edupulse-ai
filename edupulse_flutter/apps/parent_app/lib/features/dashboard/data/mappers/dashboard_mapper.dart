import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/outstanding_class.dart';
import '../models/dashboard_summary_dto.dart';
import '../models/outstanding_class_dto.dart';

extension DashboardSummaryDtoMapper on DashboardSummaryDto {
  DashboardSummaryEntity toEntity() {
    return DashboardSummaryEntity(
      todayCollection: todayCollection,
      monthCollection: monthCollection,
      pendingDues: pendingDues,
      collectionPercentage: collectionPercentage,
      defaultersCount: defaultersCount,
      topOutstandingClasses:
          topOutstandingClasses.map((dto) => dto.toEntity()).toList(),
    );
  }
}

extension OutstandingClassDtoMapper on OutstandingClassDto {
  OutstandingClassEntity toEntity() {
    return OutstandingClassEntity(
      className: className,
      outstandingAmount: outstandingAmount,
    );
  }
}
