import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cry_analysis_configuration.dart';
import 'preview_http_client.dart';

class NewbornAssistantService {
  static const configuredEndpoint =
      String.fromEnvironment('BABY_MONITOR_AI_ENDPOINT');

  final String endpoint;
  final Future<String?> Function() accessToken;

  NewbornAssistantService({
    String? endpoint,
    Future<String?> Function()? accessToken,
  })  : endpoint = (endpoint ?? _defaultEndpoint()).trim(),
        accessToken = accessToken ?? CryAnalysisConfiguration.getSessionToken;

  bool get isConfigured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static String _defaultEndpoint() {
    final configured = configuredEndpoint.trim();
    if (configured.isNotEmpty) return configured;
    if (kIsWeb && Uri.base.scheme == 'https') {
      return Uri.base.resolve('/v1/newborn-assistant').toString();
    }
    return '';
  }

  Future<String> ask(String question) async {
    if (!isConfigured) {
      throw const NewbornAssistantException(
        'المساعد الذكي غير متصل بعد. لم يتم إرسال سؤالك.',
      );
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await accessToken();
    if (!kIsWeb && (token == null || token.isEmpty)) {
      throw const NewbornAssistantException(
        'تعذر إنشاء جلسة دخول آمنة للمساعد. لم يُرسل سؤالك.',
      );
    }
    if (token != null && token.isNotEmpty && token != 'web-beta-session') {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await postJson(
          Uri.parse(endpoint),
          headers: headers,
          body: jsonEncode({'question': question.trim()}),
        )
        .timeout(const Duration(seconds: 35));

    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) payload = decoded;
    } on FormatException {
      // Use a local error message below when the server returns non-JSON.
    }

    if (response.statusCode == 429) {
      throw const NewbornAssistantException(
        'وصلنا إلى حد الأسئلة المؤقت. حاولي مرة أخرى بعد قليل.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const NewbornAssistantException(
        'انتهت جلسة الدخول الآمنة للمساعد. أعيدي فتح النسخة التجريبية ثم حاولي مرة أخرى.',
      );
    }
    if (response.statusCode == 400) {
      throw const NewbornAssistantException(
        'السؤال غير صالح. اكتبي سؤالًا عامًا قصيرًا دون بيانات تعريفية.',
      );
    }
    if (response.statusCode == 503) {
      throw const NewbornAssistantException(
        'خدمة المساعد غير جاهزة الآن. لم تكتمل الإجابة؛ حاولي لاحقًا.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const NewbornAssistantException(
        'تعذر الحصول على إجابة الآن. حاولي مرة أخرى لاحقًا.',
      );
    }

    final answer = payload['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const NewbornAssistantException(
        'لم يصل رد صالح من المساعد. حاولي مرة أخرى.',
      );
    }
    return answer.trim();
  }
}

class NewbornAssistantException implements Exception {
  final String message;
  const NewbornAssistantException(this.message);

  @override
  String toString() => message;
}
