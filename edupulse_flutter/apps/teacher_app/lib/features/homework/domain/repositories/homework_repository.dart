import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/homework_entity.dart';

abstract class HomeworkRepository {
  Future<ApiResult<HomeworkEntity>> createHomework({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required String teacherSubjectAssignmentId,
    required String subjectId,
    required String classId,
    required String sectionId,
    String? timetableId,
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    String? attachmentUrl,
    int? estimatedMinutes,
  });

  Future<ApiResult<HomeworkEntity>> createFromTimetable({
    required String schoolId,
    required String timetableId,
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    String? attachmentUrl,
    int? estimatedMinutes,
  });

  Future<ApiResult<List<HomeworkEntity>>> copyHomework({
    required String schoolId,
    required String homeworkId,
    required List<String> targetSectionIds,
  });

  Future<ApiResult<HomeworkEntity>> publishHomework({
    required String schoolId,
    required String id,
  });

  Future<ApiResult<List<HomeworkEntity>>> getRecentHomework({
    required String schoolId,
  });

  Future<ApiResult<List<String>>> getTemplates({
    required String schoolId,
    String? subjectId,
  });

  Future<ApiResult<HomeworkEntity>> getHomeworkById({
    required String schoolId,
    required String id,
  });

  Future<ApiResult<List<HomeworkEntity>>> listHomeworks({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    HomeworkStatus? status,
    String? search,
    int skip = 0,
    int limit = 100,
  });

  Future<ApiResult<HomeworkEntity>> updateHomework({
    required String schoolId,
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    HomeworkPriority? priority,
    HomeworkStatus? status,
    String? attachmentUrl,
    int? estimatedMinutes,
  });

  Future<ApiResult<HomeworkEntity>> deleteHomework({
    required String schoolId,
    required String id,
  });
}
