import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/primary_button.dart';
import '../services/biometric_service.dart';
import 'welcome_screen.dart';
import 'shell_screen.dart';

class QuickAuthScreen extends StatefulWidget {
  const QuickAuthScreen({super.key});
  static const String route = '/quick-auth';

  @override
  State<QuickAuthScreen> createState() => _QuickAuthScreenState();
}

class _QuickAuthScreenState extends State<QuickAuthScreen> with SingleTickerProviderStateMixin {
  bool _biometricLoading = false;
  String? _errorMessage;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Auto-trigger biometric scan on entry if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndTriggerBiometrics();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _checkAndTriggerBiometrics() async {
    final enabled = await BiometricService.isAppLockEnabled;
    if (enabled) {
      _verifyBiometrics();
    }
  }

  Future<void> _verifyBiometrics() async {
    setState(() {
      _biometricLoading = true;
      _errorMessage = null;
    });

    final success = await BiometricService.authenticate(
      reason: 'Sign in to AxisVTU',
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _biometricLoading = false;
        _errorMessage = 'Biometric authentication canceled.';
      });
      return;
    }

    final session = context.read<SessionController>();
    final ok = await session.loginWithBiometrics();

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    } else {
      setState(() {
        _biometricLoading = false;
        _errorMessage = session.error ?? 'Please tap "Log in with Password".';
      });
    }
  }

  void _handleSwitchAccount() async {
    final session = context.read<SessionController>();
    await session.clearLastUser();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(WelcomeScreen.route);
  }

  void _handleLoginWithPassword() {
    final session = context.read<SessionController>();
    final lastUser = session.lastUser;
    final email = lastUser?['email'] ?? lastUser?['phone'] ?? '';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(initialIdentifier: email),
      ),
    );
  }

  String _maskIdentifier(Map<String, dynamic> user) {
    final phone = (user['phone_number'] ?? user['phone'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final identifier = phone.isNotEmpty ? phone : email;

    if (identifier.isEmpty) return '';

    if (identifier.contains('@')) {
      final parts = identifier.split('@');
      final name = parts[0];
      if (name.length <= 2) return '$name***@${parts[1]}';
      return '${name.substring(0, 2)}***@${parts[1]}';
    } else {
      if (identifier.length <= 4) return identifier;
      final start = identifier.substring(0, 3);
      final end = identifier.substring(identifier.length - 3);
      return '$start***$end';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.lastUser ?? {};
    final fullName = (user['full_name'] ?? user['name'] ?? 'User').toString().toUpperCase();
    final maskedId = _maskIdentifier(user);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: AuthBackdrop(
        showBrandText: false,
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed(WelcomeScreen.route),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        launchUrl(Uri.parse('mailto:mmtechglobe@gmail.com?subject=AxisVTU%20Support%20Request'));
                      },
                      child: Text(
                        'Help',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Brand Logo (Glowing AxisVTU Header)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.double_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AxisVTU',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // User Circular Profile (Initials Avatar in OPay style)
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName.substring(0, 1) : 'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (maskedId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '($maskedId)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(flex: 2),

              // Biometric Icon Container (OPay Custom Neon Scanner Vector)
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _verifyBiometrics,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 56,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Click to log in with Biometrics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Primary "Verify Face" Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: PrimaryButton(
                  label: _biometricLoading ? 'Verifying...' : 'Verify Biometrics',
                  loading: _biometricLoading,
                  icon: Icons.security_rounded,
                  isPremium: true,
                  onPressed: _biometricLoading ? null : _verifyBiometrics,
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Actions (Switch Account | Log in with Password)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _handleSwitchAccount,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      child: const Text(
                        'Switch Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    TextButton(
                      onPressed: _handleLoginWithPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      child: const Text(
                        'Log in with Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
