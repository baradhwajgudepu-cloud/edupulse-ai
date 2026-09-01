import 'package:equatable/equatable.dart';
import 'outstanding_class.dart';

class DashboardSummaryEntity extends Equatable {
  final double todayCollection;
  final double monthCollection;
  final double pendingDues;
  final double collectionPercentage;
  final int defaultersCount;
  final List<OutstandingClassEntity> topOutstandingClasses;

  const DashboardSummaryEntity({
    required this.todayCollection,
    required this.monthCollection,
    required this.pendingDues,
    required this.collectionPercentage,
    required this.defaultersCount,
    required this.topOutstandingClasses,
  });

  @override
  List<Object?> get props => [
        todayCollection,
        monthCollection,
        pendingDues,
        collectionPercentage,
        defaultersCount,
        topOutstandingClasses,
      ];
}
