import '../config.dart';
import 'api_client.dart';

class UserLookupService {
  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl);

  Future<Map<String, dynamic>> lookup(String identifier) async {
    return _client.post('/auth/lookup', {'identifier': identifier});
  }
}
