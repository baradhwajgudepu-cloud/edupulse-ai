class MarksPublishSummaryEntity {
  final String examName;
  final String subjectName;
  final String className;
  final int totalStudents;
  final int enteredCount;
  final int missingCount;
  final double passPercentage;

  const MarksPublishSummaryEntity({
    required this.examName,
    required this.subjectName,
    required this.className,
    required this.totalStudents,
    required this.enteredCount,
    required this.missingCount,
    required this.passPercentage,
  });
}
