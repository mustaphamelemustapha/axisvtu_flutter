import '../config.dart';
import 'api_client.dart';

class PasswordService {
  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl);

  Future<Map<String, dynamic>> requestReset(String identifier) async {
    return _client.post('/auth/forgot-password', {'identifier': identifier});
  }

  Future<Map<String, dynamic>> verifyResetToken({
    required String identifier,
    required String otp,
  }) async {
    return _client.post('/auth/verify-reset-token', {
      'identifier': identifier,
      'otp': otp,
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    return _client.post('/auth/reset-password', {
      'identifier': identifier,
      'otp': otp,
      'new_password': newPassword,
    });
  }
}
