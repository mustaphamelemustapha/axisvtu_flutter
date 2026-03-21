import '../config.dart';
import 'api_client.dart';

class DataService {
  DataService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<List<dynamic>> getPlans() async {
    final data = await _client.get('/data/plans');
    final list = data['data'] ?? data['plans'] ?? data['items'];
    return list is List ? list : [];
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
