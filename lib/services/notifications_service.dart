import '../config.dart';
import 'api_client.dart';

class NotificationsService {
  NotificationsService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<List<dynamic>> getBroadcasts() async {
    final data = await _client.get('/notifications/broadcast');
    final list = data['data'] ?? data['items'] ?? data['notifications'];
    return list is List ? list : [];
  }
}
