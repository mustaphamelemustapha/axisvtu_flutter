import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/app_header.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user ?? {};
    final name = user['full_name'] ?? user['name'] ?? 'AxisVTU User';
    final email = user['email'] ?? 'email@example.com';
    final phone = user['phone_number'] ?? 'N/A';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppHeader(
            title: 'Profile',
            subtitle: 'Account details and security.',
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                _InfoTile(label: 'Phone number', value: phone),
                const Divider(height: 20),
                _InfoTile(label: 'Account type', value: 'User'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _ActionRow(label: 'Change password', icon: Icons.lock_outline, onTap: () {}),
                const SizedBox(height: 8),
                _ActionRow(label: 'Delete account', icon: Icons.delete_outline, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () async {
              await session.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                LoginScreen.route,
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
