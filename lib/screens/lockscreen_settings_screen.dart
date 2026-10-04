import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../services/biometric_service.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import 'package:local_auth/local_auth.dart';

import '../utils/fast_route.dart';
import '../services/api_client.dart';
import '../services/transaction_pin_service.dart';
import '../widgets/pin_entry_sheet.dart';
import 'change_pin_screen.dart';

class LockscreenSettingsScreen extends StatefulWidget {
  const LockscreenSettingsScreen({super.key});
  static const String route = '/lockscreen-settings';

  @override
  State<LockscreenSettingsScreen> createState() => _LockscreenSettingsScreenState();
}

class _LockscreenSettingsScreenState extends State<LockscreenSettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final bioEnabled = await BiometricService.isAppLockEnabled;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bioEnabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_biometricBusy) return;
    final session = context.read<SessionController>();
    
    // If they want to disable it
    if (!value) {
      setState(() => _biometricBusy = true);
      try {
        await BiometricService.setAppLockEnabled(false);
        await BiometricService.deletePin();
        await session.disableBiometrics();
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock disabled.')),
        );
      } finally {
        if (mounted) setState(() => _biometricBusy = false);
      }
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      final availability = await BiometricService.getAvailability();
      if (!availability.ready) {
        String message = 'Biometric unlock is not available on this device.';
        if (!availability.supported) {
          message = 'This device does not support biometrics or device screen lock.';
        } else if (!availability.canCheck || !availability.hasEnrolled) {
          message = 'No fingerprint/face is set. Add one in your phone settings, then try again.';
        } else if (availability.error != null && availability.error!.trim().isNotEmpty) {
          message = availability.error!.trim();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric unlock',
      );
      if (authenticated) {
        if (!mounted) return;
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
            await showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Text('Setup PIN first'),
                  content: const Text(
                    'You need a transaction PIN before you can use biometric unlock.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          FastRoute(page: const ChangePinScreen()),
                        );
                      },
                      child: const Text('Create PIN'),
                    ),
                  ],
                );
              },
            );
            return;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to verify PIN status: ${e.toString()}')),
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
        await BiometricService.setAppLockEnabled(true);
        await session.enableBiometrics();
        
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock enabled.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric verification was not completed. Try again.'),
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
    final session = context.watch<SessionController>();
    final isAppLockEnabled = session.securityPreference == 'max';
    final primaryColor = const Color(0xFF3B82F6); // Blue color from screenshot

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
                          'Lockscreen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  children: [
                    // Setting Card 1
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Require unlock to open MELE DATA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: isAppLockEnabled,
                            onChanged: (val) async {
                              final newPref = val ? 'max' : 'smart';
                              await session.setSecurityPreference(newPref);
                            },
                            activeColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 24),
                      child: Text(
                        'Lock MELE DATA every time you open it. Unlock with Face ID or your transaction PIN — the PIN works offline once you\'ve confirmed it once.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ),

                    // Setting Card 2 (Biometrics)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Unlock with Face ID',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _biometricEnabled,
                            onChanged: _biometricBusy ? null : _toggleBiometric,
                            activeColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
                      child: Text(
                        'Use Face ID to unlock instead of typing your PIN.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
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
