import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/agent_service.dart';
import '../models/agent_models.dart';
import '../state/session.dart';
import 'referral_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> with SingleTickerProviderStateMixin {
  AgentService? _agentService;
  late TabController _tabController;
  
  bool _isLoading = true;
  String _error = '';
  AgentDashboardStats? _stats;
  List<RewardCampaign> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_agentService == null) {
      final token = context.read<SessionController>().token ?? '';
      _agentService = AgentService(token: token);
      _fetchData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      if (_agentService == null) return;
      
      // Parallelize both API requests to double loading speed
      final results = await Future.wait([
        _agentService!.getDashboardStats(),
        _agentService!.getActiveCampaigns(),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as AgentDashboardStats;
          _campaigns = results[1] as List<RewardCampaign>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimReward(RewardCampaign campaign) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claiming reward...')),
      );
      
      if (_agentService == null) return;
      final result = await _agentService!.claimReward(campaign.id);
      
      if (mounted) {
        _fetchData();
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You have successfully claimed your reward for "${campaign.title}".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${campaign.rewardAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'It has been credited to your wallet.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Agent Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReferralScreen()),
            ),
            tooltip: 'Referrals',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: textPrimary,
          unselectedLabelColor: textSecondary,
          isScrollable: false,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Offers'),
          ],
        ),
      ),
      body: _isLoading
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildSkeletonLoader(context, cardColor),
                _buildOffersSkeleton(cardColor),
              ],
            )
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          side: BorderSide(color: borderColor),
                        ),
                        onPressed: _fetchData,
                        child: Text('Retry', style: TextStyle(color: textPrimary)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _fetchData,
                      color: primaryColor,
                      backgroundColor: cardColor,
                      child: _buildDashboardTab(context, cardColor, borderColor, textPrimary, textSecondary),
                    ),
                    RefreshIndicator(
                      onRefresh: _fetchData,
                      color: primaryColor,
                      backgroundColor: cardColor,
                      child: _buildOffersTab(cardColor, borderColor, textPrimary, textSecondary),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        // Wallet Balance Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0xFF08101F) : const Color(0xFFCBD5E1).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(color: textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '₦${_stats!.walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Stats Grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _buildStatCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              title: 'Data sold',
              value: '${_stats!.todayDataGb} GB',
              badgeText: 'Live',
              badgeColor: Colors.green,
            ),
            _buildStatCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              title: 'Airtime sold',
              value: '₦${_stats!.todayAirtime.toStringAsFixed(0)}',
              badgeText: 'Live',
              badgeColor: Colors.green,
            ),
            _buildStatCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              title: 'Data sold',
              value: '${_stats!.monthDataGb} GB',
              badgeText: '30d',
              badgeColor: Colors.grey.shade600,
            ),
            _buildStatCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              title: 'Airtime sold',
              value: '₦${_stats!.monthAirtime.toStringAsFixed(0)}',
              badgeText: '30d',
              badgeColor: Colors.grey.shade600,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Sales Growth Chart
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0xFF08101F) : const Color(0xFFCBD5E1).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales Growth',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('7d', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _legendItem(const Color(0xFFF59E0B), 'Airtime (₦)', textSecondary),
                  const SizedBox(width: 16),
                  _legendItem(primaryColor, 'Data (GB)', textSecondary),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 150,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 1),
                          FlSpot(1, 2.5),
                          FlSpot(2, 1.5),
                          FlSpot(3, 3),
                          FlSpot(4, 2),
                          FlSpot(5, 4),
                          FlSpot(6, 3),
                        ],
                        isCurved: true,
                        color: primaryColor,
                        barWidth: 3.5,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 0.5),
                          FlSpot(1, 1),
                          FlSpot(2, 2.5),
                          FlSpot(3, 1),
                          FlSpot(4, 3.5),
                          FlSpot(5, 2),
                          FlSpot(6, 1.5),
                        ],
                        isCurved: true,
                        color: const Color(0xFFF59E0B),
                        barWidth: 3.5,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => launchUrl(Uri.parse('https://chat.whatsapp.com/JvmyGaCuxeeAPBjKAKZJhk?s=cl&p=i&mlu=3&amv=0'), mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF25D366),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join Agent WhatsApp Group',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect with other agents and get support.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required String title,
    required String value,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badgeText == 'Live' ? 'Orders/Tx' : '30 days total',
            style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text, Color textColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildOffersTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        // Static Agent Perk Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor.withValues(alpha: 0.85), primaryColor.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Up to 15% off on Data & Airtime.',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Always-on  •  Agent perk',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        ..._campaigns.map((c) => _buildCampaignCard(c, cardColor, borderColor, textPrimary, textSecondary)).toList(),
        if (_campaigns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No other active offers right now.', style: TextStyle(color: textSecondary)),
            ),
          ),
      ],
    );
  }

  Widget _buildCampaignCard(
    RewardCampaign campaign,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final progressPercent = (campaign.progressValue / campaign.targetValue).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${campaign.targetValue} ${campaign.targetMetric.toLowerCase().contains('gb') ? 'GB' : ''}',
                      style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₦${campaign.rewardAmount.toStringAsFixed(0)}',
                          style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '  •  Free Wallet Credit',
                          style: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: campaign.isQualified ? () => _claimReward(campaign) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: campaign.isQualified ? primaryColor : textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: campaign.isQualified ? primaryColor : borderColor,
                    ),
                  ),
                  child: Text(
                    campaign.isQualified ? 'Unlock' : 'Locked',
                    style: TextStyle(
                      color: campaign.isQualified ? Colors.white : textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${(progressPercent * 100).toInt()}%',
                style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: textSecondary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      campaign.isQualified ? Colors.green : primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context, Color cardColor) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBlock(width: 120, height: 16),
              SkeletonBlock(width: 80, height: 28, borderRadius: 20),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: List.generate(4, (index) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBlock(width: 70, height: 12),
                    SkeletonBlock(width: 32, height: 18, borderRadius: 12),
                  ],
                ),
                SkeletonBlock(width: 100, height: 22),
                SkeletonBlock(width: 60, height: 10),
              ],
            ),
          )),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBlock(width: 100, height: 16),
                  SkeletonBlock(width: 40, height: 22, borderRadius: 20),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  SkeletonBlock(width: 80, height: 12),
                  SizedBox(width: 16),
                  SkeletonBlock(width: 80, height: 12),
                ],
              ),
              SizedBox(height: 24),
              SkeletonBlock(width: double.infinity, height: 150),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOffersSkeleton(Color cardColor) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: 200, height: 18),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBlock(width: 120, height: 12),
                  SkeletonBlock(width: 50, height: 22, borderRadius: 16),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(2, (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 140, height: 16),
                      SizedBox(height: 6),
                      SkeletonBlock(width: 80, height: 12),
                      SizedBox(height: 8),
                      SkeletonBlock(width: 60, height: 12),
                    ],
                  ),
                  SkeletonBlock(width: 64, height: 28, borderRadius: 20),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  SkeletonBlock(width: 30, height: 12),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBlock(width: double.infinity, height: 6)),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class SkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.65).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}


