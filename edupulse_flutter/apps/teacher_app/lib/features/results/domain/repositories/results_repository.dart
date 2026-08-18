import 'package:edupulse_network/edupulse_network.dart';
import '../entities/result_summary_entity.dart';
import '../entities/report_card_entity.dart';
import '../entities/report_card_preview_entity.dart';
import '../entities/bulk_class_generate_entity.dart';

abstract class ResultsRepository {
  Future<ApiResult<ResultSummaryEntity>> getResultSummary({
    required String examScheduleId,
    required String schoolId,
  });

  Future<ApiResult<List<ReportCardEntity>>> getReportCards({
    required String schoolId,
    String? classId,
    String? sectionId,
    String? academicYearId,
    ReportCardStatus? status,
  });

  Future<ApiResult<ReportCardPreviewEntity>> getReportCardPreview({
    required String studentId,
    required String schoolId,
    String? remarks,
  });

  Future<ApiResult<ReportCardEntity>> generateReportCard({
    required String studentId,
    required String schoolId,
    String? remarks,
  });

  Future<ApiResult<ReportCardEntity>> submitForReview({
    required String id,
    required String schoolId,
  });

  Future<ApiResult<BulkClassGenerateEntity>> bulkGenerateClass({
    required String classId,
    required String sectionId,
    required String schoolId,
  });
}
