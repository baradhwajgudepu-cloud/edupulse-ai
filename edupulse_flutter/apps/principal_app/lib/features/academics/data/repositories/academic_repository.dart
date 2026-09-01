import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/academic_datasource.dart';
import '../models/academic_models.dart';

class AcademicRepository {
  final AcademicDatasource _datasource;

  AcademicRepository(this._datasource);

  Future<ApiResult<List<Examination>>> getExaminations({
    required String schoolId,
  }) async {
    final result = await _datasource.getExaminations(schoolId: schoolId);
    return result.when(
      onSuccess: (list) {
        final exams = list.map((e) => Examination.fromJson(e)).toList();
        return ApiResult.success(exams);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<MarksSummary>> getMarksSummary({
    required String schoolId,
    required String examScheduleId,
  }) async {
    final result = await _datasource.getMarksSummary(schoolId: schoolId, examScheduleId: examScheduleId);
    return result.when(
      onSuccess: (json) => ApiResult.success(MarksSummary.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Examination>> createExamination({
    required String schoolId,
    required String examName,
    required String examType,
    required String startDate,
    required String endDate,
    String? description,
  }) async {
    final payload = {
      'school_id': schoolId,
      'exam_name': examName,
      'exam_type': examType,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
    };
    final result = await _datasource.createExamination(data: payload);
    return result.when(
      onSuccess: (map) => ApiResult.success(Examination.fromJson(map)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Examination>> publishExamination({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.publishExamination(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (map) => ApiResult.success(Examination.fromJson(map)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getClasses({
    required String schoolId,
  }) {
    return _datasource.getClasses(schoolId: schoolId);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getAcademicYears({
    required String schoolId,
  }) {
    return _datasource.getAcademicYears(schoolId: schoolId);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSections({
    required String schoolId,
    String? classId,
  }) {
    return _datasource.getSections(schoolId: schoolId, classId: classId);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSuggestedSchedules({
    required String schoolId,
    required List<String> classIds,
    required String startDate,
    required String endDate,
  }) {
    return _datasource.getSuggestedSchedules(
      schoolId: schoolId,
      classIds: classIds,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<ApiResult<Examination>> createExaminationWizard({
    required Map<String, dynamic> payload,
  }) async {
    final result = await _datasource.createExaminationWizard(data: payload);
    return result.when(
      onSuccess: (map) => ApiResult.success(Examination.fromJson(map)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}

