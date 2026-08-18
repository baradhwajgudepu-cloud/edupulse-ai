import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/teacher_class_group.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/my_classes_repository.dart';
import '../datasource/my_classes_remote_datasource.dart';
import '../models/teacher_subject_assignment_dto.dart';
import '../../../dashboard/data/models/class_dto.dart';
import '../../../dashboard/data/models/section_dto.dart';
import '../../../dashboard/data/models/subject_dto.dart';

class MyClassesRepositoryImpl implements MyClassesRepository {
  final MyClassesRemoteDatasource _remoteDatasource;

  const MyClassesRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<List<TeacherClassGroupEntity>>> getTeacherClasses({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  }) async {
    final assignmentsResult = await _remoteDatasource.getTeacherAssignments(
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
    );

    return assignmentsResult.when(
      onFailure: (failure) => ApiResult.failure(failure),
      onSuccess: (assignments) async {
        if (assignments.isEmpty) {
          return const ApiResult.success([]);
        }

        // Fetch reference catalogs in parallel to resolve names
        final responses = await Future.wait([
          _remoteDatasource.getClasses(schoolId: schoolId, academicYearId: academicYearId),
          _remoteDatasource.getSections(schoolId: schoolId, academicYearId: academicYearId),
          _remoteDatasource.getSubjects(schoolId: schoolId, academicYearId: academicYearId),
        ]);

        final classesResult = responses[0] as ApiResult<List<ClassDto>>;
        final sectionsResult = responses[1] as ApiResult<List<SectionDto>>;
        final subjectsResult = responses[2] as ApiResult<List<SubjectDto>>;

        final classesList = classesResult.dataOrNull ?? [];
        final sectionsList = sectionsResult.dataOrNull ?? [];
        final subjectsList = subjectsResult.dataOrNull ?? [];

        final classMap = {for (var c in classesList) c.id: c.name};
        final sectionMap = {for (var s in sectionsList) s.id: s.name};
        final subjectMap = {for (var sub in subjectsList) sub.id: sub};

        // Group assignments by class_id and section_id
        final Map<String, List<TeacherSubjectAssignmentDto>> groupedMap = {};
        for (final assignment in assignments) {
          final key = '${assignment.classId}:${assignment.sectionId}';
          groupedMap.putIfAbsent(key, () => []).add(assignment);
        }

        final List<TeacherClassGroupEntity> groups = [];

        groupedMap.forEach((key, list) {
          final parts = key.split(':');
          final classId = parts[0];
          final sectionId = parts[1];

          final className = classMap[classId] ?? 'Class ($classId)';
          final sectionName = sectionMap[sectionId] ?? 'Section ($sectionId)';

          // Map DTOs to entities, filtering out duplicates if any
          final List<TeacherSubjectAssignmentEntity> subjectAssignments = [];
          final Set<String> seenSubjects = {};

          for (final dto in list) {
            if (seenSubjects.contains(dto.subjectId)) {
              continue; // Avoid duplicate presentation in the UI
            }
            seenSubjects.add(dto.subjectId);

            final subjectDto = subjectMap[dto.subjectId];
            final subjectName = subjectDto?.subjectName ?? 'Subject (${dto.subjectId})';
            final subjectCode = subjectDto?.subjectCode ?? '';
            final displayColor = subjectDto?.displayColor;

            subjectAssignments.add(
              TeacherSubjectAssignmentEntity(
                id: dto.id,
                subjectId: dto.subjectId,
                subjectName: subjectName,
                subjectCode: subjectCode,
                displayColor: displayColor,
                isClassTeacher: dto.isClassTeacher,
              ),
            );
          }

          groups.add(
            TeacherClassGroupEntity(
              classId: classId,
              className: className,
              sectionId: sectionId,
              sectionName: sectionName,
              assignments: subjectAssignments,
            ),
          );
        });

        // Optional: Sort groups by class name then section name
        groups.sort((a, b) {
          final classCompare = a.className.compareTo(b.className);
          if (classCompare != 0) return classCompare;
          return a.sectionName.compareTo(b.sectionName);
        });

        return ApiResult.success(groups);
      },
    );
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getClassStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) async {
    final result = await _remoteDatasource.getStudents(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );

    return result.when(
      onFailure: (failure) => ApiResult.failure(failure),
      onSuccess: (studentDtos) async {
        final students = studentDtos.map((dto) {
          return StudentEntity(
            id: dto.id,
            firstName: dto.firstName,
            middleName: dto.middleName,
            lastName: dto.lastName,
            gender: dto.gender,
            dateOfBirth: dto.dateOfBirth,
            bloodGroup: dto.bloodGroup,
            mobile: dto.mobile,
            email: dto.email,
            photoUrl: dto.photoUrl,
            admissionNumber: dto.admissionNumber,
            rollNumber: dto.rollNumber,
            status: dto.status,
            className: dto.className ?? 'Class',
            sectionName: dto.sectionName ?? 'Section',
          );
        }).toList();

        // Sort students by roll number or name
        students.sort((a, b) {
          final aRoll = int.tryParse(a.rollNumber) ?? 9999;
          final bRoll = int.tryParse(b.rollNumber) ?? 9999;
          final rollCompare = aRoll.compareTo(bRoll);
          if (rollCompare != 0) return rollCompare;
          return a.fullName.compareTo(b.fullName);
        });

        return ApiResult.success(students);
      },
    );
  }
}
