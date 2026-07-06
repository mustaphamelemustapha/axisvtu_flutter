import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

class EpicReceiptModal extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String amount;
  final Color primaryColor;
  final Map<String, String> details;
  final VoidCallback onSave;

  const EpicReceiptModal({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.amount,
    required this.primaryColor,
    required this.details,
    required this.onSave,
  });

  @override
  State<EpicReceiptModal> createState() => _EpicReceiptModalState();
}

class _EpicReceiptModalState extends State<EpicReceiptModal> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -60,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isSuccess ? Icons.check_rounded : Icons.close_rounded,
                        size: 64,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 110, 28, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isSuccess ? 'Transaction Successful' : 'Transaction Failed',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ).animate().fade().slideY(begin: 0.2, duration: const Duration(milliseconds: 400)),
                const SizedBox(height: 8),
                Text(
                  widget.isSuccess 
                      ? 'Your request has been processed successfully.'
                      : 'We encountered an issue processing your request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fade(delay: const Duration(milliseconds: 100)).slideY(begin: 0.2),
                
                const SizedBox(height: 32),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.amount,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: widget.isSuccess ? widget.primaryColor : const Color(0xFFEF4444),
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: const Duration(milliseconds: 200)).scale(begin: const Offset(0.95, 0.95)),
                
                const SizedBox(height: 24),
                
                _SuccessToggle(
                  isExpanded: _showDetails,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showDetails = !_showDetails);
                  },
                ).animate().fade(delay: const Duration(milliseconds: 300)),
                
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: widget.details.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ReceiptRow(label: entry.key, value: entry.value, isDark: isDark),
                        );
                      }).toList(),
                    ),
                  ),
                  crossFadeState: _showDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 400),
                  sizeCurve: Curves.easeOutCubic,
                ),
                
                const SizedBox(height: 48),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isSuccess) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSave();
                          },
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Share Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            elevation: 4,
                            shadowColor: widget.primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ).animate().fade(delay: const Duration(milliseconds: 400)).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessToggle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _SuccessToggle({required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Transaction Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ReceiptRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

class EpicShareableReceipt extends StatelessWidget {
  final bool ok;
  final String title;
  final String amount;
  final Map<String, String> details;
  final Color primaryColor;

  const EpicShareableReceipt({
    super.key,
    required this.ok,
    required this.title,
    required this.amount,
    required this.details,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = ok ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    return RepaintBoundary(
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: color,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    ok ? 'Payment Successful' : 'Payment Failed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // ZigZag Divider
            SizedBox(
              height: 20,
              width: double.infinity,
              child: CustomPaint(
                painter: _ZigZagPainter(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  isDark: isDark,
                ),
              ),
            ),
            
            // Details Section
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  ...details.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _ReceiptTableItem(label: entry.key, value: entry.value, isDark: isDark),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  // Footer branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by MELE DATA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptTableItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ReceiptTableItem({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  _ZigZagPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.2 : 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(0, 0);
    
    const double zigZagWidth = 10.0;
    const double zigZagHeight = 10.0;
    
    for (double i = 0; i < size.width; i += zigZagWidth) {
      path.lineTo(i + zigZagWidth / 2, zigZagHeight);
      path.lineTo(i + zigZagWidth, 0);
    }
    
    path.lineTo(size.width, -size.height);
    path.lineTo(0, -size.height);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
