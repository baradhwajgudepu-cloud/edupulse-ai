class StudentFailureDetailEntity {
  final String studentId;
  final String studentName;
  final List<String> reasons;

  const StudentFailureDetailEntity({
    required this.studentId,
    required this.studentName,
    required this.reasons,
  });
}

class BulkClassGenerateEntity {
  final int totalStudents;
  final int generatedCount;
  final int failedCount;
  final List<StudentFailureDetailEntity> failures;

  const BulkClassGenerateEntity({
    required this.totalStudents,
    required this.generatedCount,
    required this.failedCount,
    required this.failures,
  });
}
