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

class AdminAgentStat {
  final int id;
  final int agentId;
  final String agentEmail;
  final String agentFullName;
  final double totalDataMb;
  final double totalAirtimeAmount;
  final int totalTransactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminAgentStat({
    required this.id,
    required this.agentId,
    required this.agentEmail,
    required this.agentFullName,
    required this.totalDataMb,
    required this.totalAirtimeAmount,
    required this.totalTransactions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminAgentStat.fromJson(Map<String, dynamic> json) {
    return AdminAgentStat(
      id: json['id'],
      agentId: json['agent_id'],
      agentEmail: json['agent_email'] ?? '',
      agentFullName: json['agent_full_name'] ?? '',
      totalDataMb: (json['total_data_mb'] ?? 0).toDouble(),
      totalAirtimeAmount: (json['total_airtime_amount'] ?? 0).toDouble(),
      totalTransactions: json['total_transactions'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AdminAgentReward {
  final int id;
  final int agentId;
  final String agentEmail;
  final int campaignId;
  final String campaignTitle;
  final double amount;
  final String status;
  final String transactionReference;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminAgentReward({
    required this.id,
    required this.agentId,
    required this.agentEmail,
    required this.campaignId,
    required this.campaignTitle,
    required this.amount,
    required this.status,
    required this.transactionReference,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminAgentReward.fromJson(Map<String, dynamic> json) {
    return AdminAgentReward(
      id: json['id'],
      agentId: json['agent_id'],
      agentEmail: json['agent_email'] ?? '',
      campaignId: json['campaign_id'] ?? 0,
      campaignTitle: json['campaign_title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      transactionReference: json['transaction_reference'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
