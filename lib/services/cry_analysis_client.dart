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
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const CryAnalysisException('انتهت جلسة الدخول. سجّل الدخول وحاول مرة أخرى.');
    }

    final request = http.MultipartRequest('POST', endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('audio', audio.path));

    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CryAnalysisException('تعذر تحليل التسجيل (${response.statusCode}).');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return CryAnalysisResult.fromJson(json);
  }
}

class CryAnalysisException implements Exception {
  final String message;
  const CryAnalysisException(this.message);
  @override String toString() => message;
}
