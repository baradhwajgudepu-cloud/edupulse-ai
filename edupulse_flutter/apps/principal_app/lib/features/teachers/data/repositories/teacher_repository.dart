import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/teacher_datasource.dart';
import '../models/teacher_model.dart';

class TeacherRepository {
  final TeacherDatasource _datasource;

  TeacherRepository(this._datasource);

  Future<ApiResult<List<Teacher>>> getTeachers({
    required String schoolId,
    int skip = 0,
    int limit = 100,
    String? search,
  }) async {
    final result = await _datasource.getTeachers(
      schoolId: schoolId,
      skip: skip,
      limit: limit,
      search: search,
    );

    return result.when(
      onSuccess: (list) {
        final teachers = list.map((e) => Teacher.fromJson(e)).toList();
        return ApiResult.success(teachers);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Teacher>> getTeacherById(String id, String schoolId) async {
    final result = await _datasource.getTeacherById(id, schoolId);
    return result.when(
      onSuccess: (json) => ApiResult.success(Teacher.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
