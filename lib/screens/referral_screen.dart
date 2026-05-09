import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/referral_service.dart';
import '../state/session.dart';
import '../widgets/service_shell.dart';
import '../widgets/glass_card.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  static const route = '/referrals';

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Future<Map<String, dynamic>>? _future;
  String _activeToken = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = (context.watch<SessionController>().token ?? '').trim();
    if (token.isNotEmpty && (token != _activeToken || _future == null)) {
      _activeToken = token;
      _future = ReferralService(token: token).getMe();
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
      ..writeln('AxisVTU')
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
        subject: 'Join me on AxisVTU',
      ),
    );
  }

  String _getReferralLink(Map<String, dynamic> data) {
    // Ensure we don't double up the domain
    String link = (data['referral_link'] ?? '').toString().trim();
    
    // Fix the "double axisvtu" bug: axisvtu.vercel.app -> axisvtu.com
    if (link.contains('axisvtu.vercel.app')) {
      link = link.replaceFirst('https://axisvtu.vercel.app', 'https://axisvtu.com');
      link = link.replaceFirst('axisvtu.vercel.app', 'axisvtu.com');
    } else if (link.contains('.vercel.app')) {
      link = link.replaceAll('.vercel.app', 'axisvtu.com');
    }

    // Final check to ensure it's the correct production domain
    if (!link.startsWith('https://axisvtu.com')) {
      if (link.contains('/signup?')) {
        final query = link.split('?').last;
        link = 'https://axisvtu.com/signup?$query';
      }
    }
    
    // Absolute permanent fix for any doubling
    if (link.contains('axisvtu.comaxisvtu.com')) {
      link = link.replaceAll('axisvtu.comaxisvtu.com', 'axisvtu.com');
    }
    if (link.contains('axisvtu.com/axisvtu')) {
      link = link.replaceFirst('axisvtu.com/axisvtu', 'axisvtu.com');
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

    return ServiceShell(
      title: 'Referrals',
      subtitle: 'Invite friends and earn when they keep buying data.',
      icon: Icons.group_add_rounded,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = _future == null || snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;
          final items = (data?['referrals'] as List?) ?? const [];
          final referralCode = (data?['referral_code'] ?? '—').toString();
          final referralLink = data != null ? _getReferralLink(data) : '';
          final totalReferrals = (data?['total_referrals'] ?? 0).toString();
          final rewardedReferrals = (data?['rewarded_referrals'] ?? 0).toString();
          final totalEarned = _money(data?['total_earned']);

          return Column(
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
              else if (snapshot.hasError)
                _EmptyHistory(
                  message: 'Referral details are temporarily unavailable. Pull to refresh and try again.',
                  isError: true,
                )
              else if (items.isEmpty)
                _EmptyHistory(
                  message: 'No referrals yet. Share your code to start earning once your friends join AxisVTU.',
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
          );
        },
      ),
    );
  }
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
