import 'package:edupulse_network/edupulse_network.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/homework_entity.dart';
import '../../domain/repositories/homework_repository.dart';
import '../datasource/homework_remote_datasource.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  final HomeworkRemoteDatasource _remoteDatasource;

  const HomeworkRepositoryImpl(this._remoteDatasource);

  String _formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  @override
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
  }) async {
    final result = await _remoteDatasource.createHomework(
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: _formatDate(dueDate),
      priority: priority.name,
      status: status.name,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
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
  }) async {
    final result = await _remoteDatasource.createFromTimetable(
      schoolId: schoolId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: _formatDate(dueDate),
      priority: priority.name,
      status: status.name,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<List<HomeworkEntity>>> copyHomework({
    required String schoolId,
    required String homeworkId,
    required List<String> targetSectionIds,
  }) async {
    final result = await _remoteDatasource.copyHomework(
      schoolId: schoolId,
      homeworkId: homeworkId,
      targetSectionIds: targetSectionIds,
    );

    return result.when(
      onSuccess: (list) => ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<HomeworkEntity>> publishHomework({
    required String schoolId,
    required String id,
  }) async {
    final result = await _remoteDatasource.publishHomework(
      schoolId: schoolId,
      id: id,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<List<HomeworkEntity>>> getRecentHomework({
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getRecentHomework(
      schoolId: schoolId,
    );

    return result.when(
      onSuccess: (list) => ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<List<String>>> getTemplates({
    required String schoolId,
    String? subjectId,
  }) {
    return _remoteDatasource.getTemplates(
      schoolId: schoolId,
      subjectId: subjectId,
    );
  }

  @override
  Future<ApiResult<HomeworkEntity>> getHomeworkById({
    required String schoolId,
    required String id,
  }) async {
    final result = await _remoteDatasource.getHomeworkById(
      schoolId: schoolId,
      id: id,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
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
  }) async {
    final result = await _remoteDatasource.listHomeworks(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      teacherId: teacherId,
      status: status?.name,
      search: search,
      skip: skip,
      limit: limit,
    );

    return result.when(
      onSuccess: (list) => ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
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
  }) async {
    final result = await _remoteDatasource.updateHomework(
      schoolId: schoolId,
      id: id,
      title: title,
      description: description,
      dueDate: dueDate != null ? _formatDate(dueDate) : null,
      priority: priority?.name,
      status: status?.name,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<HomeworkEntity>> deleteHomework({
    required String schoolId,
    required String id,
  }) async {
    final result = await _remoteDatasource.deleteHomework(
      schoolId: schoolId,
      id: id,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }
}
