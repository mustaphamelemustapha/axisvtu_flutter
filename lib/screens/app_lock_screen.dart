import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/glass_card.dart';
import '../services/purchase_auth_service.dart';
import '../services/biometric_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _checkingBiometrics = false;
  bool _hasBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkAndTriggerBiometrics();
  }

  Future<void> _checkAndTriggerBiometrics() async {
    final bioEnabled = await BiometricService.isAppLockEnabled;
    final availability = await BiometricService.getAvailability();
    if (bioEnabled && availability.ready) {
      setState(() {
        _hasBiometrics = true;
      });
      // Trigger biometrics automatically after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometrics();
      });
    }
  }

  Future<void> _triggerBiometrics() async {
    if (_checkingBiometrics) return;
    setState(() {
      _checkingBiometrics = true;
    });

    try {
      final success = await BiometricService.authenticate(
        reason: 'Authenticate to unlock AxisVTU',
      );
      if (success && mounted) {
        context.read<SessionController>().unlock();
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingBiometrics = false;
        });
      }
    }
  }

  Future<void> _unlockWithPin() async {
    final result = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'unlock',
      preferredMethod: PurchaseAuthService.methodPin,
    );
    if (result == true && mounted) {
      context.read<SessionController>().unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: AuthBackdrop(
        showBrandText: false,
        child: Column(
          children: [
            // Premium Header with Brand Title & Theme Toggle
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0E1624)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/brand/axisvtu-icon.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AxisVTU',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ThemeToggleButton(size: 40),
                  ],
                ),
              ),
            ),
            
            // Lock Card Area
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Glowing Circular Security Ring
                          Center(
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_person_rounded,
                                    size: 36,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Header text
                          Text(
                            'App Locked',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verify your identity or enter your secure transaction PIN to resume your session.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Primary Actions
                          if (_hasBiometrics) ...[
                            ElevatedButton.icon(
                              onPressed: _triggerBiometrics,
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: const Text(
                                'Unlock with Biometrics',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                height: 50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _unlockWithPin,
                              icon: const Icon(Icons.pin_outlined),
                              label: const Text(
                                'Unlock with PIN',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                height: 50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: _unlockWithPin,
                              icon: const Icon(Icons.key_rounded),
                              label: const Text(
                                'Unlock App',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                height: 50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 28),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          
                          // Switch account
                          TextButton(
                            onPressed: () {
                              context.read<SessionController>().logout();
                            },
                            child: Text(
                              'Switch Account / Sign Out',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
