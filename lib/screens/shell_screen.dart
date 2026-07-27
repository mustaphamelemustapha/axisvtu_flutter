import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_screen.dart';
import 'services_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../state/session.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  static const String route = '/app';

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  bool _hasShownUpdatePrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      session.addListener(_onSessionChanged);
      _checkOptionalUpdate();
    });
  }

  @override
  void dispose() {
    // Note: Provider automatically handles cleanup if not accessing from context directly,
    // but doing it safely requires accessing the read carefully. It's safer to not remove it 
    // here since ShellScreen is the root.
    super.dispose();
  }

  void _onSessionChanged() {
    _checkOptionalUpdate();
  }

  void _checkOptionalUpdate() {
    if (!mounted || _hasShownUpdatePrompt) return;
    
    final session = context.read<SessionController>();
    if (session.optionalUpdateAvailable) {
      _hasShownUpdatePrompt = true;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Available'),
          content: const Text(
            'A new version of MELE DATA is available. Update now to enjoy the latest features and improvements.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final url = Platform.isIOS ? session.appStoreUrl : session.playStoreUrl;
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    }
  }

  void _goToTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _goToTab),
      const ServicesScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          elevation: 0,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            _goToTab(value);
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Services',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
