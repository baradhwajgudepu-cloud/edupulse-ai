import 'package:edupulse_network/edupulse_network.dart';
import '../models/teacher_profile_dto.dart';
import '../models/academic_year_dto.dart';
import '../models/class_dto.dart';
import '../models/section_dto.dart';
import '../models/subject_dto.dart';
import '../models/timetable_dto.dart';

class DashboardRemoteDatasource {
  final BaseApiClient _apiClient;

  const DashboardRemoteDatasource(this._apiClient);

  Future<ApiResult<List<TeacherProfileDto>>> getTeacherProfile({
    required String email,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/teachers',
      queryParameters: {
        'school_id': schoolId,
        'search': email,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => TeacherProfileDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<AcademicYearDto>>> getActiveAcademicYear({
    required String schoolId,
  }) {
    return _apiClient.get(
      '/schools/$schoolId/academic-years',
      queryParameters: {
        'status': 'ACTIVE',
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => AcademicYearDto.fromJson(item as Map<String, dynamic>))
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

  Future<ApiResult<List<TimetableDto>>> getTeacherSchedule({
    required String teacherId,
    required String academicYearId,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/timetables/teacher-schedule',
      queryParameters: {
        'teacher_id': teacherId,
        'academic_year_id': academicYearId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => TimetableDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }
}
