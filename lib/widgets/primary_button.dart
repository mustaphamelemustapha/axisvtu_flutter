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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

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
    return SizedBox(
      width: double.infinity,
      child: Listener(
        onPointerDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel: _enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AxisDurations.fast,
          curve: Curves.easeOut,
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
              backgroundColor: widget.backgroundColor ?? theme.colorScheme.primary,
              foregroundColor: widget.foregroundColor ?? Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AxisRadii.lg),
              ),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontSize: 16,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              ),
              elevation: 0,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.18),
              surfaceTintColor: Colors.transparent,
              animationDuration: AxisDurations.normal,
            ),
          ),
        ),
      ),
    );
  }
}
