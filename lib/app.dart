import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/session.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/reset_pin_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/welcome_screen.dart';

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
              WelcomeScreen.route: (_) => const WelcomeScreen(),
              LoginScreen.route: (_) => const LoginScreen(),
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

class AppEntryGate extends StatelessWidget {
  const AppEntryGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final path = uri.path.toLowerCase();
    if (token != null && token.isNotEmpty) {
      if (path.contains('reset-pin')) {
        return ResetPinScreen(token: token);
      }
      if (path.contains('reset-password')) {
        return ResetPasswordScreen(token: token);
      }
    }

    final session = context.watch<SessionController>();
    if (session.isAuthenticated) {
      return const ShellScreen();
    }
    return const WelcomeScreen();
  }
}

// Theme now lives in lib/theme/app_theme.dart
