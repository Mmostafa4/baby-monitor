class CryAnalysisResult {
  final String category;
  final String advice;
  final bool urgent;
  final bool experimental;

  const CryAnalysisResult({
    required this.category,
    required this.advice,
    required this.urgent,
    required this.experimental,
  });
}
