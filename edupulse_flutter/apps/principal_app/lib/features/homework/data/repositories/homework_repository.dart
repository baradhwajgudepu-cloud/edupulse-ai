import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/homework_datasource.dart';
import '../models/homework_model.dart';

class HomeworkRepository {
  final HomeworkDatasource _datasource;

  HomeworkRepository(this._datasource);

  Future<ApiResult<List<Homework>>> getHomeworks({
    required String schoolId,
    int skip = 0,
    int limit = 100,
  }) async {
    final result = await _datasource.getHomeworks(schoolId: schoolId, skip: skip, limit: limit);
    return result.when(
      onSuccess: (list) {
        final homeworks = list.map((e) => Homework.fromJson(e)).toList();
        return ApiResult.success(homeworks);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
