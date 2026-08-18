class ExamScheduleEntity {
  final String id;
  final String examId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String teacherSubjectAssignmentId;
  final DateTime examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;
  final String? roomNumber;
  final bool isActive;
  final int version;

  const ExamScheduleEntity({
    required this.id,
    required this.examId,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.teacherSubjectAssignmentId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
    this.roomNumber,
    required this.isActive,
    required this.version,
  });
}
