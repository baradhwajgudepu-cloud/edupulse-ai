import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/student_datasource.dart';
import '../models/student_model.dart';

class StudentRepository {
  final StudentDatasource _datasource;

  StudentRepository(this._datasource);

  Future<ApiResult<List<Student>>> getStudents({
    required String schoolId,
    int skip = 0,
    int limit = 100,
    String? search,
    String? classId,
    String? sectionId,
  }) async {
    final result = await _datasource.getStudents(
      schoolId: schoolId,
      skip: skip,
      limit: limit,
      search: search,
      classId: classId,
      sectionId: sectionId,
    );

    return result.when(
      onSuccess: (list) {
        final students = list.map((e) => Student.fromJson(e)).toList();
        return ApiResult.success(students);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Student>> getStudentById(String id, String schoolId) async {
    final result = await _datasource.getStudentById(id, schoolId);
    return result.when(
      onSuccess: (json) => ApiResult.success(Student.fromJson(json)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
