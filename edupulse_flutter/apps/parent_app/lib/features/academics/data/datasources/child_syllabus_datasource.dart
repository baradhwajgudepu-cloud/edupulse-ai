import 'package:edupulse_network/edupulse_network.dart';
import '../models/child_syllabus_models.dart';

class ChildSyllabusDatasource {
  final BaseApiClient _apiClient;

  const ChildSyllabusDatasource(this._apiClient);

  Future<ApiResult<ChildSyllabusProgressResponse>> getChildSyllabusProgress({
    required String studentId,
    required String schoolId,
    required String academicYearId,
  }) {
    return _apiClient.get(
      '/syllabus-recovery/student-progress',
      queryParameters: {
        'student_id': studentId,
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>? ?? payload;
        return ChildSyllabusProgressResponse.fromJson(data);
      },
    );
  }
}
