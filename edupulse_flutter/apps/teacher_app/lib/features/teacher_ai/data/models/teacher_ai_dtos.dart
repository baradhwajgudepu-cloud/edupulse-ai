class StudentInsightDto {
  final String performanceTrend;
  final String attendanceTrend;
  final List<String> improvementAreas;
  final List<String> attentionAreas;
  final String? recentAcademicChanges;
  final List<String> suggestedActions;
  final String summary;

  StudentInsightDto({
    required this.performanceTrend,
    required this.attendanceTrend,
    required this.improvementAreas,
    required this.attentionAreas,
    this.recentAcademicChanges,
    required this.suggestedActions,
    required this.summary,
  });

  factory StudentInsightDto.fromJson(Map<String, dynamic> json) {
    return StudentInsightDto(
      performanceTrend: json['performance_trend'] as String? ?? '',
      attendanceTrend: json['attendance_trend'] as String? ?? '',
      improvementAreas: List<String>.from(json['improvement_areas'] as List? ?? []),
      attentionAreas: List<String>.from(json['attention_areas'] as List? ?? []),
      recentAcademicChanges: json['recent_academic_changes'] as String?,
      suggestedActions: List<String>.from(json['suggested_actions'] as List? ?? []),
      summary: json['summary'] as String? ?? '',
    );
  }
}

class ClassAnalysisDto {
  final double classAverage;
  final Map<String, int> gradeDistribution;
  final double passPercentage;
  final String improvementTrend;
  final List<String> studentsImproving;
  final List<String> studentsDeclining;
  final List<String> strongAreas;
  final List<String> needsReinforcementAreas;
  final List<String> suggestedActions;

  ClassAnalysisDto({
    required this.classAverage,
    required this.gradeDistribution,
    required this.passPercentage,
    required this.improvementTrend,
    required this.studentsImproving,
    required this.studentsDeclining,
    required this.strongAreas,
    required this.needsReinforcementAreas,
    required this.suggestedActions,
  });

  factory ClassAnalysisDto.fromJson(Map<String, dynamic> json) {
    final gradeMap = <String, int>{};
    if (json['grade_distribution'] is Map) {
      (json['grade_distribution'] as Map).forEach((k, v) {
        gradeMap[k.toString()] = (v as num? ?? 0).toInt();
      });
    }
    return ClassAnalysisDto(
      classAverage: (json['class_average'] as num? ?? 0.0).toDouble(),
      gradeDistribution: gradeMap,
      passPercentage: (json['pass_percentage'] as num? ?? 0.0).toDouble(),
      improvementTrend: json['improvement_trend'] as String? ?? '',
      studentsImproving: List<String>.from(json['students_improving'] as List? ?? []),
      studentsDeclining: List<String>.from(json['students_declining'] as List? ?? []),
      strongAreas: List<String>.from(json['strong_areas'] as List? ?? []),
      needsReinforcementAreas: List<String>.from(json['needs_reinforcement_areas'] as List? ?? []),
      suggestedActions: List<String>.from(json['suggested_actions'] as List? ?? []),
    );
  }
}

class RemarkGenerationDto {
  final String draftRemark;

  RemarkGenerationDto({required this.draftRemark});

  factory RemarkGenerationDto.fromJson(Map<String, dynamic> json) {
    return RemarkGenerationDto(
      draftRemark: json['draft_remark'] as String? ?? '',
    );
  }
}

class GeneratedQuestionDto {
  final String text;
  final int marks;
  final String difficulty;
  final List<String>? choices;
  final String? answerKey;

  GeneratedQuestionDto({
    required this.text,
    required this.marks,
    required this.difficulty,
    this.choices,
    this.answerKey,
  });

  factory GeneratedQuestionDto.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestionDto(
      text: json['text'] as String? ?? '',
      marks: (json['marks'] as num? ?? 0).toInt(),
      difficulty: json['difficulty'] as String? ?? '',
      choices: json['choices'] != null ? List<String>.from(json['choices'] as List) : null,
      answerKey: json['answer_key'] as String?,
    );
  }
}

class HomeworkGenerationDto {
  final String title;
  final String description;
  final String learningObjective;
  final String difficulty;
  final int estimatedMinutes;
  final List<GeneratedQuestionDto> questions;

  HomeworkGenerationDto({
    required this.title,
    required this.description,
    required this.learningObjective,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.questions,
  });

  factory HomeworkGenerationDto.fromJson(Map<String, dynamic> json) {
    return HomeworkGenerationDto(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      learningObjective: json['learning_objective'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      estimatedMinutes: (json['estimated_minutes'] as num? ?? 0).toInt(),
      questions: (json['questions'] as List? ?? [])
          .map((q) => GeneratedQuestionDto.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestionsGenerationDto {
  final List<GeneratedQuestionDto> questions;

  QuestionsGenerationDto({required this.questions});

  factory QuestionsGenerationDto.fromJson(Map<String, dynamic> json) {
    return QuestionsGenerationDto(
      questions: (json['questions'] as List? ?? [])
          .map((q) => GeneratedQuestionDto.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
