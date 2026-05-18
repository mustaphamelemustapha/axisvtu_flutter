import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/session.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/reset_pin_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/force_update_screen.dart';
import 'screens/security_preference_screen.dart';
import 'screens/app_lock_screen.dart';

class AxisVTUApp extends StatelessWidget {
  const AxisVTUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: Builder(
        builder: (context) {
          final mode = context.watch<ThemeController>().mode;
          return MaterialApp(
            title: 'AxisVTU',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              // Use textScaleFactor for better compatibility
              final scale = media.textScaleFactor.clamp(0.95, 1.12);
              return MediaQuery(
                data: media.copyWith(textScaleFactor: scale),
                child: child ?? const SizedBox.shrink(),
              );
            },
            routes: {
              '/splash': (_) => const SplashScreen(),
              WelcomeScreen.route: (_) => const WelcomeScreen(),
               RegisterScreen.route: (_) => const RegisterScreen(),
              ShellScreen.route: (_) => const ShellScreen(),
              SecurityPreferenceScreen.route: (_) => const SecurityPreferenceScreen(),
            },
            home: const AppEntryGate(),
          );
        },
      ),
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool _splashDone = false;
  bool _onboardingDone = false;
  bool _onboardingLoaded = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _splashDone = true);
    });
    _loadInitialState();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarding = prefs.getBool(OnboardingScreen.seenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _onboardingDone = onboarding;
      _onboardingLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final flow =
        (uri.queryParameters['flow'] ?? uri.queryParameters['kind'] ?? '')
            .toLowerCase();
    final resetFlag = (uri.queryParameters['reset'] ?? '').toLowerCase();
    final path = uri.path.toLowerCase();
    if (token != null && token.isNotEmpty) {
      final isPinReset = flow == 'pin' ||
          resetFlag == '1' ||
          resetFlag == 'pin' ||
          path.contains('reset-pin') ||
          path.contains('pin/reset');

      if (isPinReset) {
        return ResetPinScreen(token: token);
      }

      final isPasswordReset = flow == 'password' ||
          path.contains('reset-password') ||
          path.contains('password/reset');

      if (isPasswordReset) {
        return ResetPasswordScreen(token: token);
      }
    }

    final session = context.watch<SessionController>();
    if (!session.isBootstrapped || !_splashDone || !_onboardingLoaded) {
      return const SplashScreen();
    }

    if (session.updateRequired) {
      return ForceUpdateScreen(
        playStoreUrl: session.playStoreUrl,
        appStoreUrl: session.appStoreUrl,
      );
    }

    if (session.isAuthenticated) {
      if (session.isLocked) {
        return const AppLockScreen();
      }
      if (!session.hasSecurityPreference) {
        return const SecurityPreferenceScreen();
      }
      return const ShellScreen();
    }

    if (!_onboardingDone) {
      return const OnboardingScreen();
    }
    return const WelcomeScreen();
  }
}

// Theme now lives in lib/theme/app_theme.dart
