import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../widgets/concentric_circles_bg.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/transaction_pin_service.dart';

class SlateColors {
  static const Color slate = Color(0xFF64748B);
  static const Color shade50 = Color(0xFFF8FAFC);
  static const Color shade100 = Color(0xFFF1F5F9);
  static const Color shade200 = Color(0xFFE2E8F0);
  static const Color shade300 = Color(0xFFCBD5E1);
  static const Color shade400 = Color(0xFF94A3B8);
  static const Color shade500 = Color(0xFF64748B);
  static const Color shade600 = Color(0xFF475569);
  static const Color shade700 = Color(0xFF334155);
  static const Color shade900 = Color(0xFF0F172A);
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _pinCode = '';
  bool _checkingBiometrics = false;
  bool _hasBiometrics = false;
  bool _isVerifyingPin = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.didChangeDependencies();
    super.initState();
    
    // Set up shake animation for incorrect PIN feedback
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = _ShakeTween(begin: 0.0, end: 24.0)
        .animate(_shakeController);

    _checkAndTriggerBiometrics();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndTriggerBiometrics() async {
    final bioEnabled = await BiometricService.isAppLockEnabled;
    final availability = await BiometricService.getAvailability();
    if (bioEnabled && availability.ready) {
      setState(() {
        _hasBiometrics = true;
      });
      // Automatically trigger biometrics without asking
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometrics();
      });
    }
  }

  Future<void> _triggerBiometrics() async {
    if (_checkingBiometrics) return;
    setState(() {
      _checkingBiometrics = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService.authenticate(
        reason: 'Authenticate to unlock MELE DATA',
      );
      if (success && mounted) {
        final session = context.read<SessionController>();
        final ok = await session.loginWithBiometrics();
        if (mounted) {
          if (ok) {
            session.unlock();
          } else {
            setState(() => _errorMessage = 'Session expired. Tap "Use Password" to log in again.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Biometric authentication failed or is unavailable.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingBiometrics = false;
        });
      }
    }
  }

  void _handleKeyPress(String value) {
    if (_isVerifyingPin || _pinCode.length >= 4) return;

    setState(() {
      _pinCode += value;
      _errorMessage = null;
    });

    if (_pinCode.length == 4) {
      _verifyPinCode();
    }
  }

  void _handleBackspace() {
    if (_isVerifyingPin || _pinCode.isEmpty) return;
    setState(() {
      _pinCode = _pinCode.substring(0, _pinCode.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPinCode() async {
    setState(() {
      _isVerifyingPin = true;
    });

    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();

    try {
      // 1. Instant Local Verification
      final cachedPin = await BiometricService.getPin();
      if (cachedPin != null && cachedPin == _pinCode) {
        final ok = await session.loginWithBiometrics();
        if (mounted) {
          if (ok) {
            session.unlock();
          } else {
            setState(() {
              _errorMessage = 'Session expired. Tap "Use Password" to log in again.';
              _isVerifyingPin = false;
              _pinCode = '';
            });
          }
        }
        return;
      }

      // 2. Fallback Network Verification
      final service = TransactionPinService(token: token);
      await service.verify(_pinCode);
      
      // If network verification succeeds, cache the correct PIN for future instant logins
      await BiometricService.savePin(_pinCode);
      
      if (mounted) {
        session.unlock();
      }
    } catch (e) {
      if (mounted) {
        String err = 'Incorrect PIN, try again.';
        if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
          err = 'Session expired. Tap "Use Password" to log in again.';
        }
        setState(() {
          _pinCode = '';
          _isVerifyingPin = false;
          _errorMessage = err;
        });
        _shakeController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 60),
                          
                          // Logo matching Amigo's rounded square
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isDark ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Hero(
                                  tag: 'axis-logo',
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 44,
                                    height: 44,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main Lock Title
                          Text(
                            'MELE DATA is locked',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              color: isDark ? Colors.white : SlateColors.shade900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          // Subtitle or Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.colorScheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Enter your PIN to unlock.',
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark ? SlateColors.shade400 : SlateColors.shade500,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                          const SizedBox(height: 32),

                          // PIN Indicator Dots with Shake Animation
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0.0),
                                child: child,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) {
                                final active = index < _pinCode.length;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? (isDark ? Colors.white : SlateColors.shade900)
                                        : (isDark ? Colors.white24 : SlateColors.shade200),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),

                      // Keypad section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _KeypadButton(number: '1', onTap: () => _handleKeyPress('1')),
                                _KeypadButton(number: '2', onTap: () => _handleKeyPress('2')),
                                _KeypadButton(number: '3', onTap: () => _handleKeyPress('3')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _KeypadButton(number: '4', onTap: () => _handleKeyPress('4')),
                                _KeypadButton(number: '5', onTap: () => _handleKeyPress('5')),
                                _KeypadButton(number: '6', onTap: () => _handleKeyPress('6')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _KeypadButton(number: '7', onTap: () => _handleKeyPress('7')),
                                _KeypadButton(number: '8', onTap: () => _handleKeyPress('8')),
                                _KeypadButton(number: '9', onTap: () => _handleKeyPress('9')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Biometric Action button
                                _KeypadIconButton(
                                  icon: Icons.face_retouching_natural_rounded,
                                  color: const Color(0xFF3B82F6),
                                  onTap: _hasBiometrics ? _triggerBiometrics : null,
                                ),
                                _KeypadButton(number: '0', onTap: () => _handleKeyPress('0')),
                                // Delete / Backspace button
                                _KeypadIconButton(
                                  icon: Icons.backspace_outlined,
                                  onTap: _handleBackspace,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Bottom Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: TextButton(
                          onPressed: () {
                            context.read<SessionController>().logout();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white54 : SlateColors.shade500,
                          ),
                          child: Text(
                            'Sign out instead',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Shake animation tween for incorrect PIN entry feedback
class _ShakeTween extends Tween<double> {
  _ShakeTween({super.begin, super.end});
  @override
  double lerp(double t) {
    return begin! + (end! - begin!) * math.sin(t * 3 * math.pi);
  }
}

// Custom Glass-style Numeric Keypad Button
class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.number,
    required this.onTap,
  });

  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : SlateColors.shade900,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Glass-style Keypad Icon Button (For Backspace & Biometric trigger)
class _KeypadIconButton extends StatelessWidget {
  const _KeypadIconButton({
    required this.icon,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (onTap == null) {
      return const SizedBox(width: 82, height: 82);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 82,
        height: 82,
        child: Center(
          child: Icon(
            icon,
            size: 32,
            color: color ?? (isDark ? Colors.white54 : SlateColors.shade600),
          ),
        ),
      ),
    );
  }
}
