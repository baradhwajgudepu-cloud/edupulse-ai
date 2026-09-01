class ExamSchedule {
  final String id;
  final String subjectId;
  final String examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;

  ExamSchedule({
    required this.id,
    required this.subjectId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      examDate: json['exam_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      maxMarks: json['max_marks'] as int? ?? 100,
      passMarks: json['pass_marks'] as int? ?? 35,
    );
  }
}

class Examination {
  final String id;
  final String examName;
  final String examType;
  final String startDate;
  final String endDate;
  final String status;
  final String? description;
  final List<ExamSchedule> schedules;

  Examination({
    required this.id,
    required this.examName,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    required this.schedules,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    final schedList = json['schedules'] as List<dynamic>? ?? [];
    return Examination(
      id: json['id'] as String? ?? '',
      examName: json['exam_name'] as String? ?? '',
      examType: json['exam_type'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      description: json['description'] as String?,
      schedules: schedList.map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MarksSummary {
  final double classAverage;
  final double passPercentage;
  final double highestScore;
  final double lowestScore;
  final int missingCount;
  final int absentCount;

  MarksSummary({
    required this.classAverage,
    required this.passPercentage,
    required this.highestScore,
    required this.lowestScore,
    required this.missingCount,
    required this.absentCount,
  });

  factory MarksSummary.fromJson(Map<String, dynamic> json) {
    return MarksSummary(
      classAverage: (json['class_average'] as num?)?.toDouble() ?? 0.0,
      passPercentage: (json['pass_percentage'] as num?)?.toDouble() ?? 0.0,
      highestScore: (json['highest_score'] as num?)?.toDouble() ?? 0.0,
      lowestScore: (json['lowest_score'] as num?)?.toDouble() ?? 0.0,
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory MarksSummary.empty() {
    return MarksSummary(
      classAverage: 0.0,
      passPercentage: 0.0,
      highestScore: 0.0,
      lowestScore: 0.0,
      missingCount: 0,
      absentCount: 0,
    );
  }
}
