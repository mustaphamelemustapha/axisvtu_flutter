import '../config.dart';
import 'api_client.dart';

class TransactionPinStatus {
  TransactionPinStatus({
    required this.isSet,
    required this.isLocked,
    required this.failedAttempts,
    required this.maxAttempts,
    required this.pinLength,
    this.lockedUntil,
  });

  final bool isSet;
  final bool isLocked;
  final DateTime? lockedUntil;
  final int failedAttempts;
  final int maxAttempts;
  final int pinLength;

  factory TransactionPinStatus.fromJson(Map<String, dynamic> data) {
    return TransactionPinStatus(
      isSet: data['is_set'] == true,
      isLocked: data['is_locked'] == true,
      lockedUntil: DateTime.tryParse((data['locked_until'] ?? '').toString()),
      failedAttempts: (data['failed_attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (data['max_attempts'] as num?)?.toInt() ?? 5,
      pinLength: (data['pin_length'] as num?)?.toInt() ?? 4,
    );
  }
}

class TransactionPinService {
  TransactionPinService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<TransactionPinStatus> status() async {
    final data = await _client.get('/security/pin/status');
    return TransactionPinStatus.fromJson(data);
  }

  Future<TransactionPinStatus?> statusOrNull() async {
    try {
      return await status();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> setup({
    required String pin,
    required String confirmPin,
  }) async {
    await _client.post('/security/pin/setup', {
      'pin': pin,
      'confirm_pin': confirmPin,
    });
  }

  Future<void> verify(String pin) async {
    await _client.post('/security/pin/verify', {'pin': pin});
  }

  Future<void> change({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    await _client.post('/security/pin/change', {
      'current_pin': currentPin,
      'new_pin': newPin,
      'confirm_pin': confirmPin,
    });
  }

  Future<void> requestReset() async {
    await _client.post('/security/pin/reset-request', const <String, dynamic>{});
  }

  Future<bool> isResetTokenValid(String token) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/security/pin/reset-token')
        .replace(queryParameters: {'token': token});
    final data = await _client.get(uri.path + '?${uri.query}');
    return data['is_valid'] == true;
  }

  Future<void> confirmReset({
    required String token,
    required String newPin,
    required String confirmPin,
  }) async {
    await _client.post('/security/pin/reset-confirm', {
      'token': token,
      'new_pin': newPin,
      'confirm_pin': confirmPin,
    });
  }
}
