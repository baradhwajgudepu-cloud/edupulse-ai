import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/report_cards_datasource.dart';
import '../models/report_card_model.dart';

class ReportCardsRepository {
  final ReportCardsDatasource _datasource;

  ReportCardsRepository(this._datasource);

  Future<ApiResult<List<ReportCard>>> getReportCards({
    required String schoolId,
    String? status,
  }) async {
    final result = await _datasource.getReportCards(schoolId: schoolId, status: status);
    return result.when(
      onSuccess: (list) {
        final cards = list.map((e) => ReportCard.fromJson(e)).toList();
        return ApiResult.success(cards);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<ReportCard>> approveReportCard({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.approveReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (json) => ApiResult.success(ReportCard.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<ReportCard>> lockReportCard({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.lockReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (json) => ApiResult.success(ReportCard.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<ReportCard>> unlockReportCard({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.unlockReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (json) => ApiResult.success(ReportCard.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<List<ReportCard>>> publishReportCards({
    required String schoolId,
    required String classId,
    required String sectionId,
  }) async {
    final result = await _datasource.publishReportCards(schoolId: schoolId, classId: classId, sectionId: sectionId);
    return result.when(
      onSuccess: (list) {
        final cards = list.map((e) => ReportCard.fromJson(e)).toList();
        return ApiResult.success(cards);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
