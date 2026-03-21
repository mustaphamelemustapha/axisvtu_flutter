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
}
