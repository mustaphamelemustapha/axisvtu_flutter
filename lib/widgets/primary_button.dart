import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/axis_tokens.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.compact = false,
    this.isPremium = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool compact;
  final bool isPremium;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handlePress() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = widget.backgroundColor ?? theme.colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: Listener(
        onPointerDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel: _enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: AxisDurations.fast,
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              gradient: _enabled
                  ? (widget.isPremium
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF4F46E5),
                            Color(0xFFF97316),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : LinearGradient(
                          colors: [
                            primary,
                            primary.withValues(alpha: 0.82),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ))
                  : null,
              color: _enabled ? null : theme.disabledColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AxisRadii.lg),
              boxShadow: [
                if (_enabled)
                  BoxShadow(
                    color: (widget.isPremium ? const Color(0xFFF97316) : primary)
                        .withValues(alpha: isDark ? 0.28 : 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _enabled ? _handlePress : null,
              icon: widget.loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.foregroundColor ?? Colors.white,
                        ),
                      ),
                    )
                  : Icon(widget.icon ?? Icons.arrow_forward_rounded, size: 20),
              label: Text(widget.label),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: widget.foregroundColor ?? Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: widget.compact ? 12 : 16,
                ),
                minimumSize: Size.fromHeight(widget.compact ? 48 : 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AxisRadii.lg),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
