import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _updatingProfile = false;
  bool _changingPassword = false;
  bool _deletingAccount = false;

  String _displayName(Map<String, dynamic> user) {
    final fullName = (user['full_name'] ?? user['name'] ?? '')
        .toString()
        .trim();
    if (fullName.isNotEmpty) return fullName;
    final email = (user['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length > 1 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _joinedLabel(dynamic createdAt) {
    final raw = createdAt?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Joined recently';
    return 'Joined ${parsed.year}';
  }

  Future<void> _openEditProfileSheet() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;

    final currentUser = session.user ?? {};
    final fullNameCtrl = TextEditingController(
      text: (currentUser['full_name'] ?? currentUser['name'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (currentUser['phone_number'] ?? '').toString(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Edit Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _updatingProfile ? 'Saving...' : 'Save Changes',
                  loading: _updatingProfile,
                  icon: Icons.save_outlined,
                  onPressed: _updatingProfile
                      ? null
                      : () async {
                          final fullName = fullNameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (fullName.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Full name is too short'),
                              ),
                            );
                            return;
                          }
                          if (phone.isNotEmpty && phone.length < 7) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Phone number is too short'),
                              ),
                            );
                            return;
                          }

                          setState(() => _updatingProfile = true);
                          try {
                            final updated = await AuthService(token: token)
                                .updateProfile(
                                  fullName: fullName,
                                  phoneNumber: phone,
                                );
                            session.updateUser(updated);
                            if (!mounted) return;
                            final navigator = Navigator.of(this.context);
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Update failed: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _updatingProfile = false);
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChangePasswordSheet() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setSheetState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setSheetState(() => obscureNew = !obscureNew),
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setSheetState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _changingPassword
                          ? 'Updating...'
                          : 'Update Password',
                      loading: _changingPassword,
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _changingPassword
                          ? null
                          : () async {
                              final current = currentCtrl.text.trim();
                              final newer = newCtrl.text.trim();
                              final confirm = confirmCtrl.text.trim();
                              if (current.isEmpty ||
                                  newer.isEmpty ||
                                  confirm.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'All password fields are required',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (newer.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'New password must be at least 6 characters',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (newer != confirm) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('New passwords do not match'),
                                  ),
                                );
                                return;
                              }

                              setState(() => _changingPassword = true);
                              try {
                                await AuthService(token: token).changePassword(
                                  currentPassword: current,
                                  newPassword: newer,
                                );
                                if (!mounted) return;
                                final navigator = Navigator.of(this.context);
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password updated successfully',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Password update failed: $e'),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _changingPassword = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Do you want to delete account? If yes, continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, continue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _deletingAccount = true);
    try {
      await AuthService(token: token).deleteMe();
      await session.logout();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(WelcomeScreen.route, (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete account failed: $e')));
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user ?? {};
    final name = _displayName(user);
    final email = (user['email'] ?? '').toString().trim();
    final phone = (user['phone_number'] ?? '').toString().trim();
    final accountType = (user['role'] ?? 'User').toString();
    final joined = _joinedLabel(user['created_at']);
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.66);

    final initials = _initialsFromName(name);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AxisPalette.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Account and security setup',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const ThemeToggleButton(size: 44),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                      colors: [Color(0xFF0E1B2C), Color(0xFF172A46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEAF2FF), Color(0xFFD9E8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AxisPalette.warmGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      initials.isEmpty ? 'AX' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(joined, style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoTile(
                  label: 'Full name',
                  value: name,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Email',
                  value: email.isEmpty ? 'No email' : email,
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Phone number',
                  value: phone.isEmpty ? 'No phone number' : phone,
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Account type',
                  value: accountType.toUpperCase(),
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _updatingProfile ? null : _openEditProfileSheet,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_updatingProfile ? 'Saving...' : 'Edit Profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  label: 'Change password',
                  subtitle: 'Update your password regularly',
                  icon: Icons.lock_outline_rounded,
                  onTap: _changingPassword ? () {} : _openChangePasswordSheet,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: _deletingAccount
                      ? 'Deleting account...'
                      : 'Delete account',
                  subtitle: 'Permanent action',
                  icon: Icons.delete_outline_rounded,
                  danger: true,
                  onTap: _deletingAccount ? () {} : _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoTile(
                  label: 'App version',
                  value: 'AxisVTU Flutter v1.0.0',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Designed by',
                  value: 'M.Mele · MMTECHGLOBE',
                  icon: Icons.design_services_outlined,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Certification',
                  value: 'Certified by CAC',
                  icon: Icons.verified_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () async {
              await session.logout();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(WelcomeScreen.route, (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
