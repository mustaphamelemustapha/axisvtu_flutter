import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/session.dart';
import '../theme/axis_tokens.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../services/transaction_pin_service.dart';
import '../services/biometric_service.dart';
import '../widgets/pin_entry_sheet.dart';

import 'change_password_screen.dart';
import 'change_pin_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometricBusy = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final bioEnabled = await BiometricService.isAppLockEnabled;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bioEnabled;
    });
  }

  Future<void> _toggleBiometric() async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    try {
      final availability = await BiometricService.getAvailability();
      if (!availability.ready) {
        String message = 'Biometric unlock is not available on this device.';
        if (!availability.supported) {
          message =
              'This device does not support biometrics or device screen lock.';
        } else if (!availability.canCheck || !availability.hasEnrolled) {
          message =
              'No fingerprint/face is set. Add one in your phone settings, then try again.';
        } else if (availability.error != null &&
            availability.error!.trim().isNotEmpty) {
          message = availability.error!.trim();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      if (_biometricEnabled) {
        final session = context.read<SessionController>();
        setState(() => _biometricEnabled = false);
        await BiometricService.setAppLockEnabled(false);
        await BiometricService.deletePin();
        await session.disableBiometrics();
        return;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric unlock',
      );
      if (authenticated) {
        if (!mounted) return;
        final session = context.read<SessionController>();
        final token = (session.token ?? '').trim();
        if (token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please log in again.')),
          );
          return;
        }

        final pinService = TransactionPinService(token: token);

        try {
          final status = await pinService.status();
          if (!status.isSet) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please create a transaction PIN in settings first.'),
              ),
            );
            return;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to verify PIN status: ${e.toString()}'),
            ),
          );
          return;
        }

        if (!mounted) return;

        final pin = await PinEntrySheet.show(
          context,
          title: 'Enter Transaction PIN',
          subtitle: 'Verify your PIN to secure biometric purchases.',
          confirmLabel: 'Verify',
          pinLength: 4,
          onSubmit: (val) async {
            try {
              await pinService.verify(val);
              return null; // success
            } on ApiException catch (e) {
              if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 423 || e.statusCode == 429) {
                return 'Incorrect PIN, try again.';
              }
              return e.message;
            } catch (e) {
              return e.toString();
            }
          },
        );

        if (pin == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric activation cancelled.')),
          );
          return;
        }

        await BiometricService.savePin(pin);

        setState(() => _biometricEnabled = true);
        await BiometricService.setAppLockEnabled(true);
        // Also save the token specifically for biometrics so it persists after logout
        await session.enableBiometrics();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock enabled.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric verification was not completed. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 24),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Security Center',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Text(
                        'Access & Authentication',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569), // Slate 600
                        ),
                      ),
                    ),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          _SecurityTile(
                            icon: Icons.password_rounded,
                            title: 'Change Password',
                            subtitle: 'Update your account login password',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16),
                          _SecurityTile(
                            icon: Icons.dialpad_rounded,
                            title: 'Change MELE DATA PIN',
                            subtitle: 'Update your 4-digit transaction PIN',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChangePinScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Text(
                        'Device Security',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569), // Slate 600
                        ),
                      ),
                    ),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _SecurityTile(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometric Unlock',
                        subtitle: 'Use Face ID or Fingerprint to authorize',
                        trailing: Switch.adaptive(
                          value: _biometricEnabled, 
                          onChanged: _biometricBusy ? null : (_) => _toggleBiometric(), 
                          activeColor: Theme.of(context).colorScheme.primary
                        ),
                        onTap: _toggleBiometric,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}
