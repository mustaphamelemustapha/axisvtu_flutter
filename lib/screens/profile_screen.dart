import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/transaction_pin_service.dart';
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
  bool _biometricEnabled = true;
  bool _saveBeneficiaries = true;
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _themeFollowSystem = false;

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
    if (raw.trim().isEmpty) return 'Member';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Member';
    return 'Member since ${DateFormat('MMM yyyy').format(parsed.toLocal())}';
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
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
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
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
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
                                ScaffoldMessenger.of(this.context).showSnackBar(
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

  Future<void> _openTransactionPinSheet() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;

    final service = TransactionPinService(token: token);

    try {
      final status = await service.statusOrNull();
      if (!mounted) return;

      if (status == null) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.pin_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transaction PIN',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Security service is updating. Please try again in a moment.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openTransactionPinSheet();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.pin_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction PIN',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.isSet
                                  ? 'Update or reset the PIN that protects wallet debits.'
                                  : 'Set up a PIN to protect wallet debits and approvals.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!status.isSet)
                    PrimaryButton(
                      label: 'Set PIN',
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _setupTransactionPin(service);
                      },
                    )
                  else ...[
                    PrimaryButton(
                      label: 'Change PIN',
                      icon: Icons.edit_note_rounded,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _changeTransactionPin(service);
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _requestTransactionPinReset(service);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reset PIN'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load PIN settings: $e')),
      );
    }
  }

  Future<void> _setupTransactionPin(TransactionPinService service) async {
    final first = await PinEntrySheet.show(
      context,
      title: 'Create Transaction PIN',
      subtitle: 'Set a 4-digit PIN to protect wallet debits.',
      confirmLabel: 'Continue',
    );
    if (!mounted || first == null) return;

    final confirm = await PinEntrySheet.show(
      context,
      title: 'Confirm Transaction PIN',
      subtitle: 'Re-enter your 4-digit PIN.',
      confirmLabel: 'Save PIN',
    );
    if (!mounted || confirm == null) return;
    if (first != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN mismatch. Please try again.')),
      );
      return;
    }

    try {
      await service.setup(pin: first, confirmPin: confirm);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction PIN created successfully.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _changeTransactionPin(TransactionPinService service) async {
    final current = await PinEntrySheet.show(
      context,
      title: 'Enter Current PIN',
      subtitle: 'Confirm your identity before changing the PIN.',
      confirmLabel: 'Continue',
    );
    if (!mounted || current == null) return;

    final next = await PinEntrySheet.show(
      context,
      title: 'Set New PIN',
      subtitle: 'Choose a fresh 4-digit PIN.',
      confirmLabel: 'Continue',
    );
    if (!mounted || next == null) return;

    final confirm = await PinEntrySheet.show(
      context,
      title: 'Confirm New PIN',
      subtitle: 'Re-enter the new 4-digit PIN.',
      confirmLabel: 'Save PIN',
    );
    if (!mounted || confirm == null) return;

    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN mismatch. Please try again.')),
      );
      return;
    }

    try {
      await service.change(
        currentPin: current,
        newPin: next,
        confirmPin: confirm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction PIN updated successfully.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _requestTransactionPinReset(
    TransactionPinService service,
  ) async {
    try {
      await service.requestReset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset link sent to your email. Open it to reset your PIN.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showComingSoon(String title, String subtitle) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(context),
                icon: Icons.check_rounded,
              ),
            ],
          ),
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
    final initials = _initialsFromName(name);
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.66);
    final hasName = (user['full_name'] ?? user['name'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final hasEmail = (user['email'] ?? '').toString().trim().isNotEmpty;
    final hasPhone = (user['phone_number'] ?? '').toString().trim().isNotEmpty;
    final verificationLabel = hasName && hasEmail && hasPhone
        ? 'Verified'
        : hasName || hasEmail || hasPhone
        ? 'In review'
        : 'Setup required';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF5B6B82);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AxisPalette.gradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile & Security',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage account, verification, and trusted settings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeToggleButton(size: 44),
            ],
          ),
              const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF0C1624), Color(0xFF13253B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF7FAFF), Color(0xFFEAF2FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFF2457F5).withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: AxisPalette.warmGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          initials.isEmpty ? 'AX' : initials,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: heroText,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$accountType • $joined',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: heroSoftText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      icon: Icons.verified_user_rounded,
                      label: verificationLabel,
                    ),
                    _StatusChip(
                      icon: Icons.security_rounded,
                      label: 'Trusted account',
                    ),
                    _StatusChip(
                      icon: Icons.lock_outline_rounded,
                      label: 'Secure sessions',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hasName && hasEmail && hasPhone
                      ? 'Your profile is ready for trusted purchases.'
                      : 'Complete your profile details to unlock a stronger trust state.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: heroSoftText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileSection(
            title: 'Account details',
            subtitle: 'Identity and contact information',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
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
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _updatingProfile ? 'Saving...' : 'Edit Profile',
                  loading: _updatingProfile,
                  icon: Icons.edit_outlined,
                  onPressed: _updatingProfile ? null : _openEditProfileSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Security center',
            subtitle: 'Protect your wallet and account',
            icon: Icons.security_rounded,
            child: Column(
              children: [
                _ActionTile(
                  label: 'Change password',
                  subtitle: 'Update your password regularly',
                  icon: Icons.lock_outline_rounded,
                  onTap: _changingPassword ? () {} : _openChangePasswordSheet,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Transaction PIN',
                  subtitle: 'Set, change, or reset your purchase PIN',
                  icon: Icons.pin_outlined,
                  onTap: _openTransactionPinSheet,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Biometric unlock',
                  subtitle: 'Device-only quick access',
                  icon: Icons.fingerprint_rounded,
                  trailing: Switch.adaptive(
                    value: _biometricEnabled,
                    onChanged: (value) =>
                        setState(() => _biometricEnabled = value),
                  ),
                  onTap: () =>
                      setState(() => _biometricEnabled = !_biometricEnabled),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Session management',
                  subtitle: 'Review active sessions and device access',
                  icon: Icons.shield_outlined,
                  onTap: () => _showComingSoon(
                    'Session management',
                    'We will show active sessions and device controls here for additional account protection.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Verification / KYC',
            subtitle: 'Strengthen your trust level',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoTile(
                  label: 'Status',
                  value: verificationLabel,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 10),
                Text(
                  verificationLabel == 'Verified'
                      ? 'Your profile is looking strong and ready for trusted use.'
                      : 'Complete missing details to improve wallet trust and future limit handling.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: verificationLabel == 'Verified'
                      ? 'View verification'
                      : 'Complete verification',
                  icon: Icons.verified_rounded,
                  onPressed: () => _showComingSoon(
                    'KYC / Verification',
                    'This screen will eventually connect to your full identity verification flow.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Preferences',
            subtitle: 'Control notifications and convenience',
            icon: Icons.tune_rounded,
            child: Column(
              children: [
                _ActionTile(
                  label: 'Push notifications',
                  subtitle: 'Account alerts and purchase updates',
                  icon: Icons.notifications_active_outlined,
                  trailing: Switch.adaptive(
                    value: _pushNotifications,
                    onChanged: (value) =>
                        setState(() => _pushNotifications = value),
                  ),
                  onTap: () =>
                      setState(() => _pushNotifications = !_pushNotifications),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Email alerts',
                  subtitle: 'Receipts and security notices',
                  icon: Icons.mark_email_unread_outlined,
                  trailing: Switch.adaptive(
                    value: _emailAlerts,
                    onChanged: (value) => setState(() => _emailAlerts = value),
                  ),
                  onTap: () => setState(() => _emailAlerts = !_emailAlerts),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Auto-save beneficiaries',
                  subtitle: 'Store frequent numbers for faster checkout',
                  icon: Icons.bookmark_border_rounded,
                  trailing: Switch.adaptive(
                    value: _saveBeneficiaries,
                    onChanged: (value) =>
                        setState(() => _saveBeneficiaries = value),
                  ),
                  onTap: () =>
                      setState(() => _saveBeneficiaries = !_saveBeneficiaries),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Theme preference',
                  subtitle: _themeFollowSystem
                      ? 'Follow system theme'
                      : 'Use manual theme switch',
                  icon: Icons.dark_mode_outlined,
                  trailing: Switch.adaptive(
                    value: _themeFollowSystem,
                    onChanged: (value) =>
                        setState(() => _themeFollowSystem = value),
                  ),
                  onTap: () =>
                      setState(() => _themeFollowSystem = !_themeFollowSystem),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Help and support',
            subtitle: 'Get help quickly when needed',
            icon: Icons.support_agent_rounded,
            child: Column(
              children: [
                _ActionTile(
                  label: 'Contact support',
                  subtitle: 'Reach the AxisVTU team',
                  icon: Icons.headset_mic_outlined,
                  onTap: () => _showComingSoon(
                    'Contact support',
                    'Support channels will open here for complaints, issues, and account help.',
                  ),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'FAQ / Help center',
                  subtitle: 'Answers to common questions',
                  icon: Icons.help_outline_rounded,
                  onTap: () => _showComingSoon(
                    'Help center',
                    'This will host support articles, policy notes, and quick answers.',
                  ),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Report an issue',
                  subtitle: 'Flag a failed transaction or app bug',
                  icon: Icons.bug_report_outlined,
                  onTap: () => _showComingSoon(
                    'Report an issue',
                    'We can route reports here with screenshots and transaction references.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'About AxisVTU',
            subtitle: 'App information and trust markers',
            icon: Icons.info_outline_rounded,
            child: Column(
              children: [
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
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Policies',
                  value: 'Privacy • Terms • KYC',
                  icon: Icons.policy_outlined,
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

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProfileSection extends StatefulWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: AxisDurations.normal,
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AxisDurations.normal,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [const SizedBox(height: 14), widget.child],
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: AxisDurations.normal,
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
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
    this.trailing,
    this.danger = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 2),
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
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipText = isDark ? Colors.white : const Color(0xFF0F172A);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.surface;
    final chipBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white : const Color(0xFF2457F5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: chipText,
            ),
          ),
        ],
      ),
    );
  }
}
