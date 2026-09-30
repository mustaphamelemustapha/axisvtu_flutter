import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/promo.dart';
import 'api_client.dart';

class PromoService {
  final String token;
  final ApiClient _apiClient;

  PromoService({required this.token})
      : _apiClient = ApiClient(baseUrl: Config.apiBaseUrl, token: token);

  Future<List<UserPromo>> getMyPromos() async {
    final response = await _apiClient.get('/promos/me');
    
    // ApiClient returns a Map. If it was a list, it's wrapped in {'data': [...]}.
    final List<dynamic> data = response is List ? response : (response['data'] ?? []);
    return data.map((json) => UserPromo.fromJson(json)).toList();
  }

  Future<UserPromo> claimPromo(String code) async {
    // ApiClient.post returns the decoded JSON Map and throws ApiException on error.
    final response = await _apiClient.post(
      '/promos/claim',
      {'code': code},
    );

    return UserPromo.fromJson(response);
  }
}

