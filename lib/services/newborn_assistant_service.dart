import 'dart:convert';

import 'package:http/http.dart' as http;

class NewbornAssistantService {
  static const configuredEndpoint =
      String.fromEnvironment('BABY_MONITOR_AI_ENDPOINT');

  final String endpoint;

  const NewbornAssistantService({this.endpoint = configuredEndpoint});

  bool get isConfigured => endpoint.startsWith('https://');

  Future<String> ask(String question) async {
    if (!isConfigured) {
      throw const NewbornAssistantException(
        'المساعد الذكي غير متصل بعد. لم يتم إرسال سؤالك.',
      );
    }

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: const {'Content-Type': 'application/json'},
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NewbornAssistantException(
        (payload['error'] as String?) ??
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
