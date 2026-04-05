import '../config.dart';
import 'api_client.dart';

class AuthService {
  AuthService({this.token});

  final String? token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return data;
  }

  Future<Map<String, dynamic>> lookupUser(String identifier) async {
    return _client.post('/auth/lookup', {'identifier': identifier});
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone_number': phone.trim(),
      'password': password,
    });
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    return _client.get('/auth/me');
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) {
      body['full_name'] = fullName.trim();
    }
    if (phoneNumber != null) {
      body['phone_number'] = phoneNumber.trim();
    }
    return _client.patch('/auth/me', body);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _client.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> deleteMe() {
    return _client.delete('/auth/delete-me');
  }
}
