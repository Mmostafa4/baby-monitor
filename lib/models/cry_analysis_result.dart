class CryAnalysisResult {
  final String category;
  final String advice;
  final int scorePercent;
  final bool urgent;
  final bool experimental;

  const CryAnalysisResult({
    required this.category,
    required this.advice,
    required this.scorePercent,
    required this.urgent,
    required this.experimental,
  });
}
