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
    String link = (data['referral_link'] ?? '').toString();
    if (link.contains('.vercel.app')) {
      link = link.replaceAll('.vercel.app', 'axisvtu.com');
    }
    // Final check to ensure it's the correct production domain
    if (!link.startsWith('https://axisvtu.com')) {
      // If it's a relative path or another domain, force it
      if (link.contains('/signup?')) {
        final query = link.split('?').last;
        link = 'https://axisvtu.com/signup?$query';
      }
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.66);

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
                title: 'Share Code',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            referralCode,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: referralCode == '—' ? null : () => _copyCode(referralCode),
                          icon: const Icon(Icons.copy_rounded, size: 20),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: (loading || referralCode == '—') ? null : () => _shareInvite(data ?? const {}),
                          icon: const Icon(Icons.share_rounded, size: 20),
                        ),
                      ],
                    ),
                    if (referralLink.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        referralLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _StatPill(label: 'Invited', value: totalReferrals, icon: Icons.group_outlined),
                      const SizedBox(width: 10),
                      _StatPill(label: 'Rewarded', value: rewardedReferrals, icon: Icons.verified_outlined),
                      const SizedBox(width: 10),
                      _StatPill(label: 'Total Earned', value: totalEarned, icon: Icons.payments_outlined),
                    ],
                  ),
                ),
              ),
              ServiceSectionCard(
                title: 'Reward Policy',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Earn 2% of your friend\'s first deposit.',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reward is credited after the first successful wallet funding only.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'REFERRAL HISTORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _ReferralLoading(),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.14 : 0.1),
                      ),
                    ),
                    child: Text(
                      'Referral details are temporarily unavailable. Pull to refresh and try again.',
                      style: TextStyle(color: muted, height: 1.45),
                    ),
                  ),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.14 : 0.1),
                      ),
                    ),
                    child: Text(
                      'No referrals yet. Share your code to start earning once your friend begins buying data.',
                      style: TextStyle(color: muted, height: 1.45),
                    ),
                  ),
                )
              else
                ...items.whereType<Map>().map((raw) {
                  final item = raw.map((k, v) => MapEntry(k.toString(), v));
                  final status = (item['status'] ?? 'pending').toString();
                  final itemName = (item['referred_user_name'] ?? 'Referral').toString();
                  final firstDeposit = _money(item['first_deposit_amount'] ?? 0);
                  final reward = _money(item['reward_amount'] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.14 : 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Code ${item['referral_code_used'] ?? '—'}',
                                      style: TextStyle(color: muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(label: status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'First Deposit',
                                    style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    firstDeposit,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Your Reward',
                                    style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    reward,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
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
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          child: Container(
            height: 124,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
