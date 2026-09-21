import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/cry_analysis_result.dart';

/// Client for the experimental preview API. Never put a service secret in Flutter.
class CryAnalysisClient {
  final Uri endpoint;
  final Future<String?> Function() accessToken;

  const CryAnalysisClient({required this.endpoint, required this.accessToken});

  Future<CryAnalysisResult> analyze(Uint8List audioBytes) async {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty) {
      throw const CryAnalysisException(
        'تعذر إرسال التسجيل بأمان. لم يتم رفع الصوت.',
      );
    }
    if (audioBytes.isEmpty || audioBytes.length > 400000) {
      throw const CryAnalysisException('مدة التسجيل أو حجمه غير صالح للتحليل.');
    }

    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const CryAnalysisException(
        'تعذر الحصول على جلسة دخول آمنة. لم يكتمل التحليل.',
      );
    }

    final request = http.MultipartRequest('POST', endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'cry-recording.wav',
        ),
      );

    final response = await request.send().timeout(const Duration(seconds: 90));
    final body = await response.stream
        .bytesToString()
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CryAnalysisException(_messageForStatus(response.statusCode));
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
    final advice = decoded['advice'];
    final urgent = decoded['urgent'];
    final experimental = decoded['experimental'];
    const categories = {
      'hungry',
      'belly_pain',
      'burping',
      'discomfort',
      'tiredness',
      'unclear',
    };
    if (category is! String ||
        !categories.contains(category) ||
        advice is! String ||
        advice.trim().isEmpty ||
        urgent is! bool ||
        experimental != true) {
      throw const CryAnalysisException('استجابة التحليل غير صالحة.');
    }

    return CryAnalysisResult(
      category: category,
      advice: advice.trim(),
      urgent: urgent,
      experimental: true,
    );
  }

  String _messageForStatus(int status) {
    switch (status) {
      case 400:
      case 413:
      case 415:
        return 'التسجيل غير صالح للتحليل. حُذف من ذاكرة التطبيق.';
      case 401:
      case 403:
        return 'انتهت جلسة الدخول الآمنة. أعيدي المحاولة.';
      case 429:
        return 'وصلت خدمة التجربة إلى حد الاستخدام المؤقت.';
      case 503:
        return 'خدمة التحليل التجريبية غير جاهزة الآن.';
      default:
        return 'تعذر إكمال التحليل (${status}).';
    }
  }
}

class CryAnalysisException implements Exception {
  final String message;
  const CryAnalysisException(this.message);

  @override
  String toString() => message;
}
