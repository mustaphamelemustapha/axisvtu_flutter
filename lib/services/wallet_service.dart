import '../config.dart';
import 'api_client.dart';

class WalletService {
  WalletService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getWallet({bool forceRefresh = false}) async {
    return _client.get('/wallet/me', forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> getBankAccounts({bool forceRefresh = false}) async {
    return _client.get('/wallet/bank-transfer-accounts', forceRefresh: forceRefresh);
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
    try {
      return await _client.post('/wallet/bank-transfer-accounts', body);
    } catch (e) {
      if (e is ApiException && e.statusCode == 405) {
        return await _client.post('/wallet/monnify/reserved-account', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyTransferRecipient(String identifier) async {
    return _client.post('/wallet/transfer/verify', {
      'identifier': identifier,
    });
  }

  Future<Map<String, dynamic>> performTransfer(String identifier, String amount) async {
    return _client.post('/wallet/transfer', {
      'identifier': identifier,
      'amount': amount,
    });
  }

  Future<List<dynamic>> getBanks() async {
    final res = await _client.get('/wallet/banks');
    if (res['data'] is List) return res['data'] as List;
    return [];
  }

  Future<Map<String, dynamic>> resolveBankAccount(String accountNumber, String bankCode) async {
    return _client.post('/wallet/resolve-bank-account', {
      'account_number': accountNumber,
      'bank_code': bankCode,
    });
  }

  Future<Map<String, dynamic>> withdrawToBank({
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String accountName,
    required double amount,
    required String pin,
    String? narration,
  }) async {
    return _client.post('/wallet/withdraw', {
      'account_number': accountNumber,
      'bank_code': bankCode,
      'bank_name': bankName,
      'account_name': accountName,
      'amount': amount,
      'pin': pin,
      if (narration != null && narration.isNotEmpty) 'narration': narration,
    });
  }
}
