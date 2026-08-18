import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/biometric_service.dart';

class SummaryItem {
  final String label;
  final String value;
  final IconData icon;

  const SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class EpicPurchaseSummary extends StatefulWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color primaryColor;
  final IconData headerIcon;
  final List<SummaryItem> items;
  final FutureOr<void> Function() onProceedPin;
  final FutureOr<void> Function() onProceedBiometric;

  const EpicPurchaseSummary({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.primaryColor,
    required this.headerIcon,
    required this.items,
    required this.onProceedPin,
    required this.onProceedBiometric,
  });

  @override
  State<EpicPurchaseSummary> createState() => _EpicPurchaseSummaryState();
}

class _EpicPurchaseSummaryState extends State<EpicPurchaseSummary> {
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final enabled = await BiometricService.isAppLockEnabled;
    final availability = await BiometricService.getAvailability();
    if (mounted) {
      setState(() {
        _bioAvailable = enabled && availability.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.primaryColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border(
          top: BorderSide(
            color: primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 10,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient Glow Background
          Positioned(
            top: -50,
            left: -50,
            right: -50,
            height: 200,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Header Icon & Title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(widget.headerIcon, color: primary, size: 36)
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .shimmer(duration: const Duration(seconds: 2), color: Colors.white.withValues(alpha: 0.8)),
                ).animate().scale(duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ).animate().fade().slideY(begin: 0.2, duration: const Duration(milliseconds: 200)),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fade().slideY(begin: 0.2, duration: const Duration(milliseconds: 200)),
                
                const SizedBox(height: 36),
                
                // Hero Amount Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [const Color(0xFF1E293B).withValues(alpha: 0.7), const Color(0xFF0F172A).withValues(alpha: 0.7)]
                        : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.amount,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : primary,
                          letterSpacing: -1.5,
                          shadows: [
                            Shadow(
                              color: (isDark ? Colors.white : primary).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: const Duration(milliseconds: 50)).slideY(begin: 0.1, duration: const Duration(milliseconds: 200)),
                
                const SizedBox(height: 32),
                
                // Details List
                Column(
                  children: widget.items.asMap().entries.map((entry) {
                    return _PremiumSummaryItem(
                      label: entry.value.label,
                      value: entry.value.value,
                      icon: entry.value.icon,
                      isDark: isDark,
                    ).animate().fade(delay: Duration(milliseconds: 50 + (entry.key * 20))).slideX(begin: 0.1, duration: const Duration(milliseconds: 200));
                  }).toList(),
                ),
                
                const SizedBox(height: 48),
                
                // Modern Pay Button Block
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (_bioAvailable) {
                        widget.onProceedBiometric();
                      } else {
                        widget.onProceedPin();
                      }
                    },
                    icon: Icon(
                            _bioAvailable ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                            color: primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          ),
                    label: Text(
                      _bioAvailable ? 'Confirm with Biometrics' : 'Confirm & Pay with PIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      shadowColor: primary.withValues(alpha: 0.4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(duration: const Duration(seconds: 2), color: Colors.white.withValues(alpha: 0.5)),
                ).animate().fade(delay: const Duration(milliseconds: 400)).scale(begin: const Offset(0.95, 0.95)),
                
                if (_bioAvailable) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onProceedPin();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                    child: Text(
                      'Pay with PIN instead',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ).animate().fade(delay: const Duration(milliseconds: 500)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _PremiumSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
