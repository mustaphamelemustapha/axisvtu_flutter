import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;
  static const Duration _timeout = Duration(seconds: 60);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

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
    _log('API GET: $uri');
    try {
      final resp = await http.get(uri, headers: _headers()).timeout(_timeout);
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    _log('API POST: $uri');
    try {
      final resp = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    _log('API PUT: $uri');
    try {
      final resp = await http
          .put(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    _log('API PATCH: $uri');
    try {
      final resp = await http
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    _log('API DELETE: $uri');
    try {
      final resp = await http
          .delete(uri, headers: _headers())
          .timeout(_timeout);
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required File file,
    required String fileField,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    _log('API POST MULTIPART: $uri');
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(json: false));
      
      // Determine extension from file or default to jpg
      final ext = file.path.split('.').last.toLowerCase();
      final subtype = (ext == 'png') ? 'png' : ((ext == 'gif') ? 'gif' : 'jpeg');

      request.files.add(
        await http.MultipartFile.fromPath(
          fileField, 
          file.path,
          contentType: MediaType('image', subtype),
        )
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final resp = await http.Response.fromStream(streamedResponse);
      
      _log('API RESP [$path]: ${resp.statusCode}');
      return _decode(resp, path);
    } on TimeoutException catch (e) {
      _log('API ERR [$path]: Timeout - $e');
      throw ApiException(
        408,
        'Request timed out. The server is taking too long to respond.',
      );
    } on SocketException catch (e) {
      _log('API ERR [$path]: SocketException - $e');
      throw ApiException(
        503,
        'Unable to connect. Check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      _log('API ERR [$path]: ClientException - $e');
      throw ApiException(
        503,
        'Unable to reach server right now. Please try again shortly.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('API ERR [$path]: Unexpected - $e');
      throw ApiException(500, 'Unexpected error. Please try again.');
    }
  }

  Map<String, dynamic> _decode(http.Response resp, String path) {
    if (resp.body.isNotEmpty && resp.statusCode >= 400) {
      _log('API BODY [$path]: ${resp.body}');
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
        ? (data['detail'] ??
              data['message'] ??
              data['error'] ??
              'Request failed')
        : 'Request failed';
    throw ApiException(
      resp.statusCode,
      _friendlyMessage(resp.statusCode, _formatErrorMessage(message)),
    );
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
          final field = loc is List && loc.isNotEmpty
              ? loc.last?.toString()
              : null;
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
    return _sanitizeUserMessage(message?.toString() ?? 'Request failed');
  }

  String _friendlyMessage(int statusCode, String message) {
    final normalized = _sanitizeUserMessage(message).trim();
    if (normalized.isNotEmpty &&
        !normalized.toLowerCase().contains('request failed')) {
      return normalized;
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please review your input and try again.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You are not allowed to perform this action.';
      case 404:
        return 'Service endpoint not found. Please try again shortly.';
      case 408:
        return 'Request timed out. Please try again.';
      case 409:
        return 'This request is already being processed. Please wait.';
      case 422:
        return 'Invalid request details. Please check your input.';
      case 429:
        return 'Too many requests right now. Please wait a moment and retry.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server temporarily unavailable. Please try again shortly.';
      default:
        return normalized.isEmpty
            ? 'Unable to complete request. Please try again.'
            : normalized;
    }
  }

  String _sanitizeUserMessage(String input) {
    var text = input;
    // Hide provider/internal debug flags from end users.
    text = text.replaceAll(
      RegExp(r'AMIGO_TEST_MODE\s*=\s*true', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'temporarily', caseSensitive: false),
      'right now',
    );
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (text.isEmpty) return 'Unable to complete request. Please try again.';
    return text;
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
