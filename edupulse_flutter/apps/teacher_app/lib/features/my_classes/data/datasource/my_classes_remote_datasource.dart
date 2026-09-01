import 'package:edupulse_network/edupulse_network.dart';
import '../../../dashboard/data/models/class_dto.dart';
import '../../../dashboard/data/models/section_dto.dart';
import '../../../dashboard/data/models/subject_dto.dart';
import '../models/teacher_subject_assignment_dto.dart';
import '../models/student_dto.dart';

class MyClassesRemoteDatasource {
  final BaseApiClient _apiClient;

  const MyClassesRemoteDatasource(this._apiClient);

  Future<ApiResult<List<TeacherSubjectAssignmentDto>>> getTeacherAssignments({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  }) {
    return _apiClient.get(
      '/teacher-subject-assignments',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'teacher_id': teacherId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => TeacherSubjectAssignmentDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<ClassDto>>> getClasses({
    required String schoolId,
    required String academicYearId,
  }) {
    return _apiClient.get(
      '/classes',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => ClassDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<SectionDto>>> getSections({
    required String schoolId,
    required String academicYearId,
  }) {
    return _apiClient.get(
      '/sections',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => SectionDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<SubjectDto>>> getSubjects({
    required String schoolId,
    required String academicYearId,
  }) {
    return _apiClient.get(
      '/subjects',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => SubjectDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<StudentDto>>> getStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) {
    return _apiClient.get(
      '/students',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => StudentDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<StudentDto>> getStudent({
    required String schoolId,
    required String studentId,
  }) {
    return _apiClient.get(
      '/students/$studentId',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StudentDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<StudentDto>>> getTeacherStudents({
    required String schoolId,
    required String academicYearId,
  }) {
    return _apiClient.get(
      '/students',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => StudentDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }
}
