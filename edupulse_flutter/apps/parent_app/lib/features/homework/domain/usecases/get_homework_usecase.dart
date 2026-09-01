import 'package:edupulse_network/edupulse_network.dart';
import '../entities/homework.dart';
import '../repositories/homework_repository.dart';

class GetHomeworkUseCase {
  final HomeworkRepository _repository;

  const GetHomeworkUseCase(this._repository);

  Future<ApiResult<List<HomeworkEntity>>> call({
    required String schoolId,
    bool forceRefresh = false,
  }) {
    return _repository.getHomeworkRecords(
      schoolId: schoolId,
      forceRefresh: forceRefresh,
    );
  }
}
