import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;
  static const Duration _cacheTtl = Duration(seconds: 30); // Reduced from 10 mins to 30s to stay closer to live data
  static List<dynamic> _cachedPlans = [];
  static DateTime? _cacheAt;
  static const String _prefsKey = 'axis_data_plans_cache_v1';
  static const int _maxPerNetwork = 8;
  static const List<String> _blockKeywords = <String>[
    'night',
    'social',
    'weekend',
    'daily',
    'awoof',
    'bonus',
    'router',
    'mifi',
    'youtube',
    'unlimited',
  ];
  static const Set<String> _airtelVisibleCapacities = <String>{
    '2GB',
    '3GB',
    '4GB',
    '8GB',
    '10GB',
    '13GB',
    '18GB',
    '25GB',
  };

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

  List<dynamic> _curatePlans(List<dynamic> rows) {
    if (rows.isEmpty) return <dynamic>[];
    final grouped = <String, List<dynamic>>{};
    for (final item in rows) {
      if (item is! Map) continue;
      final normalized = _normalizePlan(item);
      final network = (normalized['network'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final key = network.isEmpty ? 'unknown' : network;
      grouped.putIfAbsent(key, () => <dynamic>[]).add(normalized);
    }

    final curated = <dynamic>[];
    grouped.forEach((networkKey, networkPlans) {
      final clean = networkPlans.where((plan) => !_isNoisyPlan(plan)).toList();
      List<dynamic> source;
      if (networkKey == 'airtel') {
        source = _filterAirtelPlans(clean.isNotEmpty ? clean : networkPlans);
        if (source.isEmpty) return;
      } else {
        source = clean.length >= 4 ? clean : networkPlans;
        if (source.isEmpty) return;
      }
      source.sort((a, b) => _planPrice(a).compareTo(_planPrice(b)));
      curated.addAll(source.take(_maxPerNetwork));
    });
    return curated;
  }

  List<dynamic> _filterAirtelPlans(List<dynamic> plans) {
    return plans.where((plan) {
      if (plan is! Map) return false;
      final network = (plan['network'] ?? '').toString().trim().toLowerCase();
      if (network != 'airtel') return true;
      final capacity = _capacityKey(plan['data_size'] ?? plan['plan_name']);
      if (!_airtelVisibleCapacities.contains(capacity)) return false;
      final validity = _validityDays(plan['validity'] ?? plan['plan_name']);
      return validity == 30;
    }).toList();
  }

  bool _isNoisyPlan(dynamic plan) {
    if (plan is! Map) return false;
    final label =
        '${plan['plan_name'] ?? ''} ${plan['data_size'] ?? ''} ${plan['validity'] ?? ''}'
            .toLowerCase();
    if (_blockKeywords.any((keyword) => label.contains(keyword))) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> _normalizePlan(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    map['plan_name'] = _sanitizePlanText(map['plan_name']);
    map['data_size'] = _sanitizePlanText(map['data_size']);
    return map;
  }

  String _capacityKey(dynamic value) {
    final text = (value ?? '').toString().toUpperCase().replaceAll(' ', '');
    if (text.isEmpty) return '';
    if (text.contains('GB') || text.contains('MB')) {
      final match = RegExp(r'(\d+(?:\.\d+)?)(GB|MB)').firstMatch(text);
      if (match != null) {
        return '${match.group(1)}${match.group(2)}';
      }
    }
    return text;
  }

  int? _validityDays(dynamic value) {
    final text = (value ?? '').toString().toLowerCase();
    if (text.isEmpty) return null;
    final match = RegExp(r'(\d+)\s*(d|day|days|month|months|week|weeks)').firstMatch(text);
    if (match == null) return null;
    final amount = int.tryParse(match.group(1) ?? '');
    if (amount == null) return null;
    final unit = match.group(2) ?? '';
    if (unit.startsWith('month')) return amount * 30;
    if (unit.startsWith('week')) return amount * 7;
    return amount;
  }

  String _sanitizePlanText(dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return '';
    return text
        .replaceAll(
          RegExp(r'\(\s*direct\s+data\s*\)', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\bdirect\s+data\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^\-\s*'), '')
        .replaceAll(RegExp(r'\s*\-$'), '')
        .trim();
  }

  num _planPrice(dynamic plan) {
    if (plan is! Map) return 1e15;
    final value = num.tryParse('${plan['price'] ?? ''}');
    return value ?? 1e15;
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
