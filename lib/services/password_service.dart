import '../config.dart';
import 'api_client.dart';

class PasswordService {
  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl);

  Future<Map<String, dynamic>> requestReset(String email) async {
    return _client.post('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return _client.post('/auth/reset-password', {
      'token': token,
      'new_password': newPassword,
    });
  }
}
