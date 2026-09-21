import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/cry_analysis_result.dart';

/// Client for the protected backend. Never put the model/API secret in Flutter.
class CryAnalysisClient {
  final Uri endpoint;
  final Future<String?> Function() accessToken;

  const CryAnalysisClient({required this.endpoint, required this.accessToken});

  Future<CryAnalysisResult> analyze(File audio) async {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty) {
      throw const CryAnalysisException(
        'تعذر إرسال التسجيل بأمان. لم يتم رفع الصوت.',
      );
    }

    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const CryAnalysisException(
        'انتهت جلسة الدخول. سجّل الدخول وحاول مرة أخرى.',
      );
    }

    final request = http.MultipartRequest('POST', endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('audio', audio.path));

    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream
        .bytesToString()
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CryAnalysisException(
        'تعذر تحليل التسجيل (${response.statusCode}).',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const CryAnalysisException('استجابة التحليل غير صالحة.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CryAnalysisException('استجابة التحليل غير صالحة.');
    }

    final category = decoded['category'];
    final confidence = decoded['confidence'];
    final advice = decoded['advice'];
    final urgent = decoded['urgent'];
    if (category is! String ||
        category.trim().isEmpty ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        advice is! String ||
        advice.trim().isEmpty ||
        urgent is! bool) {
      throw const CryAnalysisException('استجابة التحليل غير صالحة.');
    }

    return CryAnalysisResult(
      category: category.trim(),
      confidence: confidence.toDouble(),
      advice: advice.trim(),
      urgent: urgent,
    );
  }
}

class CryAnalysisException implements Exception {
  final String message;
  const CryAnalysisException(this.message);
  @override String toString() => message;
}
