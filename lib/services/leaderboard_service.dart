import '../config.dart';
import 'api_client.dart';

class LeaderboardService {
  final String? token;

  LeaderboardService({this.token});

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getLeaderboard() async {
    return _client.get('/leaderboard/');
  }
}
