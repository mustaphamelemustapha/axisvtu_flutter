import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;
  static const Duration _cacheTtl = Duration(minutes: 10);
  static List<dynamic> _cachedPlans = [];
  static DateTime? _cacheAt;
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

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  static bool get hasCache => _cachedPlans.isNotEmpty;

  static bool get isCacheFresh =>
      _cacheAt != null && DateTime.now().difference(_cacheAt!) < _cacheTtl;

  static List<dynamic> get cachedPlans => List<dynamic>.from(_cachedPlans);

  Future<List<dynamic>> getPlans({bool forceRefresh = false}) async {
    if (!forceRefresh && hasCache && isCacheFresh) {
      return cachedPlans;
    }
    final data = await _client.get('/data/plans');
    final list = data['data'] ?? data['plans'] ?? data['items'];
    final plans = list is List ? _curatePlans(list) : <dynamic>[];
    _cachedPlans = plans;
    _cacheAt = DateTime.now();
    return plans;
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
    grouped.forEach((_, networkPlans) {
      final clean = networkPlans.where((plan) => !_isNoisyPlan(plan)).toList();
      final source = clean.length >= 4 ? clean : networkPlans;
      source.sort((a, b) => _planPrice(a).compareTo(_planPrice(b)));
      curated.addAll(source.take(_maxPerNetwork));
    });
    return curated;
  }

  bool _isNoisyPlan(dynamic plan) {
    if (plan is! Map) return false;
    final label =
        '${plan['plan_name'] ?? ''} ${plan['data_size'] ?? ''} ${plan['validity'] ?? ''}'
            .toLowerCase();
    if (_blockKeywords.any((keyword) => label.contains(keyword))) {
      return true;
    }
    final days = _validityDays(plan);
    if (days != null && days < 7) return true;
    return false;
  }

  Map<String, dynamic> _normalizePlan(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    map['plan_name'] = _sanitizePlanText(map['plan_name']);
    map['data_size'] = _sanitizePlanText(map['data_size']);
    return map;
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

  int? _validityDays(dynamic plan) {
    if (plan is! Map) return null;
    final raw = '${plan['validity'] ?? plan['plan_name'] ?? ''}'.toLowerCase();
    final match = RegExp(
      r'(\d+)\s*(day|days|month|months|week|weeks|d)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;
    final amount = int.tryParse(match.group(1) ?? '');
    if (amount == null) return null;
    final unit = (match.group(2) ?? '').toLowerCase();
    if (unit.startsWith('month')) return amount * 30;
    if (unit.startsWith('week')) return amount * 7;
    return amount;
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
  }) async {
    return _client.post('/data/purchase', {
      'plan_code': planCode,
      'phone_number': phoneNumber,
      'ported_number': ported,
    });
  }
}
