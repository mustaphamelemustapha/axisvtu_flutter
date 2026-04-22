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
            routes: {
              '/splash': (_) => const SplashScreen(),
              WelcomeScreen.route: (_) => const WelcomeScreen(),
              RegisterScreen.route: (_) => const RegisterScreen(),
              ShellScreen.route: (_) => const ShellScreen(),
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
    _loadOnboardingSeen();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingDone = prefs.getBool(OnboardingScreen.seenKey) ?? false;
      _onboardingLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final flow = (uri.queryParameters['flow'] ?? uri.queryParameters['kind'] ?? '').toLowerCase();
    final resetFlag = (uri.queryParameters['reset'] ?? '').toLowerCase();
    final path = uri.path.toLowerCase();
    if (token != null && token.isNotEmpty) {
      if (flow == 'pin' ||
          resetFlag == '1' ||
          resetFlag == 'pin' ||
          path.contains('reset-pin')) {
        return ResetPinScreen(token: token);
      }
      if (flow == 'password' || path.contains('reset-password')) {
        return ResetPasswordScreen(token: token);
      }
    }

    final session = context.watch<SessionController>();
    if (!session.isBootstrapped || !_splashDone) {
      return const SplashScreen();
    }
    if (session.isAuthenticated) {
      return const ShellScreen();
    }
    if (!_onboardingLoaded) {
      return const SplashScreen();
    }
    if (!_onboardingDone) {
      return const OnboardingScreen();
    }
    return const WelcomeScreen();
  }
}

// Theme now lives in lib/theme/app_theme.dart
