import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/transaction_pin_service.dart';
import '../state/session.dart';
import '../widgets/auth_liquid_glass.dart';
import '../widgets/state_select_sheet.dart';
import 'shell_screen.dart';

class SetPinScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const SetPinScreen({
    super.key,
    this.onCompleted,
  });

  static const String route = '/set-pin';

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSetPin() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = 'PIN must be exactly 4 digits');
      _shakeKey.currentState?.shake();
      return;
    }

    if (pin != confirm) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = 'PINs do not match. Please verify.');
      _shakeKey.currentState?.shake();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final session = context.read<SessionController>();
    final token = session.token;

    if (token == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Session expired. Please log in again.';
      });
      return;
    }

    try {
      await TransactionPinService(token: token).setup(
        pin: pin,
        confirmPin: confirm,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _navigateNext();
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().toLowerCase();

      // Treat 409 "already set" as success
      if (err.contains('409') || err.contains('already set')) {
        HapticFeedback.mediumImpact();
        _navigateNext();
        return;
      }

      HapticFeedback.heavyImpact();
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to set PIN. Please check your network and try again.';
      });
      _shakeKey.currentState?.shake();
    }
  }

  void _navigateNext() {
    final session = context.read<SessionController>();
    final user = session.user;
    final state = user?['state'];

    if (state == null || state.toString().trim().isEmpty) {
      StateSelectBottomSheet.show(context, onCompleted: () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(ShellScreen.route, (_) => false);
      });
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(ShellScreen.route, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Icon Header
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Your\nTransaction PIN',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.18,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A 4-digit PIN is required to authorize data purchases and wallet withdrawals.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                ShakeWidget(
                  key: _shakeKey,
                  child: LiquidGlassPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTER 4-DIGIT PIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0A101D) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: TextField(
                            controller: _pinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: _obscurePin,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: 10,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                                letterSpacing: 8,
                              ),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePin = !_obscurePin),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'CONFIRM 4-DIGIT PIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0A101D) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: TextField(
                            controller: _confirmPinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: _obscureConfirm,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: 10,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                                letterSpacing: 8,
                              ),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.white54,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFF43F5E),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFF43F5E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleSetPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2457F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save PIN & Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
