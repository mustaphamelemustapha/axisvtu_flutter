import 'dart:convert';
import '../models/agent_models.dart';
import '../config.dart';
import 'api_client.dart';

class AgentService {
  AgentService({required this.token});
  
  final String token;
  ApiClient get _apiClient => ApiClient(baseUrl: AppConfig.baseUrl, token: token);

  Future<AgentDashboardStats> getDashboardStats() async {
    final response = await _apiClient.get('/agent/dashboard');
    return AgentDashboardStats.fromJson(response);
  }

  Future<List<RewardCampaign>> getActiveCampaigns() async {
    final response = await _apiClient.get('/agent/campaigns');
    if (response['data'] != null && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((item) => RewardCampaign.fromJson(item)).toList();
    } else if (response is List) {
      // In case the API returns a direct list but decoded as map? Actually ApiClient returns the direct decoded response.
      // Wait, api_client.dart says: `if (data is Map<String, dynamic>) { return data; } return {'data': data};`
      // So if it's a list, it'll be inside `data`
      final List<dynamic> data = response['data'] ?? [];
      return data.map((item) => RewardCampaign.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> claimReward(int campaignId) async {
    final response = await _apiClient.post(
      '/agent/claim-reward',
      {'campaign_id': campaignId},
    );
    return response;
  }
}
