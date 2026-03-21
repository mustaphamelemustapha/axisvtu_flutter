import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/session.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
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
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            routes: {
              WelcomeScreen.route: (_) => const WelcomeScreen(),
              LoginScreen.route: (_) => const LoginScreen(),
              RegisterScreen.route: (_) => const RegisterScreen(),
              ShellScreen.route: (_) => const ShellScreen(),
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.isAuthenticated) {
      return const ShellScreen();
    }
    return const WelcomeScreen();
  }
}

// Theme now lives in lib/theme/app_theme.dart
