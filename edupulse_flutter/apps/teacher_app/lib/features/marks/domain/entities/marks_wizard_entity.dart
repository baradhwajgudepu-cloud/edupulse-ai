import 'student_mark_entity.dart';

class StudentShortInfoEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String rollNumber;

  const StudentShortInfoEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.rollNumber,
  });

  String get fullName => '$firstName $lastName';
}

class MarkWizardItemEntity {
  final StudentShortInfoEntity student;
  final StudentMarkEntity? markRecord;
  final bool isMissing;

  const MarkWizardItemEntity({
    required this.student,
    this.markRecord,
    required this.isMissing,
  });
}

class MarksWizardEntity {
  final int totalStudents;
  final int enteredCount;
  final int missingCount;
  final double? averageScore;
  final double? highestScore;
  final double? lowestScore;
  final List<StudentShortInfoEntity> missingStudents;
  final List<MarkWizardItemEntity> entries;

  const MarksWizardEntity({
    required this.totalStudents,
    required this.enteredCount,
    required this.missingCount,
    this.averageScore,
    this.highestScore,
    this.lowestScore,
    required this.missingStudents,
    required this.entries,
  });
}
