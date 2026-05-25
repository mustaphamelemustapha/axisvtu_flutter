import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_client.dart';

class ConfigService {
  static Future<Map<String, dynamic>> fetchAppConfig() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/app-config');
      final response = await http.get(url).timeout(const Duration(seconds: 35));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(response.statusCode, 'Failed to load app config');
      }
    } catch (e) {
      // Return a safe default to not break the app entirely if network is down
      // but log it for debugging.
      return {
        "min_app_version": "1.0.0",
        "play_store_url": "https://play.google.com/store/apps",
        "app_store_url": "https://apps.apple.com/us/app"
      };
    }
  }
}
