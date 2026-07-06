import 'dart:async';
import '../utils/fast_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/session.dart';
import '../widgets/concentric_circles_bg.dart';
import '../services/biometric_service.dart';
import 'welcome_screen.dart';
import 'support_screen.dart';
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
  Timer? _toastTimer;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndTriggerBiometrics();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _errorMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _errorMessage = null);
    });
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
      reason: 'Sign in to MELE DATA',
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _biometricLoading = false);
      _showToast('Biometric authentication canceled.');
      return;
    }

    final session = context.read<SessionController>();
    final ok = await session.loginWithBiometrics();

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    } else {
      setState(() => _biometricLoading = false);
      _showToast(session.error ?? 'Please tap "Use Password".');
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          ConcentricCirclesBg(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed(WelcomeScreen.route),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            FastRoute(page: const SupportScreen()),
                          );
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
                
                Expanded(
                  child: Center(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Icon Header
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset('assets/brand/meledata-icon.png'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Main Glowing Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // User Info
                              Text(
                                fullName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (maskedId.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  maskedId,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 32),
                              
                              // Biometric Scanner
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: GestureDetector(
                                  onTap: _biometricLoading ? null : _verifyBiometrics,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primaryColor.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: _biometricLoading 
                                        ? const SizedBox(
                                            width: 30, height: 30, 
                                            child: CircularProgressIndicator(strokeWidth: 2.5)
                                          )
                                        : Icon(
                                            Icons.fingerprint_rounded,
                                            size: 44,
                                            color: primaryColor,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              Text(
                                'Tap to authenticate',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Bottom Actions
                        Row(
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
                                'Use Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Absolute Top Auto-Dismiss Error Toast
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            top: _errorMessage != null ? MediaQuery.of(context).padding.top + 16 : -150,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F1921) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: isDark ? 0.4 : 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage ?? '',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
