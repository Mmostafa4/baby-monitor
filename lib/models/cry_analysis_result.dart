class CryAnalysisResult {
  final String category;
  final double confidence;
  final String advice;
  final bool urgent;

  const CryAnalysisResult({
    required this.category,
    required this.confidence,
    required this.advice,
    required this.urgent,
  });

  factory CryAnalysisResult.fromJson(Map<String, dynamic> json) => CryAnalysisResult(
        category: json['category'] as String? ?? 'غير واضح',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        advice: json['advice'] as String? ?? 'حاول تهدئة الطفل واستشر طبيبًا عند القلق.',
        urgent: json['urgent'] as bool? ?? false,
      );
}
