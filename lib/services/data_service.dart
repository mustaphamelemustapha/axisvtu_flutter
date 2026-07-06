import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  static void clearCache() {
  }

  Future<List<dynamic>> getPlans({bool forceRefresh = false}) async {
    return await _fetchAndCache(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _fetchAndCache({bool forceRefresh = false}) async {
    try {
      final data = await _client.get('/data/plans', forceRefresh: forceRefresh);
      final list = _extractList(data);
      return list ?? <dynamic>[];
    } catch (e) {
      rethrow;
    }
  }

  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final rawList = data['data'] ?? data['plans'] ?? data['items'] ?? data['results'];
      if (rawList is List) return rawList;
    }
    return null;
  }

  Future<Map<String, dynamic>> purchase({
    required String planCode,
    required String phoneNumber,
    required bool ported,
    String? clientRequestId,
  }) async {
    return _client.post('/data/purchase', {
      'plan_code': planCode,
      'phone_number': phoneNumber,
      'ported_number': ported,
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }
}
