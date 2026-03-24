import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;
  static const Duration _cacheTtl = Duration(minutes: 10);
  static List<dynamic> _cachedPlans = [];
  static DateTime? _cacheAt;

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
    final plans = list is List ? list : [];
    _cachedPlans = plans;
    _cacheAt = DateTime.now();
    return plans;
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
