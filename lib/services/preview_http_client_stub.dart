import 'package:http/http.dart' as http;

Future<http.Response> postJson(
  Uri uri, {
  required Map<String, String> headers,
  required String body,
}) {
  return http.post(uri, headers: headers, body: body);
}

Future<http.Response> sendMultipart(http.MultipartRequest request) async {
  final response = await request.send();
  return http.Response.fromStream(response);
}
