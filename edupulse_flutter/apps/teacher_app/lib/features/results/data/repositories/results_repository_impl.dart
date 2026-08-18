import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/result_summary_entity.dart';
import '../../domain/entities/report_card_entity.dart';
import '../../domain/entities/report_card_preview_entity.dart';
import '../../domain/entities/bulk_class_generate_entity.dart';
import '../../domain/repositories/results_repository.dart';
import '../datasources/results_remote_datasource.dart';

class ResultsRepositoryImpl implements ResultsRepository {
  final ResultsRemoteDatasource _remoteDatasource;

  const ResultsRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<ResultSummaryEntity>> getResultSummary({
    required String examScheduleId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getResultSummary(
      examScheduleId: examScheduleId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<List<ReportCardEntity>>> getReportCards({
    required String schoolId,
    String? classId,
    String? sectionId,
    String? academicYearId,
    ReportCardStatus? status,
  }) async {
    final result = await _remoteDatasource.getReportCards(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      academicYearId: academicYearId,
      status: status?.name,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.map((e) => e.toEntity()).toList()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<ReportCardPreviewEntity>> getReportCardPreview({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.getReportCardPreview(
      studentId: studentId,
      schoolId: schoolId,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<ReportCardEntity>> generateReportCard({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.generateReportCard(
      studentId: studentId,
      schoolId: schoolId,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<ReportCardEntity>> submitForReview({
    required String id,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.submitForReview(
      id: id,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<BulkClassGenerateEntity>> bulkGenerateClass({
    required String classId,
    required String sectionId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.bulkGenerateClass(
      classId: classId,
      sectionId: sectionId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
