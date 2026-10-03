import '../config.dart';
import 'api_client.dart';

class PasswordService {
  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl);

  Future<Map<String, dynamic>> requestReset(String phoneNumber) async {
    return _client.post('/auth/forgot-password', {'phone_number': phoneNumber});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String phoneNumber,
    required String otp,
    required String newPassword,
  }) async {
    return _client.post('/auth/reset-password', {
      'phone_number': phoneNumber,
      'otp': otp,
      'new_password': newPassword,
    });
  }
}
