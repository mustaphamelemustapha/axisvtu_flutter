import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/referral_service.dart';
import '../services/dashboard_snapshot_cache.dart';
import '../state/session.dart';
import '../widgets/service_shell.dart';
import '../widgets/glass_card.dart';
import 'package:fl_chart/fl_chart.dart';


class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  static const route = '/referrals';

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _cachedData;
  bool _isLoading = true;
  String _activeToken = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isNotEmpty && token != _activeToken) {
      _activeToken = token;

      // Load from cache first for instant loading
      final identity = DashboardSnapshotCache.identityFromUser(session.user);
      if (identity != null) {
        final mem = DashboardSnapshotCache.loadSync(identity);
        if (mem != null && mem['referrals'] != null) {
          _cachedData = mem['referrals'] as Map<String, dynamic>;
          _isLoading = false;
        } else {
          DashboardSnapshotCache.load(identity).then((disk) {
            if (disk != null && disk['referrals'] != null && _cachedData == null && mounted) {
              setState(() {
                _cachedData = disk['referrals'] as Map<String, dynamic>;
                _isLoading = false;
              });
            }
          });
        }
      }

      // Fetch fresh data from API in background and sync
      ReferralService(token: token).getMe().then((freshData) {
        if (identity != null) {
          DashboardSnapshotCache.save(identity, referrals: freshData);
        }
        if (mounted) {
          setState(() {
            _cachedData = freshData;
            _isLoading = false;
          });
        }
      }).catchError((err) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  Future<void> _copyCode(String code) async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied')),
    );
  }

  Future<void> _shareInvite(Map<String, dynamic> data) async {
    final code = (data['referral_code'] ?? '').toString().trim();
    final rawLink = (data['referral_link'] ?? '').toString().trim();
    final link = _getReferralLink(data);
    final text = StringBuffer()
      ..writeln('MELE DATA')
      ..writeln('Buy data, pay bills, and manage your wallet in one place.')
      ..writeln('Use my referral code: $code')
      ..writeln('');
    if (link.isNotEmpty) {
      text.writeln(link);
    }
    HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(
        text: text.toString().trim(),
        subject: 'Join me on MELE DATA',
      ),
    );
  }

  String _getReferralLink(Map<String, dynamic> data) {
    // Ensure we don't double up the domain
    String link = (data['referral_link'] ?? '').toString().trim();
    
    // Fix the "double meledata" bug: meledata.vercel.app -> meledata.ng
    if (link.contains('meledata.vercel.app') || link.contains('axisvtu.vercel.app')) {
      link = link.replaceFirst('https://meledata.vercel.app', 'https://meledata.ng');
      link = link.replaceFirst('meledata.vercel.app', 'meledata.ng');
      link = link.replaceFirst('https://axisvtu.vercel.app', 'https://meledata.ng');
      link = link.replaceFirst('axisvtu.vercel.app', 'meledata.ng');
    } else if (link.contains('.vercel.app')) {
      link = link.replaceAll('.vercel.app', 'meledata.ng');
    }

    // Final check to ensure it's the correct production domain
    if (!link.startsWith('https://meledata.ng')) {
      if (link.contains('/signup?')) {
        final query = link.split('?').last;
        link = 'https://meledata.ng/signup?$query';
      }
    }
    
    // Absolute permanent fix for any doubling
    if (link.contains('meledata.ngmeledata.ng')) {
      link = link.replaceAll('meledata.ngmeledata.ng', 'meledata.ng');
    }
    if (link.contains('meledata.ng/meledata')) {
      link = link.replaceFirst('meledata.ng/meledata', 'meledata.ng');
    }
    if (link.contains('meledata.ng/axisvtu')) {
      link = link.replaceFirst('meledata.ng/axisvtu', 'meledata.ng');
    }
    
    return link;
  }

  String _money(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return '₦${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66);

    final loading = _isLoading && _cachedData == null;
    final data = _cachedData;
    final items = (data?['referrals'] as List?) ?? const [];
    final referralCode = (data?['referral_code'] ?? '—').toString();
    final referralLink = data != null ? _getReferralLink(data) : '';
    final totalReferrals = (data?['total_referrals'] ?? 0).toString();
    final rewardedReferrals = (data?['rewarded_referrals'] ?? 0).toString();
    final totalEarned = _money(data?['total_earned']);

    // Monthly data aggregation for the last 6 months
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final last6 = <ReferralMonthData>[];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final label = months[d.month - 1];
      final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      last6.add(ReferralMonthData(label: label, key: key));
    }

    int rewardedCount = 0;
    int qualifiedCount = 0;
    int pendingCount = 0;

    for (final raw in items) {
      if (raw is! Map) continue;
      final item = raw.map((k, v) => MapEntry(k.toString(), v));
      final status = (item['status'] ?? 'pending').toString().toLowerCase();

      if (status == 'rewarded') {
        rewardedCount++;
      } else if (status == 'qualified') {
        qualifiedCount++;
      } else {
        pendingCount++;
      }

      if (item['created_at'] != null) {
        final cDate = DateTime.tryParse(item['created_at'].toString());
        if (cDate != null) {
          final key = "${cDate.year}-${cDate.month.toString().padLeft(2, '0')}";
          final idx = last6.indexWhere((m) => m.key == key);
          if (idx != -1) {
            last6[idx].signups++;
          }
        }
      }

      if (status == 'rewarded' && item['rewarded_at'] != null) {
        final rDate = DateTime.tryParse(item['rewarded_at'].toString());
        if (rDate != null) {
          final key = "${rDate.year}-${rDate.month.toString().padLeft(2, '0')}";
          final idx = last6.indexWhere((m) => m.key == key);
          if (idx != -1) {
            final rewAmt = double.tryParse(item['reward_amount']?.toString() ?? '') ?? 0.0;
            last6[idx].earnings += rewAmt;
          }
        }
      }
    }

    final totalCount = rewardedCount + qualifiedCount + pendingCount;
    final maxSignups = last6.map((m) => m.signups).fold(1, (a, b) => a > b ? a : b).toDouble();
    final maxEarnings = last6.map((m) => m.earnings).fold(100.0, (a, b) => a > b ? a : b);

    return ServiceShell(
      title: 'Referrals',
      subtitle: 'Invite friends and earn when they keep buying data.',
      icon: Icons.group_add_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceSectionCard(
            title: 'Your Referral Identity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REFERRAL CODE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  referralCode,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: referralCode == '—' ? null : () => _copyCode(referralCode),
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: (loading || referralCode == '—') ? null : () => _shareInvite(data ?? const {}),
                            icon: const Icon(Icons.share_rounded, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                      if (referralLink.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 16, color: muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  referralLink,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          ServiceSectionCard(
            title: 'Performance Stats',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Column(
                  children: [
                    Row(
                      children: [
                        _StatPill(
                          label: 'Total Invited',
                          value: totalReferrals,
                          icon: Icons.group_outlined,
                          width: width,
                        ),
                        const SizedBox(width: 12),
                        _StatPill(
                          label: 'Rewarded',
                          value: rewardedReferrals,
                          icon: Icons.verified_outlined,
                          width: width,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatPill(
                      label: 'Total Earned',
                      value: totalEarned,
                      icon: Icons.payments_outlined,
                      width: constraints.maxWidth,
                      isLarge: true,
                    ),
                  ],
                );
              },
            ),
          ),

          if (!loading && items.isNotEmpty)
            ServiceSectionCard(
              title: 'Analytics & Insights',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'INVITE PIPELINE SPLIT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSplitBar(
                    context: context,
                    label: 'Rewarded (2% Paid)',
                    count: rewardedCount,
                    total: totalCount,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _buildSplitBar(
                    context: context,
                    label: 'Qualified (First Deposit)',
                    count: qualifiedCount,
                    total: totalCount,
                    color: const Color(0xFF2457F5),
                  ),
                  const SizedBox(height: 8),
                  _buildSplitBar(
                    context: context,
                    label: 'Pending (Registered Only)',
                    count: pendingCount,
                    total: totalCount,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PERFORMANCE TRENDS (6M)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Invites / Earnings',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _legendDot(const Color(0xFF3B82F6), 'Signups (Invites)'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF10B981), 'Earnings (₦)'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 145,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < last6.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      last6[idx].label,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              last6.length,
                              (idx) {
                                final val = last6[idx].signups.toDouble();
                                return FlSpot(idx.toDouble(), (val / maxSignups) * 5.0);
                              },
                            ),
                            isCurved: true,
                            color: const Color(0xFF3B82F6),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: List.generate(
                              last6.length,
                              (idx) {
                                final val = last6[idx].earnings;
                                return FlSpot(idx.toDouble(), (val / maxEarnings) * 5.0);
                              },
                            ),
                            isCurved: true,
                            color: const Color(0xFF10B981),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ServiceSectionCard(
            title: 'Reward Policy',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Earn 2% Lifetime Rewards',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get rewarded instantly when your friends fund their wallet for the first time.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 16, 16),
            child: Text(
              'REFERRAL HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
          ),

          if (loading)
            const _ReferralLoading()
          else if (data == null)
            _EmptyHistory(
              message: 'Referral details are temporarily unavailable. Pull to refresh and try again.',
              isError: true,
            )
          else if (items.isEmpty)
            _EmptyHistory(
              message: 'No referrals yet. Share your code to start earning once your friends join MELE DATA.',
            )
          else
            ...items.whereType<Map>().map((raw) {
              final item = raw.map((k, v) => MapEntry(k.toString(), v));
              final status = (item['status'] ?? 'pending').toString();
              final itemName = (item['referred_user_name'] ?? 'Referral').toString();
              final firstDeposit = _money(item['first_deposit_amount'] ?? 0);
              final reward = _money(item['reward_amount'] ?? 0);
              return _ReferralItem(
                name: itemName,
                code: (item['referral_code_used'] ?? '—').toString(),
                status: status,
                deposit: firstDeposit,
                reward: reward,
              );
            }),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSplitBar({
    required BuildContext context,
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? (count / total) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pctText = total > 0 ? "${(pct * 100).round()}%" : "0%";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              "$count ($pctText)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ReferralMonthData {
  final String label;
  final String key;
  int signups;
  double earnings;

  ReferralMonthData({
    required this.label,
    required this.key,
    this.signups = 0,
    this.earnings = 0.0,
  });
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
    this.isLarge = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final double width;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isLarge ? 16 : 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isLarge ? 20 : 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralItem extends StatelessWidget {
  const _ReferralItem({
    required this.name,
    required this.code,
    required this.status,
    required this.deposit,
    required this.reward,
  });

  final String name;
  final String code;
  final String status;
  final String deposit;
  final String reward;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Code: $code',
                      style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: status),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIRST DEPOSIT',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deposit,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: muted.withValues(alpha: 0.1)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'YOUR REWARD',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reward,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.history_rounded,
            size: 32,
            color: isError ? Colors.red.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final color = switch (lower) {
      'rewarded' => const Color(0xFF10B981),
      'qualified' => const Color(0xFF2457F5),
      _ => const Color(0xFFF59E0B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ReferralLoading extends StatelessWidget {
  const _ReferralLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }
}
