import '../config.dart';
import 'api_client.dart';

class ServicesService {
  ServicesService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getCatalog() {
    return _client.get('/services/catalog');
  }

  Future<Map<String, dynamic>> purchaseAirtime({
    required String network,
    required String phoneNumber,
    required double amount,
    String? clientRequestId,
  }) {
    return _client.post('/services/airtime/purchase', {
      'network': network,
      'phone_number': phoneNumber,
      'amount': amount,
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }

  Future<Map<String, dynamic>> purchaseCable({
    required String provider,
    required String smartcardNumber,
    required String phoneNumber,
    required String packageCode,
    required double amount,
    String? clientRequestId,
  }) {
    return _client.post('/services/cable/purchase', {
      'provider': provider,
      'smartcard_number': smartcardNumber,
      'phone_number': phoneNumber,
      'package_code': packageCode,
      'amount': amount,
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }

  Future<Map<String, dynamic>> purchaseElectricity({
    required String disco,
    required String meterType,
    required String meterNumber,
    required String phoneNumber,
    required double amount,
    String? clientRequestId,
  }) {
    return _client.post('/services/electricity/purchase', {
      'disco': disco,
      'meter_type': meterType,
      'meter_number': meterNumber,
      'phone_number': phoneNumber,
      'amount': amount,
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }

  Future<Map<String, dynamic>> purchaseExam({
    required String exam,
    required int quantity,
    String? phoneNumber,
    String? clientRequestId,
  }) {
    return _client.post('/services/exam/purchase', {
      'exam': exam,
      'quantity': quantity,
      'phone_number': (phoneNumber == null || phoneNumber.trim().isEmpty)
          ? null
          : phoneNumber.trim(),
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }
}
