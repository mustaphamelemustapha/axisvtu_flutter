import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/agent_models.dart';
import '../state/session.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import 'agent_dashboard_screen.dart' show SkeletonBlock;

class AdminAgentScreen extends StatefulWidget {
  const AdminAgentScreen({super.key});

  static const String route = '/admin/agents';

  @override
  State<AdminAgentScreen> createState() => _AdminAgentScreenState();
}

class _AdminAgentScreenState extends State<AdminAgentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Campaigns state
  List<RewardCampaign> _campaigns = [];
  bool _campaignsLoading = true;
  String? _campaignsError;

  // Agents state
  List<AdminAgentStat> _agents = [];
  bool _agentsLoading = true;
  String? _agentsError;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _actionPendingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCampaigns();
    _loadAgents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    if (!mounted) return;
    setState(() {
      _campaignsLoading = true;
      _campaignsError = null;
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final resp = await adminService.listCampaigns();
      final items = (resp['items'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _campaigns = items.map((json) => RewardCampaign.fromJson(json)).toList();
          _campaignsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _campaignsError = e.toString().replaceAll('Exception: ', '');
          _campaignsLoading = false;
        });
      }
    }
  }

  Future<void> _loadAgents({String? query}) async {
    if (!mounted) return;
    setState(() {
      _agentsLoading = true;
      _agentsError = null;
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final resp = await adminService.listAgentStats(query: query);
      final items = (resp['items'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _agents = items.map((json) => AdminAgentStat.fromJson(json)).toList();
          _agentsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _agentsError = e.toString().replaceAll('Exception: ', '');
          _agentsLoading = false;
        });
      }
    }
  }

  Future<void> _toggleCampaignActive(RewardCampaign campaign) async {
    final campaignId = campaign.id;
    if (_actionPendingIds.contains(campaignId)) return;

    setState(() {
      _actionPendingIds.add(campaignId);
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      await adminService.updateCampaign(campaignId, {
        'is_active': !campaign.isActive,
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        _loadCampaigns();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(campaign.isActive ? 'Campaign deactivated' : 'Campaign activated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle campaign status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionPendingIds.remove(campaignId);
        });
      }
    }
  }

  Future<void> _deleteCampaign(RewardCampaign campaign) async {
    final token = context.read<SessionController>().token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete or deactivate "${campaign.title}"? Campaigns with reward claims will be deactivated automatically instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminService = AdminService(token: token);
      final res = await adminService.deleteCampaign(campaign.id);
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        _loadCampaigns();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['action'] == 'agent_campaign_deactivate' 
              ? 'Campaign has reward history, deactivated instead.' 
              : 'Campaign deleted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete campaign: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openCreateCampaignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCampaignSheet(
        onSuccess: _loadCampaigns,
      ),
    );
  }

  void _openEditCampaignSheet(RewardCampaign campaign) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCampaignSheet(
        campaign: campaign,
        onSuccess: _loadCampaigns,
      ),
    );
  }

  void _openOverrideStatsSheet(AdminAgentStat stat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OverrideStatsSheet(
        stat: stat,
        onSuccess: _loadAgents,
      ),
    );
  }

  void _openManualRewardSheet(AdminAgentStat stat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualRewardSheet(
        stat: stat,
        campaigns: _campaigns.where((c) => c.isActive).toList(),
        onSuccess: _loadAgents,
      ),
    );
  }

  void _openRewardsHistorySheet(AdminAgentStat stat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RewardsHistorySheet(
        stat: stat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Agents',
          style: TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textMain),
            onPressed: () {
              _loadCampaigns();
              _loadAgents(query: _searchCtrl.text);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: textMain,
          unselectedLabelColor: textDim,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Campaigns'),
            Tab(text: 'Agents list'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignsTab(context, isDark, textMain, textDim, primaryColor),
          _buildAgentsTab(context, isDark, textMain, textDim, primaryColor),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab(BuildContext context, bool isDark, Color textMain, Color textDim, Color primaryColor) {
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    if (_campaignsLoading) {
      return _buildSkeletonList(cardColor);
    }

    if (_campaignsError != null) {
      return _buildErrorState(_campaignsError!, _loadCampaigns, textMain, cardColor, borderColor);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateCampaignSheet,
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCampaigns,
        color: primaryColor,
        backgroundColor: cardColor,
        child: _campaigns.isEmpty
            ? _buildEmptyState('No Reward Campaigns', 'Create targets and campaign rewards to motivate your agents.', Icons.emoji_events_outlined, _openCreateCampaignSheet, 'Create Campaign')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: _campaigns.length,
                itemBuilder: (context, index) {
                  final campaign = _campaigns[index];
                  final isUpdating = _actionPendingIds.contains(campaign.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  campaign.campaignType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              isUpdating
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Switch.adaptive(
                                      value: campaign.isActive,
                                      activeColor: primaryColor,
                                      onChanged: (val) => _toggleCampaignActive(campaign),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            campaign.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Metric: ${campaign.targetMetric}',
                                style: TextStyle(fontSize: 13, color: textDim, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '  •  Target: ${campaign.targetValue.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 13, color: textDim, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reward: ₦${campaign.rewardAmount.toStringAsFixed(2)} Wallet Credit',
                            style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: textDim, size: 20),
                                onPressed: () => _openEditCampaignSheet(campaign),
                                tooltip: 'Edit',
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteCampaign(campaign),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAgentsTab(BuildContext context, bool isDark, Color textMain, Color textDim, Color primaryColor) {
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Search Agents',
              hintText: 'Enter name or email',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchCtrl.clear();
                  _loadAgents();
                },
              ),
            ),
            onSubmitted: (val) => _loadAgents(query: val.trim()),
          ),
        ),
        Expanded(
          child: _agentsLoading
              ? _buildSkeletonList(cardColor)
              : _agentsError != null
                  ? _buildErrorState(_agentsError!, _loadAgents, textMain, cardColor, borderColor)
                  : RefreshIndicator(
                      onRefresh: () => _loadAgents(query: _searchCtrl.text.trim()),
                      color: primaryColor,
                      backgroundColor: cardColor,
                      child: _agents.isEmpty
                          ? _buildEmptyState('No Agents Found', 'Make sure your agent/reseller accounts exist on the platform.', Icons.people_outline, () => _loadAgents(), 'Refresh List')
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _agents.length,
                              itemBuilder: (context, index) {
                                final agent = _agents[index];
                                final dataGb = (agent.totalDataMb / 1024.0).toStringAsFixed(1);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                                              child: Text(
                                                agent.agentFullName.isNotEmpty ? agent.agentFullName[0].toUpperCase() : 'A',
                                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    agent.agentFullName,
                                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textMain),
                                                  ),
                                                  Text(
                                                    agent.agentEmail,
                                                    style: TextStyle(fontSize: 12, color: textDim),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('DATA SOLD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textDim)),
                                                    Text('$dataGb GB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMain)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('AIRTIME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textDim)),
                                                    Text('₦${agent.totalAirtimeAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMain)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('TXS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textDim)),
                                                    Text('${agent.totalTransactions}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMain)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton.icon(
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: textDim),
                                              icon: const Icon(Icons.history_rounded, size: 16),
                                              label: const Text('Rewards', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () => _openRewardsHistorySheet(agent),
                                            ),
                                            Row(
                                              children: [
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    side: BorderSide(color: borderColor),
                                                  ),
                                                  onPressed: () => _openOverrideStatsSheet(agent),
                                                  child: Text('Override', style: TextStyle(fontSize: 12, color: textMain, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    backgroundColor: primaryColor,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: () => _openManualRewardSheet(agent),
                                                  child: const Text('Reward', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(Color cardColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        height: 150,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBlock(width: 80, height: 16),
            SkeletonBlock(width: 180, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBlock(width: 100, height: 12),
                SkeletonBlock(width: 60, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry, Color textMain, Color cardColor, Color borderColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cardColor, side: BorderSide(color: borderColor)),
              onPressed: onRetry,
              child: Text('Retry', style: TextStyle(color: textMain)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, VoidCallback onAction, String btnText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textDim, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(btnText),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet to create/edit campaign targets
class _CreateCampaignSheet extends StatefulWidget {
  final RewardCampaign? campaign;
  final VoidCallback onSuccess;

  const _CreateCampaignSheet({this.campaign, required this.onSuccess});

  @override
  State<_CreateCampaignSheet> createState() => _CreateCampaignSheetState();
}

class _CreateCampaignSheetState extends State<_CreateCampaignSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _targetValueCtrl = TextEditingController();
  final _rewardAmountCtrl = TextEditingController();
  
  String _campaignType = 'volume';
  String _targetMetric = 'data_gb';
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      _titleCtrl.text = widget.campaign!.title;
      _targetValueCtrl.text = widget.campaign!.targetValue.toStringAsFixed(0);
      _rewardAmountCtrl.text = widget.campaign!.rewardAmount.toStringAsFixed(0);
      _campaignType = widget.campaign!.campaignType;
      _targetMetric = widget.campaign!.targetMetric;
      _isActive = widget.campaign!.isActive;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetValueCtrl.dispose();
    _rewardAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final payload = {
        'title': _titleCtrl.text.trim(),
        'campaign_type': _campaignType,
        'target_metric': _targetMetric,
        'target_value': double.parse(_targetValueCtrl.text.trim()),
        'reward_amount': double.parse(_rewardAmountCtrl.text.trim()),
        'is_active': _isActive,
      };

      if (widget.campaign != null) {
        await adminService.updateCampaign(widget.campaign!.id, payload);
      } else {
        await adminService.createCampaign(payload);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.campaign != null ? 'Campaign updated' : 'Campaign created')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save campaign: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      widget.campaign != null ? 'Edit Campaign' : 'New Campaign',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Campaign Title', prefixIcon: Icon(Icons.title_rounded)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _campaignType,
                  decoration: const InputDecoration(labelText: 'Campaign Type', prefixIcon: Icon(Icons.category_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'volume', child: Text('Sales Volume (targets)')),
                    DropdownMenuItem(value: 'referral', child: Text('Referrals')),
                    DropdownMenuItem(value: 'loyalty', child: Text('Loyalty')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _campaignType = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _targetMetric,
                  decoration: const InputDecoration(labelText: 'Target Metric', prefixIcon: Icon(Icons.query_stats_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'data_gb', child: Text('Data Sold (GB)')),
                    DropdownMenuItem(value: 'airtime_amount', child: Text('Airtime Sold (₦)')),
                    DropdownMenuItem(value: 'transactions', child: Text('Transactions Count')),
                    DropdownMenuItem(value: 'referrals', child: Text('Referral Signups')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _targetMetric = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Target Value', prefixIcon: Icon(Icons.flag_rounded)),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Target value required';
                          if (double.tryParse(val.trim()) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rewardAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Reward (₦)', prefixIcon: Icon(Icons.payments_rounded)),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Reward required';
                          if (double.tryParse(val.trim()) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: const Text('Campaign Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('Eligible agents can track and claim rewards immediately.', style: TextStyle(color: textDim, fontSize: 12)),
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _submitting ? 'Saving...' : 'Save Campaign',
                  loading: _submitting,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bottom sheet to override agent statistics
class _OverrideStatsSheet extends StatefulWidget {
  final AdminAgentStat stat;
  final VoidCallback onSuccess;

  const _OverrideStatsSheet({required this.stat, required this.onSuccess});

  @override
  State<_OverrideStatsSheet> createState() => _OverrideStatsSheetState();
}

class _OverrideStatsSheetState extends State<_OverrideStatsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dataMbCtrl = TextEditingController();
  final _airtimeCtrl = TextEditingController();
  final _txCountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dataMbCtrl.text = widget.stat.totalDataMb.toStringAsFixed(0);
    _airtimeCtrl.text = widget.stat.totalAirtimeAmount.toStringAsFixed(0);
    _txCountCtrl.text = widget.stat.totalTransactions.toString();
  }

  @override
  void dispose() {
    _dataMbCtrl.dispose();
    _airtimeCtrl.dispose();
    _txCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final payload = {
        'total_data_mb': double.parse(_dataMbCtrl.text.trim()),
        'total_airtime_amount': double.parse(_airtimeCtrl.text.trim()),
        'total_transactions': int.parse(_txCountCtrl.text.trim()),
      };

      await adminService.overrideAgentStats(widget.stat.agentId, payload);

      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent statistics overridden successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to override stats: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Override Statistics',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Override cumulative volume stats for ${widget.stat.agentFullName}. This affects target progress updates immediately.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dataMbCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Data sold (MB)', prefixIcon: Icon(Icons.data_usage_rounded)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Value required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _airtimeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Airtime sold (₦)', prefixIcon: Icon(Icons.payments_rounded)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Value required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _txCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Transactions', prefixIcon: Icon(Icons.receipt_long_rounded)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Value required' : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _submitting ? 'Overriding...' : 'Save Overrides',
                  loading: _submitting,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bottom sheet to reward manual credit to agent
class _ManualRewardSheet extends StatefulWidget {
  final AdminAgentStat stat;
  final List<RewardCampaign> campaigns;
  final VoidCallback onSuccess;

  const _ManualRewardSheet({required this.stat, required this.campaigns, required this.onSuccess});

  @override
  State<_ManualRewardSheet> createState() => _ManualRewardSheetState();
}

class _ManualRewardSheetState extends State<_ManualRewardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  
  int? _selectedCampaignId;
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final double? customAmount = _amountCtrl.text.trim().isNotEmpty 
          ? double.tryParse(_amountCtrl.text.trim()) 
          : null;

      await adminService.manualRewardAgent(
        widget.stat.agentId,
        campaignId: _selectedCampaignId,
        amount: customAmount,
        reason: _reasonCtrl.text.trim(),
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent manually rewarded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reward agent: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Manual Reward',
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Credit a reward to ${widget.stat.agentFullName}. You can link to a campaign target or fill in a manual custom amount.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: _selectedCampaignId,
                  decoration: const InputDecoration(labelText: 'Link Campaign Target (Optional)', prefixIcon: Icon(Icons.emoji_events_rounded)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Custom/Direct Credit (No Campaign)')),
                    ...widget.campaigns.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCampaignId = val;
                      if (val != null) {
                        final campaign = widget.campaigns.firstWhere((c) => c.id == val);
                        _amountCtrl.text = campaign.rewardAmount.toStringAsFixed(0);
                      } else {
                        _amountCtrl.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Reward Amount (₦)', prefixIcon: Icon(Icons.payments_rounded)),
                  validator: (val) {
                    if (_selectedCampaignId == null && (val == null || val.trim().isEmpty)) {
                      return 'Amount is required for custom rewards';
                    }
                    if (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null) {
                      return 'Must be a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reward Reason', prefixIcon: Icon(Icons.rate_review_rounded)),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Reason is required for manual reward audits' : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _submitting ? 'Processing Reward...' : 'Credit Reward',
                  loading: _submitting,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bottom sheet showing list of agent's past rewards
class _RewardsHistorySheet extends StatefulWidget {
  final AdminAgentStat stat;

  const _RewardsHistorySheet({required this.stat});

  @override
  State<_RewardsHistorySheet> createState() => _RewardsHistorySheetState();
}

class _RewardsHistorySheetState extends State<_RewardsHistorySheet> {
  List<AdminAgentReward> _rewards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    try {
      final token = context.read<SessionController>().token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      final resp = await adminService.getAgentRewards(widget.stat.agentId);
      final items = (resp['items'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _rewards = items.map((json) => AdminAgentReward.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Reward Claims Log',
                style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Past target payouts and manual rewards for ${widget.stat.agentFullName}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error loading: $_error'))
                    : _rewards.isEmpty
                        ? const Center(child: Text('No rewards documented for this agent.'))
                        : ListView.builder(
                            itemCount: _rewards.length,
                            itemBuilder: (context, index) {
                              final reward = _rewards[index];
                              final isCredited = reward.status.toLowerCase() == 'credited';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reward.campaignTitle,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textMain),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            reward.transactionReference,
                                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₦${reward.amount.toStringAsFixed(0)}',
                                          style: TextStyle(fontWeight: FontWeight.w900, color: isCredited ? Colors.green : Colors.amber, fontSize: 15),
                                        ),
                                        Text(
                                          reward.status.toUpperCase(),
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isCredited ? Colors.green : Colors.amber),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
