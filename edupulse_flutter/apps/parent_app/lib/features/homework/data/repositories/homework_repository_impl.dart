import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/homework.dart';
import '../../domain/repositories/homework_repository.dart';
import '../datasource/homework_remote_datasource.dart';
import '../mappers/homework_mapper.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  final HomeworkRemoteDatasource _remoteDatasource;

  List<HomeworkEntity>? _cachedHomeworks;

  HomeworkRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<List<HomeworkEntity>>> getHomeworkRecords({
    required String schoolId,
    bool forceRefresh = false,
  }) async {
    if (_cachedHomeworks != null && !forceRefresh) {
      return ApiResult.success(_cachedHomeworks!);
    }

    final result =
        await _remoteDatasource.getHomeworkRecords(schoolId: schoolId);
    return result.when(
      onSuccess: (list) {
        final entities = list.map((dto) => dto.toEntity()).toList();
        _cachedHomeworks = entities;
        return ApiResult.success(entities);
      },
      onFailure: (failure) {
        if (_cachedHomeworks != null) {
          return ApiResult.success(_cachedHomeworks!);
        }
        return ApiResult.failure(failure);
      },
    );
  }
}
