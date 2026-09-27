/// Models representing Student 360 operational analytics directly from backend.
/// Strictly typed to avoid fallback or fabricated data.
class Student360TrendPoint {
  final String label;
  final double value;

  const Student360TrendPoint({required this.label, required this.value});

  factory Student360TrendPoint.fromJson(Map<String, dynamic> json) {
    return Student360TrendPoint(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Student360ExamTrend {
  final String label;
  final double value;
  final String? tooltipDetail;

  const Student360ExamTrend({
    required this.label,
    required this.value,
    this.tooltipDetail,
  });

  factory Student360ExamTrend.fromJson(Map<String, dynamic> json) {
    return Student360ExamTrend(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      tooltipDetail: json['tooltip_detail']?.toString(),
    );
  }
}

class Student360SubjectScore {
  final String subject;
  final double score;
  final String? grade;
  final bool strong;
  final bool needsSupport;

  const Student360SubjectScore({
    required this.subject,
    required this.score,
    this.grade,
    this.strong = false,
    this.needsSupport = false,
  });

  factory Student360SubjectScore.fromJson(Map<String, dynamic> json) {
    return Student360SubjectScore(
      subject: json['subject']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade']?.toString(),
      strong: json['strong'] == true,
      needsSupport: json['needs_support'] == true,
    );
  }
}

class Student360ExamSummary {
  final String examinationName;
  final String examType;
  final String examDate;
  final double totalMaxMarks;
  final double totalObtainedMarks;
  final double percentage;
  final String grade;
  final String status;

  const Student360ExamSummary({
    required this.examinationName,
    required this.examType,
    required this.examDate,
    required this.totalMaxMarks,
    required this.totalObtainedMarks,
    required this.percentage,
    required this.grade,
    required this.status,
  });

  factory Student360ExamSummary.fromJson(Map<String, dynamic> json) {
    return Student360ExamSummary(
      examinationName: json['examination_name']?.toString() ?? '',
      examType: json['exam_type']?.toString() ?? '',
      examDate: json['exam_date']?.toString() ?? '',
      totalMaxMarks: (json['total_max_marks'] as num?)?.toDouble() ?? 0.0,
      totalObtainedMarks: (json['total_obtained_marks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class Student360Attendance {
  final bool hasData;
  final double? attendanceRate;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int leaveDays;
  final int workingDays;
  final List<Student360TrendPoint> monthlyTrend;

  const Student360Attendance({
    this.hasData = false,
    this.attendanceRate,
    this.totalDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.lateDays = 0,
    this.leaveDays = 0,
    this.workingDays = 0,
    this.monthlyTrend = const [],
  });

  factory Student360Attendance.fromJson(Map<String, dynamic> json) {
    final tDays = json['total_days'] as int? ?? 0;
    return Student360Attendance(
      hasData: json['has_data'] == true,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble(),
      totalDays: tDays,
      presentDays: json['present_days'] as int? ?? 0,
      absentDays: json['absent_days'] as int? ?? 0,
      lateDays: json['late_days'] as int? ?? 0,
      leaveDays: json['leave_days'] as int? ?? 0,
      workingDays: json['working_days'] as int? ?? tDays,
      monthlyTrend: (json['monthly_trend'] as List<dynamic>?)
              ?.map((e) => Student360TrendPoint.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  factory Student360Attendance.empty() => const Student360Attendance();
}

class Student360Academics {
  final bool hasData;
  final double? academicAverage;
  final double? currentScore;
  final String? overallGrade;
  final String? classRank;
  final String? sectionRank;
  final List<Student360ExamSummary> completedExaminations;
  final List<Student360ExamTrend> examTrends;
  final List<Student360SubjectScore> subjectScores;

  const Student360Academics({
    this.hasData = false,
    this.academicAverage,
    this.currentScore,
    this.overallGrade,
    this.classRank,
    this.sectionRank,
    this.completedExaminations = const [],
    this.examTrends = const [],
    this.subjectScores = const [],
  });

  factory Student360Academics.fromJson(Map<String, dynamic> json) {
    return Student360Academics(
      hasData: json['has_data'] == true,
      academicAverage: (json['academic_average'] as num?)?.toDouble(),
      currentScore: (json['current_score'] as num?)?.toDouble() ??
          (json['academic_average'] as num?)?.toDouble(),
      overallGrade: json['overall_grade']?.toString(),
      classRank: json['class_rank']?.toString(),
      sectionRank: json['section_rank']?.toString(),
      completedExaminations: (json['completed_examinations'] as List<dynamic>?)
              ?.map((e) => Student360ExamSummary.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      examTrends: (json['exam_trends'] as List<dynamic>?)
              ?.map((e) => Student360ExamTrend.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      subjectScores: (json['subject_scores'] as List<dynamic>?)
              ?.map((e) => Student360SubjectScore.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  factory Student360Academics.empty() => const Student360Academics();
}

class Student360Fees {
  final bool hasData;
  final double totalAssigned;
  final double totalPaid;
  final double balanceOutstanding;
  final double? paidPercentage;
  final String status;

  const Student360Fees({
    this.hasData = false,
    this.totalAssigned = 0.0,
    this.totalPaid = 0.0,
    this.balanceOutstanding = 0.0,
    this.paidPercentage,
    this.status = 'No fee records',
  });

  factory Student360Fees.fromJson(Map<String, dynamic> json) {
    return Student360Fees(
      hasData: json['has_data'] == true,
      totalAssigned: (json['total_assigned'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      balanceOutstanding: (json['balance_outstanding'] as num?)?.toDouble() ?? 0.0,
      paidPercentage: (json['paid_percentage'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'No fee records',
    );
  }

  factory Student360Fees.empty() => const Student360Fees();
}

class Student360AiAnalysis {
  final bool hasData;
  final String dataState; // 'NO_DATA', 'PARTIAL_DATA', 'SUFFICIENT_DATA'
  final String? trend;
  final String? headline;
  final String? insight;
  final List<String> strongHighlights;
  final List<String> supportHighlights;
  final String? actionRecommendation;
  final String? statusMessage;

  const Student360AiAnalysis({
    this.hasData = false,
    this.dataState = 'NO_DATA',
    this.trend,
    this.headline,
    this.insight,
    this.strongHighlights = const [],
    this.supportHighlights = const [],
    this.actionRecommendation,
    this.statusMessage = 'Insufficient data for AI analysis',
  });

  factory Student360AiAnalysis.fromJson(Map<String, dynamic> json) {
    return Student360AiAnalysis(
      hasData: json['has_data'] == true,
      dataState: json['data_state']?.toString() ??
          (json['has_data'] == true ? 'SUFFICIENT_DATA' : 'NO_DATA'),
      trend: json['trend']?.toString(),
      headline: json['headline']?.toString(),
      insight: json['insight']?.toString(),
      strongHighlights: (json['strong_highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      supportHighlights: (json['support_highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      actionRecommendation: json['action_recommendation']?.toString(),
      statusMessage: json['status_message']?.toString() ??
          (json['has_data'] == true ? null : 'Insufficient data for AI analysis'),
    );
  }

  factory Student360AiAnalysis.empty() => const Student360AiAnalysis();
}

class Student360Homework {
  final String title;
  final String subject;
  final String status;
  final String date;

  const Student360Homework({
    required this.title,
    required this.subject,
    required this.status,
    required this.date,
  });

  factory Student360Homework.fromJson(Map<String, dynamic> json) {
    return Student360Homework(
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}

class Student360ActivityLog {
  final String time;
  final String event;
  final String by;

  const Student360ActivityLog({
    required this.time,
    required this.event,
    required this.by,
  });

  factory Student360ActivityLog.fromJson(Map<String, dynamic> json) {
    return Student360ActivityLog(
      time: json['time']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      by: json['by']?.toString() ?? '',
    );
  }
}

class Student360ReportCard {
  final String id;
  final String title;
  final String status;
  final String? generatedDate;
  final String? publishedDate;
  final bool isAvailable;
  final String? pdfUrl;

  const Student360ReportCard({
    required this.id,
    required this.title,
    required this.status,
    this.generatedDate,
    this.publishedDate,
    this.isAvailable = true,
    this.pdfUrl,
  });

  factory Student360ReportCard.fromJson(Map<String, dynamic> json) {
    return Student360ReportCard(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Report Card',
      status: json['status']?.toString() ?? 'DRAFT',
      generatedDate: json['generated_date']?.toString(),
      publishedDate: json['published_date']?.toString(),
      isAvailable: json['is_available'] == true,
      pdfUrl: json['pdf_url']?.toString(),
    );
  }
}

class Student360Analytics {
  final String studentId;
  final String schoolId;
  final String? academicYearId;
  final Student360Attendance attendance;
  final Student360Academics academics;
  final Student360Fees fees;
  final Student360AiAnalysis aiAnalysis;
  final List<Student360Homework> homework;
  final List<Student360ActivityLog> activityLogs;
  final List<Student360ReportCard> reports;

  const Student360Analytics({
    required this.studentId,
    required this.schoolId,
    this.academicYearId,
    required this.attendance,
    required this.academics,
    required this.fees,
    required this.aiAnalysis,
    this.homework = const [],
    this.activityLogs = const [],
    this.reports = const [],
  });

  factory Student360Analytics.fromJson(Map<String, dynamic> json) {
    return Student360Analytics(
      studentId: json['student_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      academicYearId: json['academic_year_id']?.toString(),
      attendance: json['attendance'] != null
          ? Student360Attendance.fromJson(Map<String, dynamic>.from(json['attendance'] as Map))
          : Student360Attendance.empty(),
      academics: json['academics'] != null
          ? Student360Academics.fromJson(Map<String, dynamic>.from(json['academics'] as Map))
          : Student360Academics.empty(),
      fees: json['fees'] != null
          ? Student360Fees.fromJson(Map<String, dynamic>.from(json['fees'] as Map))
          : Student360Fees.empty(),
      aiAnalysis: json['ai_analysis'] != null
          ? Student360AiAnalysis.fromJson(Map<String, dynamic>.from(json['ai_analysis'] as Map))
          : Student360AiAnalysis.empty(),
      homework: (json['homework'] as List<dynamic>?)
              ?.map((e) => Student360Homework.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      activityLogs: (json['activity_logs'] as List<dynamic>?)
              ?.map((e) => Student360ActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      reports: (json['reports'] as List<dynamic>?)
              ?.map((e) => Student360ReportCard.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  factory Student360Analytics.empty(String studentId, String schoolId) {
    return Student360Analytics(
      studentId: studentId,
      schoolId: schoolId,
      attendance: Student360Attendance.empty(),
      academics: Student360Academics.empty(),
      fees: Student360Fees.empty(),
      aiAnalysis: Student360AiAnalysis.empty(),
      homework: const [],
      activityLogs: const [],
      reports: const [],
    );
  }
}
