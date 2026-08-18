import 'package:edupulse_network/edupulse_network.dart';
import '../entities/examination_entity.dart';
import '../entities/student_mark_entity.dart';
import '../entities/marks_wizard_entity.dart';
import '../entities/marks_publish_summary_entity.dart';

class SingleMarkInput {
  final String studentId;
  final double? marksObtained;
  final ExamResult resultStatus;
  final String? remarks;

  const SingleMarkInput({
    required this.studentId,
    this.marksObtained,
    required this.resultStatus,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'marks_obtained': marksObtained,
      'result_status': resultStatus.name,
      'remarks': remarks,
    };
  }
}

abstract class MarksRepository {
  Future<ApiResult<List<ExaminationEntity>>> getExaminations({
    required String schoolId,
    String? academicYearId,
    String? search,
  });

  Future<ApiResult<ExaminationEntity>> getExaminationById({
    required String id,
    required String schoolId,
  });

  Future<ApiResult<MarksWizardEntity>> getMarksWizard({
    required String examScheduleId,
    required String schoolId,
  });

  Future<ApiResult<List<StudentMarkEntity>>> bulkSaveMarks({
    required String schoolId,
    required String examScheduleId,
    required String teacherSubjectAssignmentId,
    required List<SingleMarkInput> marks,
    required bool autosave,
    required bool isUpdate,
  });

  Future<ApiResult<MarksPublishSummaryEntity>> getPublishSummary({
    required String examScheduleId,
    required String schoolId,
  });

  Future<ApiResult<List<StudentMarkEntity>>> publishMarks({
    required String examScheduleId,
    required String schoolId,
  });

  Future<ApiResult<List<String>>> getRemarksTemplates();
}
