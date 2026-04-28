import '../config.dart';
import 'api_client.dart';

class AdminService {
  AdminService({required this.token});

  final String token;

  ApiClient get _client => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  /// Fetch all data plans for administration (unfiltered)
  Future<List<dynamic>> getAllDataPlans() async {
    final data = await _client.get('/admin/data/plans');
    final list = data['data'] ?? data['plans'] ?? data['items'] ?? [];
    return list is List ? list : [];
  }

  /// Update a specific data plan's pricing or visibility
  Future<Map<String, dynamic>> updateDataPlan(String planId, Map<String, dynamic> updates) async {
    return _client.patch('/admin/data/plans/$planId', updates);
  }

  /// Fetch platform-wide margins and service settings
  Future<Map<String, dynamic>> getMargins() async {
    final data = await _client.get('/admin/settings/margins');
    return data['data'] ?? data;
  }

  /// Update platform margins
  Future<Map<String, dynamic>> updateMargins(Map<String, dynamic> margins) async {
    return _client.patch('/admin/settings/margins', margins);
  }
  
  /// Fetch user list for admin management
  Future<List<dynamic>> getUsers({String? query}) async {
    final path = query != null && query.isNotEmpty 
        ? '/admin/users?q=${Uri.encodeComponent(query)}' 
        : '/admin/users';
    final data = await _client.get(path);
    final list = data['data'] ?? data['users'] ?? data['items'] ?? [];
    return list is List ? list : [];
  }
}
