import 'package:http/http.dart' as http;

import 'preview_http_client_stub.dart'
    if (dart.library.html) 'preview_http_client_web.dart' as platform;

Future<http.Response> postJson(
  Uri uri, {
  required Map<String, String> headers,
  required String body,
}) {
  return platform.postJson(uri, headers: headers, body: body);
}

Future<http.Response> sendMultipart(http.MultipartRequest request) {
  return platform.sendMultipart(request);
}
