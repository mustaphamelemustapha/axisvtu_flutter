import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/referral_service.dart';
import '../state/session.dart';

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
    final link = (data['referral_link'] ?? '').toString().trim();
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

  String _gbLabel(int mb) {
    if (mb <= 0) return '0GB';
    final gb = mb / 1024.0;
    if ((gb - gb.roundToDouble()).abs() < 0.05) {
      return '${gb.round()}GB';
    }
    return '${gb.toStringAsFixed(1)}GB';
  }

  String _money(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return '₦${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final token = (context.read<SessionController>().token ?? '').trim();
            if (token.isEmpty) return;
            setState(() {
              _future = ReferralService(token: token).getMe();
            });
            await _future;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              final loading = _future == null || snapshot.connectionState == ConnectionState.waiting;
              final data = snapshot.data;
              final items = (data?['referrals'] as List?) ?? const [];
              final referralCode = (data?['referral_code'] ?? '—').toString();
              final referralLink = (data?['referral_link'] ?? '').toString();
              final totalReferrals = (data?['total_referrals'] ?? 0).toString();
              final rewardedReferrals = (data?['rewarded_referrals'] ?? 0).toString();
              final totalEarned = _money(data?['total_earned']);
              final rewardAmount = _money(data?['reward_amount']);
              final targetMb = int.tryParse((data?['target_mb'] ?? 51200).toString()) ?? 51200;
              final progressPercent = (data?['progress_percent'] ?? 0).toString();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 14, compact ? 16 : 20, 28),
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF4F7FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Referrals',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Invite friends and earn when they keep buying data.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(compact ? 14 : 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your referral code',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                referralCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: referralCode == '—' ? null : () => _copyCode(referralCode),
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Copy code',
                            ),
                            IconButton(
                              onPressed: (loading || referralCode == '—') ? null : () => _shareInvite(data ?? const {}),
                              icon: const Icon(Icons.share_rounded),
                              tooltip: 'Share invite',
                            ),
                          ],
                        ),
                        if (referralLink.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            referralLink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatPill(label: 'Friends invited', value: totalReferrals, icon: Icons.group_outlined),
                      _StatPill(label: 'Rewards earned', value: rewardedReferrals, icon: Icons.verified_outlined),
                      _StatPill(label: 'Total earned', value: totalEarned, icon: Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: EdgeInsets.all(compact ? 14 : 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reward rule',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Earn ₦2,000 when your friend buys 50GB of data.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: ((data?['progress_percent'] ?? 0) as num).toDouble() / 100.0,
                            backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_gbLabel((data?['total_accumulated_mb'] ?? 0) is int ? (data?['total_accumulated_mb'] ?? 0) as int : int.tryParse((data?['total_accumulated_mb'] ?? 0).toString()) ?? 0)} / ${_gbLabel(targetMb)} • $progressPercent%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Referral history',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (loading)
                    const _ReferralLoading()
                  else if (snapshot.hasError)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.1),
                        ),
                      ),
                      child: Text(
                        'Referral details are temporarily unavailable. Pull to refresh and try again.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted, height: 1.45),
                      ),
                    )
                  else if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.1),
                        ),
                      ),
                      child: Text(
                        'No referrals yet. Share your code to start earning once your friend begins buying data.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted, height: 1.45),
                      ),
                    )
                  else
                    ...items.whereType<Map>().map((raw) {
                      final item = raw.map((k, v) => MapEntry(k.toString(), v));
                      final status = (item['status'] ?? 'pending').toString();
                      final itemName = (item['referred_user_name'] ?? 'Referral').toString();
                      final accumulatedMb = int.tryParse((item['accumulated_mb'] ?? 0).toString()) ?? 0;
                      final itemTargetMb = int.tryParse((item['target_mb'] ?? targetMb).toString()) ?? targetMb;
                      final percent = int.tryParse((item['progress_percent'] ?? 0).toString()) ?? 0;
                      final reward = _money(item['reward_amount'] ?? rewardAmount);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: EdgeInsets.all(compact ? 14 : 16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.14 : 0.1),
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
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Code ${item['referral_code_used'] ?? '—'}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatusChip(label: status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: (percent.clamp(0, 100)) / 100.0,
                                  backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_gbLabel(accumulatedMb)} / ${_gbLabel(itemTargetMb)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    '$percent%',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reward $reward',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
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
        ),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
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
        color: color.withValues(alpha: 0.12),
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
