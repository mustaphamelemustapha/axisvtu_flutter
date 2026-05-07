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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;

    final services = [
      _ServiceItem(
        label: 'Buy Data',
        subtitle: 'MTN, Glo, Airtel & 9mobile',
        icon: Icons.wifi_rounded,
        accent: const Color(0xFF3B82F6),
        onTap: () => _openScreen(context, const DataScreen()),
      ),
      _ServiceItem(
        label: 'Airtime',
        subtitle: 'Instant mobile top-up',
        icon: Icons.phone_iphone_rounded,
        accent: const Color(0xFF10B981),
        onTap: () => _openScreen(context, const AirtimeScreen()),
      ),
      _ServiceItem(
        label: 'Electricity',
        subtitle: 'Prepaid meter tokens',
        icon: Icons.bolt_rounded,
        accent: const Color(0xFFF59E0B),
        onTap: () => _openScreen(context, const ElectricityScreen()),
      ),
      _ServiceItem(
        label: 'Cable TV',
        subtitle: 'DSTV, GOTV & Startimes',
        icon: Icons.live_tv_rounded,
        accent: const Color(0xFF8B5CF6),
        onTap: () => _openScreen(context, const CableScreen()),
      ),
      _ServiceItem(
        label: 'Exam PINs',
        subtitle: 'WAEC, NECO & JAMB',
        icon: Icons.school_rounded,
        accent: const Color(0xFFEF4444),
        onTap: () => _openScreen(context, const ExamScreen()),
      ),
      _ServiceItem(
        label: 'Referrals',
        subtitle: 'Earn service rewards',
        icon: Icons.card_giftcard_rounded,
        accent: const Color(0xFFEC4899),
        onTap: () => _openScreen(context, const ReferralScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Services',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Digital Utility Services',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size.width < 430 ? 2 : 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: compact ? 140 : 154,
            ),
            itemBuilder: (context, index) {
              final item = services[index];
              return _ServiceCard(item: item);
            },
          ),
          const SizedBox(height: 24),
          _SupportCard(),
        ],
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
          color: isDark ? const Color(0xFF141C2A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(
              alpha: isDark ? 0.08 : 0.06,
            ),
          ),
          boxShadow: AxisShadows.softGlow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.accent, size: 24),
            ),
            const Spacer(),
            Text(
              item.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.headset_mic_rounded, size: 32, color: Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          Text(
            'Need assistance?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Our support team is available 24/7 to help with your utility service needs.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
