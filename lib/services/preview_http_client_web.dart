import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

Future<http.Response> postJson(
  Uri uri, {
  required Map<String, String> headers,
  required String body,
}) async {
  final client = BrowserClient()..withCredentials = true;
  try {
    return await client.post(uri, headers: headers, body: body);
  } finally {
    client.close();
  }
}

Future<http.Response> sendMultipart(http.MultipartRequest request) async {
  final client = BrowserClient()..withCredentials = true;
  try {
    final response = await client.send(request);
    return http.Response.fromStream(response);
  } finally {
    client.close();
  }
}
