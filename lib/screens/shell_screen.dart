import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'services_screen.dart';
import 'history_screen.dart';
import 'transfer_screen.dart';
import 'profile_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  static const String route = '/app';

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  void _goToTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _goToTab),
      const ServicesScreen(),
      const TransferScreen(),
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
              icon: Icon(Icons.send_outlined),
              selectedIcon: Icon(Icons.send_rounded),
              label: 'Transfer',
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
