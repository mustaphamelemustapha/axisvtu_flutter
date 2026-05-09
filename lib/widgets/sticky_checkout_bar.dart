import 'package:flutter/material.dart';
import '../theme/axis_tokens.dart';

class StickyCheckoutBar extends StatelessWidget {
  const StickyCheckoutBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.active,
    required this.loading,
    required this.onBuy,
    this.actionLabel = 'Buy Now',
    this.icon = Icons.shopping_cart_rounded,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool active;
  final bool loading;
  final VoidCallback? onBuy;
  final String actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(compact ? 8 : 10, 0, compact ? 8 : 10, 10),
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 8 : 9,
          compact ? 10 : 12,
          compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1522) : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06)),
          boxShadow: AxisShadows.softGlow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.78),
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.54),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: compact ? 130 : 154,
              height: compact ? 44 : 50,
              child: FilledButton.icon(
                onPressed: active && !loading ? onBuy : null,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, size: 18),
                label: Text(
                  loading ? 'Please wait...' : actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangle.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectangle {
  static RoundedRectangleBorder get md => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AxisRadii.md),
      );
}
