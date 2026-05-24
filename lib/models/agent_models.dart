class AgentDashboardStats {
  final double walletBalance;
  final double todayDataGb;
  final double todayAirtime;
  final double monthDataGb;
  final double monthAirtime;
  final int totalTransactions;
  final String agentStatus;
  final String performanceSummary;

  AgentDashboardStats({
    required this.walletBalance,
    required this.todayDataGb,
    required this.todayAirtime,
    required this.monthDataGb,
    required this.monthAirtime,
    required this.totalTransactions,
    required this.agentStatus,
    required this.performanceSummary,
  });

  factory AgentDashboardStats.fromJson(Map<String, dynamic> json) {
    return AgentDashboardStats(
      walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
      todayDataGb: (json['today_data_gb'] ?? 0).toDouble(),
      todayAirtime: (json['today_airtime'] ?? 0).toDouble(),
      monthDataGb: (json['month_data_gb'] ?? 0).toDouble(),
      monthAirtime: (json['month_airtime'] ?? 0).toDouble(),
      totalTransactions: json['total_transactions'] ?? 0,
      agentStatus: json['agent_status'] ?? '',
      performanceSummary: json['performance_summary'] ?? '',
    );
  }
}

class RewardCampaign {
  final int id;
  final String title;
  final String campaignType;
  final String targetMetric;
  final double targetValue;
  final double rewardAmount;
  final bool isActive;
  final double progressValue;
  final bool isQualified;

  RewardCampaign({
    required this.id,
    required this.title,
    required this.campaignType,
    required this.targetMetric,
    required this.targetValue,
    required this.rewardAmount,
    required this.isActive,
    required this.progressValue,
    required this.isQualified,
  });

  factory RewardCampaign.fromJson(Map<String, dynamic> json) {
    return RewardCampaign(
      id: json['id'],
      title: json['title'] ?? '',
      campaignType: json['campaign_type'] ?? '',
      targetMetric: json['target_metric'] ?? '',
      targetValue: (json['target_value'] ?? 0).toDouble(),
      rewardAmount: (json['reward_amount'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? false,
      progressValue: (json['progress_value'] ?? 0).toDouble(),
      isQualified: json['is_qualified'] ?? false,
    );
  }
}
