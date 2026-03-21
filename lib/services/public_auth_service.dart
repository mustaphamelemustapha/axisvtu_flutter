import '../config.dart';
import 'api_client.dart';

class PublicAuthService {
  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl);

  Future<Map<String, dynamic>> lookupUser(String identifier) async {
    return _client.post('/auth/lookup', {'identifier': identifier});
  }
}
