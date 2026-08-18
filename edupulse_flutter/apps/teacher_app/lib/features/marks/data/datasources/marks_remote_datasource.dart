import 'package:edupulse_network/edupulse_network.dart';
import '../models/examination_dto.dart';
import '../models/marks_dto.dart';
import '../models/marks_wizard_dto.dart';
import '../models/marks_publish_summary_dto.dart';

class MarksRemoteDatasource {
  final BaseApiClient _apiClient;

  const MarksRemoteDatasource(this._apiClient);

  Future<ApiResult<List<ExaminationDto>>> getExaminations({
    required String schoolId,
    String? academicYearId,
    String? search,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (search != null) queryParams['search'] = search;

    return _apiClient.get(
      '/examinations',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((e) => ExaminationDto.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<ExaminationDto>> getExaminationById({
    required String id,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/examinations/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ExaminationDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<MarksWizardDto>> getMarksWizard({
    required String examScheduleId,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/marks/wizard/entry',
      queryParameters: {
        'exam_schedule_id': examScheduleId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return MarksWizardDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<MarksDto>>> bulkSaveMarks({
    required String schoolId,
    required String examScheduleId,
    required String teacherSubjectAssignmentId,
    required List<Map<String, dynamic>> marks,
    required bool autosave,
    required bool isUpdate,
  }) {
    final body = {
      'exam_schedule_id': examScheduleId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'marks': marks,
    };
    final queryParameters = {
      'school_id': schoolId,
      if (!isUpdate) 'autosave': autosave.toString(),
    };

    if (isUpdate) {
      return _apiClient.put(
        '/marks/bulk',
        queryParameters: queryParameters,
        data: body,
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list
              .map((e) => MarksDto.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
    } else {
      return _apiClient.post(
        '/marks/bulk',
        queryParameters: queryParameters,
        data: body,
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List<dynamic>;
          return list
              .map((e) => MarksDto.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
    }
  }

  Future<ApiResult<MarksPublishSummaryDto>> getPublishSummary({
    required String examScheduleId,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/marks/publish/summary',
      queryParameters: {
        'exam_schedule_id': examScheduleId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return MarksPublishSummaryDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<MarksDto>>> publishMarks({
    required String examScheduleId,
    required String schoolId,
  }) {
    return _apiClient.post(
      '/marks/publish',
      queryParameters: {
        'exam_schedule_id': examScheduleId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((e) => MarksDto.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<String>>> getRemarksTemplates() {
    return _apiClient.get(
      '/marks/remarks-templates',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      },
    );
  }
}
