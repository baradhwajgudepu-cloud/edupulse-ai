class ReportCardSubjectMarkRowEntity {
  final String subjectName;
  final int maximumMarks;
  final double? marksObtained;
  final String resultStatus;
  final String grade;
  final String? remarks;

  const ReportCardSubjectMarkRowEntity({
    required this.subjectName,
    required this.maximumMarks,
    this.marksObtained,
    required this.resultStatus,
    required this.grade,
    this.remarks,
  });
}

class ReportCardPreviewEntity {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String sectionName;
  
  final int attendanceTotal;
  final int attendancePresent;
  final double attendancePercentage;
  
  final double overallPercentage;
  final String overallGrade;
  final String promotionStatus;
  
  final List<ReportCardSubjectMarkRowEntity> subjectMarks;
  final String? teacherRemarks;
  final String? principalRemarks;
  final String aiNarrative;
  
  final bool isValid;
  final List<String> missingReasons;

  const ReportCardPreviewEntity({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.attendanceTotal,
    required this.attendancePresent,
    required this.attendancePercentage,
    required this.overallPercentage,
    required this.overallGrade,
    required this.promotionStatus,
    required this.subjectMarks,
    this.teacherRemarks,
    this.principalRemarks,
    required this.aiNarrative,
    required this.isValid,
    required this.missingReasons,
  });
}
