import 'package:equatable/equatable.dart';

class TeacherClassGroupEntity extends Equatable {
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final List<TeacherSubjectAssignmentEntity> assignments;

  const TeacherClassGroupEntity({
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.assignments,
  });

  @override
  List<Object?> get props => [classId, className, sectionId, sectionName, assignments];
}

class TeacherSubjectAssignmentEntity extends Equatable {
  final String id;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String? displayColor;
  final bool isClassTeacher;

  const TeacherSubjectAssignmentEntity({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.displayColor,
    required this.isClassTeacher,
  });

  @override
  List<Object?> get props => [id, subjectId, subjectName, subjectCode, displayColor, isClassTeacher];
}
