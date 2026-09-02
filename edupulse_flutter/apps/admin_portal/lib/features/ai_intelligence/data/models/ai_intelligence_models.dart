class SubScoreItem {
  final double score;
  final String status;

  const SubScoreItem({
    required this.score,
    required this.status,
  });

  factory SubScoreItem.fromJson(Map<String, dynamic> json) {
    return SubScoreItem(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'NORMAL',
    );
  }
}

class SchoolHealthSubScores {
  final SubScoreItem academicPerformance;
  final SubScoreItem attendanceCorrelation;
  final SubScoreItem subjectDifficulty;
  final SubScoreItem marksCompletion;
  final SubScoreItem examReadiness;

  const SchoolHealthSubScores({
    required this.academicPerformance,
    required this.attendanceCorrelation,
    required this.subjectDifficulty,
    required this.marksCompletion,
    required this.examReadiness,
  });

  factory SchoolHealthSubScores.fromJson(Map<String, dynamic> json) {
    return SchoolHealthSubScores(
      academicPerformance: SubScoreItem.fromJson(json['academic_performance'] as Map<String, dynamic>? ?? {}),
      attendanceCorrelation: SubScoreItem.fromJson(json['attendance_correlation'] as Map<String, dynamic>? ?? {}),
      subjectDifficulty: SubScoreItem.fromJson(json['subject_difficulty'] as Map<String, dynamic>? ?? {}),
      marksCompletion: SubScoreItem.fromJson(json['marks_completion'] as Map<String, dynamic>? ?? {}),
      examReadiness: SubScoreItem.fromJson(json['exam_readiness'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class AcademicRiskStudentModel {
  final String studentId;
  final String studentName;
  final String? admissionNumber;
  final String className;
  final String sectionName;
  final double academicPercentage;
  final int failedSubjectsCount;
  final String riskTier;
  final int confidenceScore;
  final List<String> primaryFactors;
  final String recommendedIntervention;

  const AcademicRiskStudentModel({
    required this.studentId,
    required this.studentName,
    this.admissionNumber,
    required this.className,
    required this.sectionName,
    required this.academicPercentage,
    required this.failedSubjectsCount,
    required this.riskTier,
    required this.confidenceScore,
    required this.primaryFactors,
    required this.recommendedIntervention,
  });

  factory AcademicRiskStudentModel.fromJson(Map<String, dynamic> json) {
    return AcademicRiskStudentModel(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? 'Unknown',
      admissionNumber: json['admission_number'] as String?,
      className: json['class_name'] as String? ?? 'Class',
      sectionName: json['section_name'] as String? ?? 'Section',
      academicPercentage: (json['academic_percentage'] as num?)?.toDouble() ?? 0.0,
      failedSubjectsCount: json['failed_subjects_count'] as int? ?? 0,
      riskTier: json['risk_tier'] as String? ?? 'LOW',
      confidenceScore: json['confidence_score'] as int? ?? 75,
      primaryFactors: (json['primary_factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      recommendedIntervention: json['recommended_intervention'] as String? ?? 'Monitor academic progress.',
    );
  }
}

class PerformanceTrendModel {
  final String examinationId;
  final String examinationName;
  final String startDate;
  final double averagePercentage;
  final double deltaPercentage;
  final String trendDirection;
  final String aiAnalysis;

  const PerformanceTrendModel({
    required this.examinationId,
    required this.examinationName,
    required this.startDate,
    required this.averagePercentage,
    required this.deltaPercentage,
    required this.trendDirection,
    required this.aiAnalysis,
  });

  factory PerformanceTrendModel.fromJson(Map<String, dynamic> json) {
    return PerformanceTrendModel(
      examinationId: json['examination_id'] as String? ?? '',
      examinationName: json['examination_name'] as String? ?? 'Exam',
      startDate: json['start_date'] as String? ?? '',
      averagePercentage: (json['average_percentage'] as num?)?.toDouble() ?? 0.0,
      deltaPercentage: (json['delta_percentage'] as num?)?.toDouble() ?? 0.0,
      trendDirection: json['trend_direction'] as String? ?? 'STABLE',
      aiAnalysis: json['ai_analysis'] as String? ?? '',
    );
  }
}

class SubjectDifficultyModel {
  final String subjectId;
  final String subjectName;
  final double averagePercentage;
  final double below50Percentage;
  final String difficultyIndex;
  final String remedialRecommendation;

  const SubjectDifficultyModel({
    required this.subjectId,
    required this.subjectName,
    required this.averagePercentage,
    required this.below50Percentage,
    required this.difficultyIndex,
    required this.remedialRecommendation,
  });

  factory SubjectDifficultyModel.fromJson(Map<String, dynamic> json) {
    return SubjectDifficultyModel(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      averagePercentage: (json['average_percentage'] as num?)?.toDouble() ?? 0.0,
      below50Percentage: (json['below_50_percentage'] as num?)?.toDouble() ?? 0.0,
      difficultyIndex: json['difficulty_index'] as String? ?? 'NORMAL',
      remedialRecommendation: json['remedial_recommendation'] as String? ?? '',
    );
  }
}

class MarksAnomalyModel {
  final String classSection;
  final String subjectName;
  final double averagePercentage;
  final double standardDeviation;
  final String anomalyType;
  final String recommendedReview;

  const MarksAnomalyModel({
    required this.classSection,
    required this.subjectName,
    required this.averagePercentage,
    required this.standardDeviation,
    required this.anomalyType,
    required this.recommendedReview,
  });

  factory MarksAnomalyModel.fromJson(Map<String, dynamic> json) {
    return MarksAnomalyModel(
      classSection: json['class_section'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      averagePercentage: (json['average_percentage'] as num?)?.toDouble() ?? 0.0,
      standardDeviation: (json['standard_deviation'] as num?)?.toDouble() ?? 0.0,
      anomalyType: json['anomaly_type'] as String? ?? 'UNUSUAL_VARIATION',
      recommendedReview: json['recommended_review'] as String? ?? '',
    );
  }
}

class AIIntelligenceSummaryModel {
  final int schoolHealthScore;
  final SchoolHealthSubScores subScores;
  final String aiExecutiveSummary;
  final List<AcademicRiskStudentModel> academicRiskRadar;
  final List<PerformanceTrendModel> performanceTrends;
  final List<SubjectDifficultyModel> subjectDifficultyAnalysis;
  final List<MarksAnomalyModel> marksAnomalies;

  const AIIntelligenceSummaryModel({
    required this.schoolHealthScore,
    required this.subScores,
    required this.aiExecutiveSummary,
    required this.academicRiskRadar,
    required this.performanceTrends,
    required this.subjectDifficultyAnalysis,
    required this.marksAnomalies,
  });

  factory AIIntelligenceSummaryModel.fromJson(Map<String, dynamic> json) {
    final subScoresJson = json['sub_scores'] as Map<String, dynamic>? ?? {};
    return AIIntelligenceSummaryModel(
      schoolHealthScore: json['school_health_score'] as int? ?? 80,
      subScores: SchoolHealthSubScores.fromJson(subScoresJson),
      aiExecutiveSummary: json['ai_executive_summary'] as String? ?? 'Academic metrics stable.',
      academicRiskRadar: (json['academic_risk_radar'] as List<dynamic>?)
              ?.map((e) => AcademicRiskStudentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      performanceTrends: (json['performance_trends'] as List<dynamic>?)
              ?.map((e) => PerformanceTrendModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subjectDifficultyAnalysis: (json['subject_difficulty_analysis'] as List<dynamic>?)
              ?.map((e) => SubjectDifficultyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      marksAnomalies: (json['marks_anomalies'] as List<dynamic>?)
              ?.map((e) => MarksAnomalyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
