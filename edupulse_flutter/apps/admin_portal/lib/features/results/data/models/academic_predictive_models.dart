import 'package:flutter/foundation.dart';

@immutable
class DataSufficiencyModel {
  final int examCount;
  final int minRequiredExams;
  final String sufficiencyStatus; // INSUFFICIENT_DATA | DESCRIPTIVE_ONLY | PREDICTIVE_ACTIVE
  final String statusMessage;
  final bool isPredictive;

  const DataSufficiencyModel({
    required this.examCount,
    required this.minRequiredExams,
    required this.sufficiencyStatus,
    required this.statusMessage,
    required this.isPredictive,
  });

  bool get isInsufficient => sufficiencyStatus == 'INSUFFICIENT_DATA';
  bool get isDescriptiveOnly => sufficiencyStatus == 'DESCRIPTIVE_ONLY';
  bool get isPredictiveActive => sufficiencyStatus == 'PREDICTIVE_ACTIVE';

  factory DataSufficiencyModel.fromJson(Map<String, dynamic> json) {
    return DataSufficiencyModel(
      examCount: (json['exam_count'] is num) ? (json['exam_count'] as num).toInt() : 0,
      minRequiredExams: (json['min_required_exams'] is num) ? (json['min_required_exams'] as num).toInt() : 2,
      sufficiencyStatus: (json['sufficiency_status'] ?? 'INSUFFICIENT_DATA').toString(),
      statusMessage: (json['status_message'] ?? 'Insufficient assessment data').toString(),
      isPredictive: json['is_predictive'] == true,
    );
  }
}

@immutable
class ScoreBandModel {
  final double minPercentage;
  final double maxPercentage;
  final String confidenceInterval;

  const ScoreBandModel({
    required this.minPercentage,
    required this.maxPercentage,
    this.confidenceInterval = '95%',
  });

  factory ScoreBandModel.fromJson(Map<String, dynamic> json) {
    return ScoreBandModel(
      minPercentage: (json['min_percentage'] is num) ? (json['min_percentage'] as num).toDouble() : 0.0,
      maxPercentage: (json['max_percentage'] is num) ? (json['max_percentage'] as num).toDouble() : 0.0,
      confidenceInterval: (json['confidence_interval'] ?? '95%').toString(),
    );
  }
}

@immutable
class SubjectHistoricalTrend {
  final String examinationId;
  final String examinationName;
  final double averagePercentage;
  final String? examDate;

  const SubjectHistoricalTrend({
    required this.examinationId,
    required this.examinationName,
    required this.averagePercentage,
    this.examDate,
  });

  factory SubjectHistoricalTrend.fromJson(Map<String, dynamic> json) {
    return SubjectHistoricalTrend(
      examinationId: (json['examination_id'] ?? '').toString(),
      examinationName: (json['examination_name'] ?? 'Exam').toString(),
      averagePercentage: (json['average_percentage'] is num) ? (json['average_percentage'] as num).toDouble() : 0.0,
      examDate: json['exam_date']?.toString(),
    );
  }
}

@immutable
class SubjectPredictivePerformance {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final double averagePercentage;
  final double minPercentage;
  final double maxPercentage;
  final double passRatePercentage;
  final String difficultyRating; // EASY | MEDIUM | HARD
  final List<SubjectHistoricalTrend> historicalTrend;
  final ScoreBandModel? predictedScoreBand;
  final String riskLevel; // LOW | MODERATE | HIGH
  final double syllabusCoveragePct;

  const SubjectPredictivePerformance({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.averagePercentage,
    required this.minPercentage,
    required this.maxPercentage,
    required this.passRatePercentage,
    required this.difficultyRating,
    required this.historicalTrend,
    this.predictedScoreBand,
    required this.riskLevel,
    required this.syllabusCoveragePct,
  });

  factory SubjectPredictivePerformance.fromJson(Map<String, dynamic> json) {
    return SubjectPredictivePerformance(
      subjectId: (json['subject_id'] ?? '').toString(),
      subjectName: (json['subject_name'] ?? '').toString(),
      subjectCode: (json['subject_code'] ?? '').toString(),
      averagePercentage: (json['average_percentage'] is num) ? (json['average_percentage'] as num).toDouble() : 0.0,
      minPercentage: (json['min_percentage'] is num) ? (json['min_percentage'] as num).toDouble() : 0.0,
      maxPercentage: (json['max_percentage'] is num) ? (json['max_percentage'] as num).toDouble() : 0.0,
      passRatePercentage: (json['pass_rate_percentage'] is num) ? (json['pass_rate_percentage'] as num).toDouble() : 0.0,
      difficultyRating: (json['difficulty_rating'] ?? 'MEDIUM').toString(),
      historicalTrend: (json['historical_trend'] as List?)
          ?.map((e) => SubjectHistoricalTrend.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      predictedScoreBand: json['predicted_score_band'] != null
          ? ScoreBandModel.fromJson(json['predicted_score_band'] as Map<String, dynamic>)
          : null,
      riskLevel: (json['risk_level'] ?? 'LOW').toString(),
      syllabusCoveragePct: (json['syllabus_coverage_pct'] is num) ? (json['syllabus_coverage_pct'] as num).toDouble() : 0.0,
    );
  }
}

@immutable
class ChapterPerformanceItem {
  final String chapterName;
  final String subjectName;
  final int totalQuestions;
  final double totalMarksAllocated;
  final String difficulty;
  final double averageAccuracyPct;
  final bool weakAreaAlert;

