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

  /// Fetch all broadcast announcements for admin management
  Future<List<dynamic>> getAdminAnnouncements() async {
    final data = await _client.get('/notifications/broadcast/admin');
    final list = data['data'] ?? data['items'] ?? [];
    return list is List ? list : [];
  }

  /// Create a new broadcast announcement
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String message,
    required String level,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? buttonLabel,
    String? buttonLink,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'message': message,
      'level': level,
      'is_active': isActive,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'button_label': buttonLabel,
      'button_link': buttonLink,
    };
    return _client.post('/notifications/broadcast/admin', body);
  }

  /// Update an existing broadcast announcement
  Future<Map<String, dynamic>> updateAnnouncement(
    int id, {
    String? title,
    String? message,
    String? level,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? buttonLabel,
    String? buttonLink,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (message != null) body['message'] = message;
    if (level != null) body['level'] = level;
    if (isActive != null) body['is_active'] = isActive;
    if (startsAt != null) body['starts_at'] = startsAt.toUtc().toIso8601String();
    if (endsAt != null) body['ends_at'] = endsAt.toUtc().toIso8601String();
    if (buttonLabel != null) body['button_label'] = buttonLabel;
    if (buttonLink != null) body['button_link'] = buttonLink;
    return _client.patch('/notifications/broadcast/admin/$id', body);
  }

  /// List all reward campaigns
  Future<Map<String, dynamic>> listCampaigns({int page = 1, int pageSize = 50}) async {
    return _client.get('/admin/agent/campaigns?page=$page&page_size=$pageSize');
  }

  /// Create a new reward campaign
  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> campaignData) async {
    return _client.post('/admin/agent/campaigns', campaignData);
  }

  /// Update an existing reward campaign
  Future<Map<String, dynamic>> updateCampaign(int campaignId, Map<String, dynamic> updates) async {
    return _client.put('/admin/agent/campaigns/$campaignId', updates);
  }

  /// Delete or deactivate a reward campaign
  Future<Map<String, dynamic>> deleteCampaign(int campaignId) async {
    return _client.delete('/admin/agent/campaigns/$campaignId');
  }

  /// List agent stats (optionally search/filter using query `q`)
  Future<Map<String, dynamic>> listAgentStats({String? query, int page = 1, int pageSize = 50}) async {
    final qParam = query != null && query.isNotEmpty ? '&q=${Uri.encodeComponent(query)}' : '';
    return _client.get('/admin/agent/stats?page=$page&page_size=$pageSize$qParam');
  }

  /// Override an agent's stats
  Future<Map<String, dynamic>> overrideAgentStats(int agentId, Map<String, dynamic> stats) async {
    return _client.post('/admin/agent/stats/$agentId/override', stats);
  }

  /// Fetch an agent's rewards list
  Future<Map<String, dynamic>> getAgentRewards(int agentId, {int page = 1, int pageSize = 50}) async {
    return _client.get('/admin/agent/stats/$agentId/rewards?page=$page&page_size=$pageSize');
  }

  /// Award a manual reward to an agent
  Future<Map<String, dynamic>> manualRewardAgent(int agentId, {int? campaignId, double? amount, required String reason}) async {
    final body = <String, dynamic>{
      'reason': reason,
    };
    if (campaignId != null) body['campaign_id'] = campaignId;
    if (amount != null) body['amount'] = amount;
    return _client.post('/admin/agent/stats/$agentId/manual-reward', body);
  }
}

