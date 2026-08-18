class ResultSummaryEntity {
  final double classAverage;
  final double passPercentage;
  final double highestScore;
  final double lowestScore;
  final int missingCount;
  final int absentCount;

  const ResultSummaryEntity({
    required this.classAverage,
    required this.passPercentage,
    required this.highestScore,
    required this.lowestScore,
    required this.missingCount,
    required this.absentCount,
  });
}
