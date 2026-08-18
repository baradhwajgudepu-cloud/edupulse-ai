import 'package:edupulse_network/edupulse_network.dart';
import '../models/result_summary_dto.dart';
import '../models/report_card_dto.dart';
import '../models/report_card_preview_dto.dart';
import '../models/bulk_class_generate_dto.dart';

class ResultsRemoteDatasource {
  final BaseApiClient _apiClient;

  const ResultsRemoteDatasource(this._apiClient);

  Future<ApiResult<ResultSummaryDto>> getResultSummary({
    required String examScheduleId,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/marks/summary',
      queryParameters: {
        'exam_schedule_id': examScheduleId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ResultSummaryDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<ReportCardDto>>> getReportCards({
    required String schoolId,
    String? classId,
    String? sectionId,
    String? academicYearId,
    String? status,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (classId != null) queryParams['class_id'] = classId;
    if (sectionId != null) queryParams['section_id'] = sectionId;
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (status != null) queryParams['status'] = status;

    return _apiClient.get(
      '/report-cards',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((e) => ReportCardDto.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<ReportCardPreviewDto>> getReportCardPreview({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (remarks != null) queryParams['teacher_remarks'] = remarks;

    return _apiClient.get(
      '/report-cards/preview/$studentId',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ReportCardPreviewDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<ReportCardDto>> generateReportCard({
    required String studentId,
    required String schoolId,
    String? remarks,
  }) {
    return _apiClient.post(
      '/report-cards/generate',
      data: {
        'student_id': studentId,
        'school_id': schoolId,
        if (remarks != null) 'teacher_remarks': remarks,
        'settings': {
          'generated_from_live_data': true,
          'show_attendance': true,
          'language': 'en',
        },
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ReportCardDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<ReportCardDto>> submitForReview({
    required String id,
    required String schoolId,
  }) {
    return _apiClient.post(
      '/report-cards/$id/submit-review',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ReportCardDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<BulkClassGenerateDto>> bulkGenerateClass({
    required String classId,
    required String sectionId,
    required String schoolId,
  }) {
    return _apiClient.post(
      '/report-cards/generate/class',
      data: {
        'class_id': classId,
        'section_id': sectionId,
        'school_id': schoolId,
        'settings': {
          'generated_from_live_data': true,
          'show_attendance': true,
          'language': 'en',
        },
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return BulkClassGenerateDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
