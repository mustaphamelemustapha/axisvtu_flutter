import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data_screen.dart';
import 'airtime_screen.dart';
import 'electricity_screen.dart';
import 'cable_screen.dart';
import 'exam_screen.dart';
import 'referral_screen.dart';
import 'wallet_screen.dart';
import 'senior_men_board_screen.dart';
import 'transfer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/concentric_circles_bg.dart';
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ConcentricCirclesBg(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Services Hub',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 8),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      label: 'Buy Data',
                      icon: Icons.wifi_rounded,
                      accent: const Color(0xFF2457F5),
                      onTap: () => _openScreen(context, const DataScreen()),
                    ),
                    _ServiceItem(
                      label: 'Airtime',
                      icon: Icons.phone_iphone_rounded,
                      accent: const Color(0xFF10B8A6),
                      onTap: () => _openScreen(context, const AirtimeScreen()),
                    ),
                    _ServiceItem(
                      label: 'Electricity',
                      icon: Icons.bolt_rounded,
                      accent: const Color(0xFFF59E0B),
                      onTap: () => _openScreen(context, const ElectricityScreen()),
                    ),
                    _ServiceItem(
                      label: 'Transfer',
                      icon: Icons.send_rounded,
                      accent: const Color(0xFF14B8A6),
                      onTap: () => _openScreen(context, const TransferScreen()),
                    ),
                    _ServiceItem(
                      label: 'Cable TV',
                      icon: Icons.live_tv_rounded,
                      accent: const Color(0xFF8B5CF6),
                      onTap: () => _openScreen(context, const CableScreen()),
                    ),
                    _ServiceItem(
                      label: 'Exam PINs',
                      icon: Icons.school_rounded,
                      accent: const Color(0xFFEF4444),
                      onTap: () => _openScreen(context, const ExamScreen()),
                    ),
                    _ServiceItem(
                      label: 'Senior Men',
                      icon: Icons.emoji_events_rounded,
                      accent: const Color(0xFFEA580C),
                      onTap: () => _openScreen(context, const SeniorMenBoardScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _ReferralBanner(
                  onTap: () => _openScreen(context, const ReferralScreen()),
                ),
                const SizedBox(height: 32),
                _SupportCard(isDark: isDark),
              ],
            ),
          ),
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
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) => _ServiceCard(item: items[index]),
    );
  }
}

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  _ServiceItem({
    required this.label,
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
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.accent, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner({required this.onTap});
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invite & Earn',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get rewarded for every friend you invite.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.isDark});
  final bool isDark;

  Future<void> _launchSupport(BuildContext context) async {
    final phone = '+2348141114647';
    final url = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

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
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _launchSupport(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2457F5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2457F5).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Chat on WhatsApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
