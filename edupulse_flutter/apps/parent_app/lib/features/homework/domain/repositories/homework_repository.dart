import 'package:edupulse_network/edupulse_network.dart';
import '../entities/homework.dart';

abstract class HomeworkRepository {
  Future<ApiResult<List<HomeworkEntity>>> getHomeworkRecords({
    required String schoolId,
    bool forceRefresh = false,
  });
}
