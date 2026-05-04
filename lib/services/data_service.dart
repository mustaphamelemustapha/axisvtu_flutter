import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;
  static const Duration _cacheTtl = Duration(minutes: 2);
  static List<dynamic> _cachedPlans = [];
  static DateTime? _cacheAt;
  static const String _prefsKey = 'axis_data_plans_cache_v1';

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  static bool get hasCache => _cachedPlans.isNotEmpty;

  static bool get isCacheFresh =>
      _cacheAt != null && DateTime.now().difference(_cacheAt!) < _cacheTtl;

  static List<dynamic> get cachedPlans => List<dynamic>.from(_cachedPlans);

  static void clearCache() {
    _cachedPlans = [];
    _cacheAt = null;
  }

  Future<List<dynamic>> getPlans({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // Serve from fresh in-memory cache immediately.
      if (_cachedPlans.isNotEmpty && isCacheFresh) {
        return cachedPlans;
      }

      // In-memory cache is stale or empty — always fetch live data.
      // But if we have any cached data (memory or disk), show it instantly
      // while refreshing in the background.
      if (_cachedPlans.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final str = prefs.getString(_prefsKey);
          if (str != null) {
            final decoded = jsonDecode(str);
            if (decoded is List) {
              _cachedPlans = decoded;
            }
          }
        } catch (_) {}
      }

      if (_cachedPlans.isNotEmpty) {
        // Kick off a background refresh so we converge on live data quickly.
        _fetchAndCache();
        return cachedPlans;
      }
    }
    return await _fetchAndCache();
  }

  Future<List<dynamic>> _fetchAndCache() async {
    try {
      final data = await _client.get('/data/plans');
      final list = data['data'] ?? data['plans'] ?? data['items'];
      final plans = list is List ? List<dynamic>.from(list) : <dynamic>[];
      _cachedPlans = plans;
      _cacheAt = DateTime.now();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(plans));
      } catch (_) {}

      return plans;
    } catch (e) {
      if (_cachedPlans.isNotEmpty) return _cachedPlans;
      rethrow;
    }
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
