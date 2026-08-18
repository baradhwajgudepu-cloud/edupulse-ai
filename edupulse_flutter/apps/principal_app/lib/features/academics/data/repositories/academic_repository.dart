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
}
