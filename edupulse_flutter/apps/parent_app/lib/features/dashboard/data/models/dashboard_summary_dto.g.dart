// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardSummaryDtoImpl _$$DashboardSummaryDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardSummaryDtoImpl(
      todayCollection: (json['today_collection'] as num).toDouble(),
      monthCollection: (json['month_collection'] as num).toDouble(),
      pendingDues: (json['pending_dues'] as num).toDouble(),
      collectionPercentage: (json['collection_percentage'] as num).toDouble(),
      defaultersCount: (json['defaulters_count'] as num).toInt(),
      topOutstandingClasses: (json['top_outstanding_classes'] as List<dynamic>)
          .map((e) => OutstandingClassDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$DashboardSummaryDtoImplToJson(
        _$DashboardSummaryDtoImpl instance) =>
    <String, dynamic>{
      'today_collection': instance.todayCollection,
      'month_collection': instance.monthCollection,
      'pending_dues': instance.pendingDues,
      'collection_percentage': instance.collectionPercentage,
      'defaulters_count': instance.defaultersCount,
      'top_outstanding_classes': instance.topOutstandingClasses,
    };
