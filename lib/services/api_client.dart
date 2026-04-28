import 'dart:async';
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
    print('API GET: $uri');
    try {
      final resp = await http.get(uri, headers: _headers());
      print('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      print('API ERR [$path]: Timeout - $e');
      throw ApiException(408, 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      print('API ERR [$path]: ClientException - $e');
      throw ApiException(503, 'Network unavailable. Please check your connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      print('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Request failed. Please try again.');
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    print('API POST: $uri');
    try {
      final resp = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      );
      print('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      print('API ERR [$path]: Timeout - $e');
      throw ApiException(408, 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      print('API ERR [$path]: ClientException - $e');
      throw ApiException(503, 'Network unavailable. Please check your connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      print('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Request failed. Please try again.');
    }
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    print('API PATCH: $uri');
    try {
      final resp = await http.patch(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      );
      print('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      print('API ERR [$path]: Timeout - $e');
      throw ApiException(408, 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      print('API ERR [$path]: ClientException - $e');
      throw ApiException(503, 'Network unavailable. Please check your connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      print('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Request failed. Please try again.');
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    print('API DELETE: $uri');
    try {
      final resp = await http.delete(uri, headers: _headers());
      print('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      print('API ERR [$path]: Timeout - $e');
      throw ApiException(408, 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      print('API ERR [$path]: ClientException - $e');
      throw ApiException(503, 'Network unavailable. Please check your connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      print('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Request failed. Please try again.');
    }
  }

  Map<String, dynamic> _decode(http.Response resp, String path) {
    if (resp.body.isNotEmpty && resp.statusCode >= 400) {
      print('API BODY [$path]: ${resp.body}');
    }
    final data = resp.body.isNotEmpty
        ? jsonDecode(resp.body)
        : <String, dynamic>{};
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'data': data};
    }
    final message = data is Map<String, dynamic>
        ? (data['detail'] ?? data['message'] ?? 'Request failed')
        : 'Request failed';
    throw ApiException(resp.statusCode, _formatErrorMessage(message));
  }

  String _formatErrorMessage(Object? message) {
    if (message is String) {
      return message;
    }
    if (message is List) {
      final parts = <String>[];
      for (final item in message) {
        if (item is Map) {
          final loc = item['loc'];
          final field = loc is List && loc.isNotEmpty ? loc.last?.toString() : null;
          final msg = item['msg']?.toString();
          if (field != null && msg != null && msg.isNotEmpty) {
            parts.add('$field: $msg');
          } else if (msg != null && msg.isNotEmpty) {
            parts.add(msg);
          }
        } else if (item != null) {
          parts.add(item.toString());
        }
      }
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }
    return message?.toString() ?? 'Request failed';
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
