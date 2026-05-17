import '../config.dart';
import 'api_client.dart';

class WalletService {
  WalletService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getWallet() async {
    return _client.get('/wallet/me');
  }

  Future<Map<String, dynamic>> getBankAccounts() async {
    return _client.get('/wallet/bank-transfer-accounts');
  }

  Future<Map<String, dynamic>> createBankAccounts({
    String? phoneNumber,
    String? bvn,
    String? nin,
  }) async {
    final body = <String, dynamic>{};
    final phone = (phoneNumber ?? '').trim();
    if (phone.isNotEmpty) {
      body['phone_number'] = phone;
    }
    final bvnVal = (bvn ?? '').trim();
    if (bvnVal.isNotEmpty) {
      body['bvn'] = bvnVal;
    }
    final ninVal = (nin ?? '').trim();
    if (ninVal.isNotEmpty) {
      body['nin'] = ninVal;
    }
    return _client.post('/wallet/bank-transfer-accounts', body);
  }
}
