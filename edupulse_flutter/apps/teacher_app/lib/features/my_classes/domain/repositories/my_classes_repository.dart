import 'package:edupulse_network/edupulse_network.dart';
import '../entities/teacher_class_group.dart';
import '../entities/student.dart';

abstract class MyClassesRepository {
  Future<ApiResult<List<TeacherClassGroupEntity>>> getTeacherClasses({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  });

  Future<ApiResult<List<StudentEntity>>> getClassStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  });

  Future<ApiResult<List<StudentEntity>>> getTeacherStudents({
    required String schoolId,
    required String academicYearId,
  });
}
