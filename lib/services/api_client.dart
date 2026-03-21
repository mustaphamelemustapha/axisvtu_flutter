import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.get(uri, headers: _headers());
    return _decode(resp);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    return _decode(resp);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.patch(uri, headers: _headers(), body: jsonEncode(body));
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final data = resp.body.isNotEmpty ? jsonDecode(resp.body) : <String, dynamic>{};
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'data': data};
    }
    final message = data is Map<String, dynamic>
        ? (data['detail'] ?? data['message'] ?? 'Request failed')
        : 'Request failed';
    throw ApiException(resp.statusCode, message.toString());
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
