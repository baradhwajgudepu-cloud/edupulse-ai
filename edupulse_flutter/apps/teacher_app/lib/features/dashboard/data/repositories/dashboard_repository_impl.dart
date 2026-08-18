import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/academic_year.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/entities/timetable_entry.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasource/dashboard_remote_datasource.dart';
import '../models/teacher_profile_dto.dart';
import '../models/academic_year_dto.dart';
import '../models/class_dto.dart';
import '../models/section_dto.dart';
import '../models/subject_dto.dart';
import '../models/timetable_dto.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDatasource _remoteDatasource;

  const DashboardRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  }) async {
    // 1. Fetch Teacher Profile
    final teacherResult = await _remoteDatasource.getTeacherProfile(
      email: email,
      schoolId: schoolId,
    );

    return teacherResult.when(
      onFailure: (failure) => ApiResult.failure(failure),
      onSuccess: (teachers) async {
        if (teachers.isEmpty) {
          return const ApiResult.failure(
            ApiFailure(
              message: 'Teacher profile not found for the logged-in email.',
              type: ApiFailureType.unknown,
              statusCode: 404,
            ),
          );
        }
        final teacherDto = teachers.first;

        // 2. Fetch Active Academic Year
        final ayResult = await _remoteDatasource.getActiveAcademicYear(
          schoolId: schoolId,
        );

        return ayResult.when(
          onFailure: (failure) => ApiResult.failure(failure),
          onSuccess: (academicYears) async {
            if (academicYears.isEmpty) {
              return const ApiResult.failure(
                ApiFailure(
                  message: 'No active academic year is configured for this school.',
                  type: ApiFailureType.unknown,
                  statusCode: 404,
                ),
              );
            }
            final activeAyDto = academicYears.first;

            // 3. Fetch Teacher Schedule
            final scheduleResult = await _remoteDatasource.getTeacherSchedule(
              teacherId: teacherDto.id,
              academicYearId: activeAyDto.id,
              schoolId: schoolId,
            );

            return scheduleResult.when(
              onFailure: (failure) => ApiResult.failure(failure),
              onSuccess: (List<TimetableDto> timetableDtos) async {
                // If there are no classes scheduled, we still succeed but return an empty schedule
                if (timetableDtos.isEmpty) {
                  return ApiResult.success(
                    DashboardDataEntity(
                      teacherProfile: _mapTeacher(teacherDto),
                      academicYear: _mapAcademicYear(activeAyDto),
                      schedule: const [],
                    ),
                  );
                }

                // 4. Fetch reference data to resolve IDs in parallel
                final classesFuture = _remoteDatasource.getClasses(
                  schoolId: schoolId,
                  academicYearId: activeAyDto.id,
                );
                final sectionsFuture = _remoteDatasource.getSections(
                  schoolId: schoolId,
                  academicYearId: activeAyDto.id,
                );
                final subjectsFuture = _remoteDatasource.getSubjects(
                  schoolId: schoolId,
                  academicYearId: activeAyDto.id,
                );

                final responses = await Future.wait([
                  classesFuture,
                  sectionsFuture,
                  subjectsFuture,
                ]);

                final classesResult = responses[0] as ApiResult<List<ClassDto>>;
                final sectionsResult = responses[1] as ApiResult<List<SectionDto>>;
                final subjectsResult = responses[2] as ApiResult<List<SubjectDto>>;

                // Map results or empty list if failed
                final classes = classesResult.dataOrNull ?? [];
                final sections = sectionsResult.dataOrNull ?? [];
                final subjects = subjectsResult.dataOrNull ?? [];

                final classMap = {for (var c in classes) c.id: c.name};
                final sectionMap = {for (var s in sections) s.id: s.name};
                final subjectMap = {for (var sub in subjects) sub.id: sub};

                // Map schedule to entities with names resolved
                final scheduleEntities = timetableDtos.map((TimetableDto dto) {
                  final className = classMap[dto.classId] ?? 'Class (N/A)';
                  final sectionName = sectionMap[dto.sectionId] ?? 'Section (N/A)';
                  final subjectDto = dto.subjectId != null ? subjectMap[dto.subjectId] : null;
                  
                  return TimetableEntryEntity(
                    id: dto.id,
                    dayOfWeek: dto.dayOfWeek,
                    periodNumber: dto.periodNumber,
                    startTime: dto.startTime,
                    endTime: dto.endTime,
                    periodType: dto.periodType,
                    roomId: dto.roomId,
                    isAvailable: dto.isAvailable,
                    classId: dto.classId,
                    className: className,
                    sectionId: dto.sectionId,
                    sectionName: sectionName,
                    subjectId: dto.subjectId,
                    subjectName: subjectDto?.subjectName ?? 'Subject (N/A)',
                    subjectCode: subjectDto?.subjectCode ?? '',
                    displayColor: subjectDto?.displayColor,
                  );
                }).toList();

                return ApiResult.success(
                  DashboardDataEntity(
                    teacherProfile: _mapTeacher(teacherDto),
                    academicYear: _mapAcademicYear(activeAyDto),
                    schedule: scheduleEntities,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  TeacherProfileEntity _mapTeacher(TeacherProfileDto dto) {
    return TeacherProfileEntity(
      id: dto.id,
      employeeCode: dto.employeeCode,
      firstName: dto.firstName,
      lastName: dto.lastName,
      designation: dto.designation,
      department: dto.department,
      officialEmail: dto.officialEmail,
      mobile: dto.mobile,
      status: dto.status,
    );
  }

  AcademicYearEntity _mapAcademicYear(AcademicYearDto dto) {
    return AcademicYearEntity(
      id: dto.id,
      name: dto.name,
      code: dto.code,
      status: dto.status,
    );
  }
}
