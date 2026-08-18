import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/examination_entity.dart';
import '../../domain/entities/student_mark_entity.dart';
import '../../domain/entities/marks_wizard_entity.dart';
import '../../domain/entities/marks_publish_summary_entity.dart';
import '../../domain/repositories/marks_repository.dart';
import '../datasources/marks_remote_datasource.dart';

class MarksRepositoryImpl implements MarksRepository {
  final MarksRemoteDatasource _remoteDatasource;

  const MarksRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<List<ExaminationEntity>>> getExaminations({
    required String schoolId,
    String? academicYearId,
    String? search,
  }) async {
    final result = await _remoteDatasource.getExaminations(
      schoolId: schoolId,
      academicYearId: academicYearId,
      search: search,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.map((e) => e.toEntity()).toList()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<ExaminationEntity>> getExaminationById({
    required String id,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getExaminationById(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<MarksWizardEntity>> getMarksWizard({
    required String examScheduleId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getMarksWizard(
      examScheduleId: examScheduleId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<List<StudentMarkEntity>>> bulkSaveMarks({
    required String schoolId,
    required String examScheduleId,
    required String teacherSubjectAssignmentId,
    required List<SingleMarkInput> marks,
    required bool autosave,
    required bool isUpdate,
  }) async {
    final result = await _remoteDatasource.bulkSaveMarks(
      schoolId: schoolId,
      examScheduleId: examScheduleId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      marks: marks.map((e) => e.toJson()).toList(),
      autosave: autosave,
      isUpdate: isUpdate,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.map((e) => e.toEntity()).toList()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<MarksPublishSummaryEntity>> getPublishSummary({
    required String examScheduleId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.getPublishSummary(
      examScheduleId: examScheduleId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<List<StudentMarkEntity>>> publishMarks({
    required String examScheduleId,
    required String schoolId,
  }) async {
    final result = await _remoteDatasource.publishMarks(
      examScheduleId: examScheduleId,
      schoolId: schoolId,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(data.map((e) => e.toEntity()).toList()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<List<String>>> getRemarksTemplates() async {
    return _remoteDatasource.getRemarksTemplates();
  }
}
