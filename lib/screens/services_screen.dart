import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data_screen.dart';
import 'airtime_screen.dart';
import 'electricity_screen.dart';
import 'cable_screen.dart';
import 'exam_screen.dart';
import 'referral_screen.dart';
import '../theme/axis_tokens.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Services Hub',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 24),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SectionHeader(
            title: 'Mobile Services',
            subtitle: 'Data bundles and airtime top-up',
            isDark: isDark,
          ),
          _ServiceGrid(
            items: [
              _ServiceItem(
                label: 'Buy Data',
                subtitle: 'MTN, Glo, Airtel, 9mobile',
                icon: Icons.wifi_rounded,
                accent: const Color(0xFF2457F5),
                onTap: () => _openScreen(context, const DataScreen()),
              ),
              _ServiceItem(
                label: 'Airtime',
                subtitle: 'Instant mobile recharge',
                icon: Icons.phone_iphone_rounded,
                accent: const Color(0xFF10B8A6),
                onTap: () => _openScreen(context, const AirtimeScreen()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Utility Subscriptions',
            subtitle: 'Electricity and Cable TV services',
            isDark: isDark,
          ),
          _ServiceGrid(
            items: [
              _ServiceItem(
                label: 'Electricity',
                subtitle: 'Prepaid meter tokens',
                icon: Icons.bolt_rounded,
                accent: const Color(0xFFF59E0B),
                onTap: () => _openScreen(context, const ElectricityScreen()),
              ),
              _ServiceItem(
                label: 'Cable TV',
                subtitle: 'DSTV, GOTV, Startimes',
                icon: Icons.live_tv_rounded,
                accent: const Color(0xFF8B5CF6),
                onTap: () => _openScreen(context, const CableScreen()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Educational & Rewards',
            subtitle: 'Exam results and rewards',
            isDark: isDark,
          ),
          _ServiceGrid(
            items: [
              _ServiceItem(
                label: 'Exam PINs',
                subtitle: 'WAEC, NECO, JAMB',
                icon: Icons.school_rounded,
                accent: const Color(0xFFEF4444),
                onTap: () => _openScreen(context, const ExamScreen()),
              ),
              _ServiceItem(
                label: 'Referrals',
                subtitle: 'Invite & earn rewards',
                icon: Icons.card_giftcard_rounded,
                accent: const Color(0xFFEC4899),
                onTap: () => _openScreen(context, const ReferralScreen()),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _SupportCard(isDark: isDark),
        ],
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.isDark});
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.items});
  final List<_ServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 154,
      ),
      itemBuilder: (context, index) => _ServiceCard(item: items[index]),
    );
  }
}

class _ServiceItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  _ServiceItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0xFF08101F) : const Color(0xFFCBD5E1).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(item.icon, color: item.accent, size: 24),
            ),
            const Spacer(),
            Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2457F5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headset_mic_rounded, size: 32, color: Color(0xFF2457F5)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Need assistance?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Our support team is available 24/7 to help with any issues or inquiries.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
