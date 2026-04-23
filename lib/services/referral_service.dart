import '../config.dart';
import 'api_client.dart';

class ReferralService {
  ReferralService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getMe() async {
    return _client.get('/referrals/me');
  }
}
