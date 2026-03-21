import '../config.dart';
import 'api_client.dart';

class TransactionsService {
  TransactionsService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<List<dynamic>> getTransactions() async {
    final data = await _client.get('/transactions/me');
    final list = data['data'] ?? data['transactions'] ?? data['items'];
    return list is List ? list : [];
  }
}
