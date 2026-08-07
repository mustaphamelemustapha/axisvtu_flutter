import '../config.dart';
import 'api_client.dart';

class ServicesService {
  ServicesService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<Map<String, dynamic>> getCatalog({bool forceRefresh = false}) {
    return _client.get('/services/catalog', forceRefresh: forceRefresh);
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
    String? customerName,
    String? clientRequestId,
  }) {
    return _client.post('/services/cable/purchase', {
      'provider': provider,
      'smartcard_number': smartcardNumber,
      'phone_number': phoneNumber,
      'package_code': packageCode,
      'amount': amount,
      if (customerName != null && customerName.trim().isNotEmpty)
        'customer_name': customerName.trim(),
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }

  Future<Map<String, dynamic>> verifyCable({
    required String provider,
    required String smartcardNumber,
  }) {
    return _client.post('/services/cable/verify', {
      'provider': provider,
      'smartcard_number': smartcardNumber,
    });
  }

  Future<Map<String, dynamic>> getCablePackages({required String provider}) {
    return _client.get('/services/cable/packages?provider=$provider');
  }

  Future<Map<String, dynamic>> verifyElectricity({
    required String disco,
    required String meterType,
    required String meterNumber,
  }) {
    return _client.post('/services/electricity/verify-meter', {
      'disco': disco,
      'meter_type': meterType,
      'meter_number': meterNumber,
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
    String? examType,
    required int quantity,
    String? phoneNumber,
    String? clientRequestId,
  }) {
    return _client.post('/services/exam/purchase', {
      'exam': exam,
      if (examType != null && examType.trim().isNotEmpty) 'exam_type': examType,
      'quantity': quantity,
      'phone_number': (phoneNumber == null || phoneNumber.trim().isEmpty)
          ? null
          : phoneNumber.trim(),
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
    });
  }

  Future<Map<String, dynamic>> getExamPackages({required String exam}) {
    return _client.get('/services/exam/packages?exam=$exam');
  }
}