  const ChapterPerformanceItem({
    required this.chapterName,
    required this.subjectName,
    required this.totalQuestions,
    required this.totalMarksAllocated,
    required this.difficulty,
    required this.averageAccuracyPct,
    required this.weakAreaAlert,
  });

  factory ChapterPerformanceItem.fromJson(Map<String, dynamic> json) {
    return ChapterPerformanceItem(
      chapterName: (json['chapter_name'] ?? '').toString(),
      subjectName: (json['subject_name'] ?? '').toString(),
      totalQuestions: (json['total_questions'] is num) ? (json['total_questions'] as num).toInt() : 0,
      totalMarksAllocated: (json['total_marks_allocated'] is num) ? (json['total_marks_allocated'] as num).toDouble() : 0.0,
      difficulty: (json['difficulty'] ?? 'MEDIUM').toString(),
      averageAccuracyPct: (json['average_accuracy_pct'] is num) ? (json['average_accuracy_pct'] as num).toDouble() : 0.0,
      weakAreaAlert: json['weak_area_alert'] == true,
    );
  }
}

@immutable
class ChapterPerformanceBlock {
  final bool isAvailable;
  final String message;
  final List<ChapterPerformanceItem> chapters;

  const ChapterPerformanceBlock({
    required this.isAvailable,
    required this.message,
    required this.chapters,
  });

  factory ChapterPerformanceBlock.fromJson(Map<String, dynamic> json) {
    return ChapterPerformanceBlock(
      isAvailable: json['is_available'] == true,
      message: (json['message'] ?? '').toString(),
      chapters: (json['chapters'] as List?)
          ?.map((e) => ChapterPerformanceItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

@immutable
class SyllabusCorrelationBlock {
  final bool isAvailable;
  final String message;
  final double? correlationIndex;
  final String? coverageVsScoreSummary;

  const SyllabusCorrelationBlock({
    required this.isAvailable,
    required this.message,
    this.correlationIndex,
    this.coverageVsScoreSummary,
  });

  factory SyllabusCorrelationBlock.fromJson(Map<String, dynamic> json) {
    return SyllabusCorrelationBlock(
      isAvailable: json['is_available'] == true,
      message: (json['message'] ?? '').toString(),
      correlationIndex: (json['correlation_index'] is num) ? (json['correlation_index'] as num).toDouble() : null,
      coverageVsScoreSummary: json['coverage_vs_score_summary']?.toString(),
    );
  }
}

@immutable
class AcademicPredictiveAnalyticsModel {
  final DataSufficiencyModel dataSufficiency;
  final List<SubjectPredictivePerformance> subjectPerformance;
  final ChapterPerformanceBlock chapterPerformance;
  final SyllabusCorrelationBlock syllabusCorrelation;

  const AcademicPredictiveAnalyticsModel({
    required this.dataSufficiency,
    required this.subjectPerformance,
    required this.chapterPerformance,
    required this.syllabusCorrelation,
  });

  factory AcademicPredictiveAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AcademicPredictiveAnalyticsModel(
      dataSufficiency: DataSufficiencyModel.fromJson(json['data_sufficiency'] as Map<String, dynamic>? ?? {}),
      subjectPerformance: (json['subject_performance'] as List?)
          ?.map((e) => SubjectPredictivePerformance.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      chapterPerformance: ChapterPerformanceBlock.fromJson(json['chapter_performance'] as Map<String, dynamic>? ?? {}),
      syllabusCorrelation: SyllabusCorrelationBlock.fromJson(json['syllabus_correlation'] as Map<String, dynamic>? ?? {}),
    );
  }
}

@immutable
class StudentPredictiveSummary {
  final String trajectoryDirection; // IMPROVING | DECLINING | STABLE
  final double trajectorySlope;
  final ScoreBandModel? predictedScoreBand;
  final List<String> weakSubjects;
  final List<String> strongSubjects;

  const StudentPredictiveSummary({
    required this.trajectoryDirection,
    required this.trajectorySlope,
    this.predictedScoreBand,
    required this.weakSubjects,
    required this.strongSubjects,
  });

  factory StudentPredictiveSummary.fromJson(Map<String, dynamic> json) {
    return StudentPredictiveSummary(
      trajectoryDirection: (json['trajectory_direction'] ?? 'STABLE').toString(),
      trajectorySlope: (json['trajectory_slope'] is num) ? (json['trajectory_slope'] as num).toDouble() : 0.0,
      predictedScoreBand: json['predicted_score_band'] != null
          ? ScoreBandModel.fromJson(json['predicted_score_band'] as Map<String, dynamic>)
          : null,
      weakSubjects: (json['weak_subjects'] as List?)?.map((e) => e.toString()).toList() ?? [],
      strongSubjects: (json['strong_subjects'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

@immutable
class StudentPredictiveAnalyticsModel {
  final DataSufficiencyModel dataSufficiency;
  final StudentPredictiveSummary? studentPredictiveSummary;
  final List<Map<String, dynamic>> examHistory;

  const StudentPredictiveAnalyticsModel({
    required this.dataSufficiency,
    this.studentPredictiveSummary,
    required this.examHistory,
  });

  factory StudentPredictiveAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return StudentPredictiveAnalyticsModel(
      dataSufficiency: DataSufficiencyModel.fromJson(json['data_sufficiency'] as Map<String, dynamic>? ?? {}),
      studentPredictiveSummary: json['student_predictive_summary'] != null
          ? StudentPredictiveSummary.fromJson(json['student_predictive_summary'] as Map<String, dynamic>)
          : null,
      examHistory: (json['exam_history'] as List?)
          ?.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList() ?? [],
    );
  }
}
