import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/promo.dart';
import 'api_client.dart';

class PromoService {
  final ApiClient _apiClient = ApiClient();

  Future<List<UserPromo>> getMyPromos() async {
    final response = await _apiClient.get('/promos/me');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => UserPromo.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load promos');
    }
  }

  Future<UserPromo> claimPromo(String code) async {
    final response = await _apiClient.post(
      '/promos/claim',
      body: {'code': code},
    );

    if (response.statusCode == 200) {
      return UserPromo.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to claim promo code');
    }
  }
}
