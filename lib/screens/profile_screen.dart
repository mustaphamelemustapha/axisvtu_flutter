import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/session.dart';
import '../state/theme_controller.dart';
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
  static const _saveBeneficiariesKey = 'axis_profile_save_beneficiaries_v1';
  static const _pushNotificationsKey = 'axis_profile_push_notifications_v1';
  static const _emailAlertsKey = 'axis_profile_email_alerts_v1';

  bool _updatingProfile = false;
  bool _changingPassword = false;
  bool _saveBeneficiaries = true;
  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _saveBeneficiaries = prefs.getBool(_saveBeneficiariesKey) ?? _saveBeneficiaries;
      _pushNotifications = prefs.getBool(_pushNotificationsKey) ?? _pushNotifications;
      _emailAlerts = prefs.getBool(_emailAlertsKey) ?? _emailAlerts;
    });
  }

  Future<void> _saveBoolPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  bool _emailAlerts = true;

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
                  Text(
                    status.isSet
                        ? 'Your ${status.pinLength}-digit PIN protects wallet debits.'
                        : 'Set a ${status.pinLength}-digit PIN to protect wallet debits and approvals.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 14),
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
    final status = await service.statusOrNull();
    final pinLength = status?.pinLength == 6 ? 6 : 4;
    final first = await PinEntrySheet.show(
      context,
      title: 'Create Transaction PIN',
      subtitle: 'Set a $pinLength-digit PIN to protect wallet debits.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || first == null) return;

    final confirm = await PinEntrySheet.show(
      context,
      title: 'Confirm Transaction PIN',
      subtitle: 'Re-enter your $pinLength-digit PIN.',
      confirmLabel: 'Save PIN',
      pinLength: pinLength,
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
    final status = await service.statusOrNull();
    final pinLength = status?.pinLength == 6 ? 6 : 4;
    final current = await PinEntrySheet.show(
      context,
      title: 'Enter Current PIN',
      subtitle: 'Confirm your identity before changing the PIN.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || current == null) return;

    final next = await PinEntrySheet.show(
      context,
      title: 'Set New PIN',
      subtitle: 'Choose a fresh $pinLength-digit PIN.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || next == null) return;

    final confirm = await PinEntrySheet.show(
      context,
      title: 'Confirm New PIN',
      subtitle: 'Re-enter the new $pinLength-digit PIN.',
      confirmLabel: 'Save PIN',
      pinLength: pinLength,
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

  Future<void> _showFeatureSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> actions,
    String? helperText,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(
                        alpha: isDark ? 0.16 : 0.18,
                      ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
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
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (helperText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                            height: 1.45,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showComingSoon(String title, String subtitle) async {
    await _showFeatureSheet(
      title: title,
      subtitle: subtitle,
      icon: Icons.hourglass_bottom_rounded,
      helperText: 'This feature is not live yet. We will unlock it in a future update.',
      actions: [
        PrimaryButton(
          label: 'Got it',
          onPressed: () => Navigator.pop(context),
          icon: Icons.check_rounded,
        ),
      ],
    );
  }

  Future<void> _showVerificationDetails({
    required String verificationLabel,
    required String name,
    required String email,
    required String phone,
    required String joined,
    required bool hasName,
    required bool hasEmail,
    required bool hasPhone,
  }) async {
    final missing = <String>[
      if (!hasName) 'Full name',
      if (!hasEmail) 'Email',
      if (!hasPhone) 'Phone number',
    ];
    await _showFeatureSheet(
      title: 'Verification status',
      subtitle: verificationLabel,
      icon: Icons.verified_user_rounded,
      helperText: verificationLabel == 'Verified'
          ? 'Your profile details are complete enough for trusted transactions.'
          : 'Finish the missing details below to move your account closer to a verified state.',
      actions: [
        _InfoTile(label: 'Account name', value: name, icon: Icons.badge_outlined),
        const SizedBox(height: 8),
        _InfoTile(label: 'Email', value: email.isEmpty ? 'Not added' : email, icon: Icons.email_outlined),
        const SizedBox(height: 8),
        _InfoTile(label: 'Phone', value: phone.isEmpty ? 'Not added' : phone, icon: Icons.phone_outlined),
        const SizedBox(height: 8),
        _InfoTile(label: 'Member since', value: joined, icon: Icons.event_outlined),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Missing: ${missing.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: hasName || hasEmail || hasPhone ? 'Edit profile' : 'Complete profile',
          icon: Icons.edit_outlined,
          onPressed: () {
            Navigator.pop(context);
            _openEditProfileSheet();
          },
        ),
      ],
    );
  }

  Future<void> _toggleThemePreference() async {
    HapticFeedback.selectionClick();
    context.read<ThemeController>().toggle();
  }

  Future<void> _togglePushPreference(bool value) async {
    setState(() => _pushNotifications = value);
    await _saveBoolPref(_pushNotificationsKey, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'In-app alerts enabled.' : 'In-app alerts paused.')),
    );
  }

  Future<void> _toggleEmailAlerts(bool value) async {
    setState(() => _emailAlerts = value);
    await _saveBoolPref(_emailAlertsKey, value);
  }

  Future<void> _toggleBeneficiaries(bool value) async {
    setState(() => _saveBeneficiaries = value);
    await _saveBoolPref(_saveBeneficiariesKey, value);
  }

  Future<void> _openFaqSheet() async {
    await _showFeatureSheet(
      title: 'Help center',
      subtitle: 'Common questions',
      icon: Icons.help_outline_rounded,
      helperText: 'These notes cover the most common questions so you can move quickly without leaving the page.',
      actions: [
        _InfoTile(
          label: 'How do I fund my wallet?',
          value: 'Transfer to your dedicated account and the wallet updates automatically.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Why is a purchase pending?',
          value: 'Some providers confirm a little later. We keep the record visible in History.',
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Where is my receipt?',
          value: 'Open the transaction and use View Receipt or Share Receipt.',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Why did my PIN fail?',
          value: 'Wrong PIN attempts return a calm retry message so you can try again right away.',
          icon: Icons.pin_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'What if a payment is pending?',
          value: 'Pending transactions stay visible in History until the provider gives a final result.',
          icon: Icons.hourglass_bottom_rounded,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Contact support',
          icon: Icons.mail_outline_rounded,
          onPressed: () {
            Navigator.pop(context);
            _contactSupport();
          },
        ),
      ],
    );
  }

  Future<void> _openIssueSheet() async {
    final subjectCtrl = TextEditingController(text: 'AxisVTU issue report');
    final detailsCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Report an issue',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write a short summary and we will route it to the mmtechglobe support team.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short summary',
                    prefixIcon: Icon(Icons.subject_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Describe what happened',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Email support',
                  icon: Icons.mail_outline_rounded,
                  onPressed: () async {
                    final subject = subjectCtrl.text.trim().isEmpty
                        ? 'AxisVTU issue report'
                        : subjectCtrl.text.trim();
                    final body = detailsCtrl.text.trim().isEmpty
                        ? 'Hello mmtechglobe team,\n\nI need help with an issue in the app.'
                        : detailsCtrl.text.trim();
                    Navigator.pop(context);
                    await _launchSupportEmail(
                      subject: subject,
                      body: body,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _contactSupport() async {
    await _launchSupportEmail(
      subject: 'AxisVTU support request',
      body: 'Hello mmtechglobe team,\n\nI need help with my AxisVTU account.',
    );
  }

  Future<void> _launchSupportEmail({required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'mmtechglobe@gmail.com',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await _showComingSoon(
          'Support email',
          'Please write to mmtechglobe@gmail.com with your subject and issue details.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showComingSoon(
        'Support email',
        'Please write to mmtechglobe@gmail.com with your subject and issue details.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
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
    final themeController = context.watch<ThemeController>();
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF5B6B82);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 16, 14, compact ? 14 : 16, 28),
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
              SizedBox(width: compact ? 10 : 12),
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
              ThemeToggleButton(size: compact ? 40 : 44),
            ],
          ),
              SizedBox(height: compact ? 14 : 16),
          Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
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
                SizedBox(height: compact ? 12 : 14),
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
                SizedBox(height: compact ? 8 : 10),
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
          SizedBox(height: compact ? 12 : 14),
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
          SizedBox(height: compact ? 10 : 12),
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
                  subtitle: 'Device biometrics will arrive in a future update',
                  icon: Icons.fingerprint_rounded,
                  onTap: () => _showComingSoon(
                    'Biometric unlock',
                    'Device biometrics will be supported in a future update for quicker secure access.',
                  ),
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
          SizedBox(height: compact ? 10 : 12),
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
                  onPressed: () => _showVerificationDetails(
                    verificationLabel: verificationLabel,
                    name: name,
                    email: email,
                    phone: phone,
                    joined: joined,
                    hasName: hasName,
                    hasEmail: hasEmail,
                    hasPhone: hasPhone,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          _ProfileSection(
            title: 'Preferences',
            subtitle: 'Control notifications and convenience',
            icon: Icons.tune_rounded,
            child: Column(
              children: [
                _ActionTile(
                  label: 'Notification alerts',
                  subtitle: 'In-app alerts and receipts for now',
                  icon: Icons.notifications_active_outlined,
                  trailing: Switch.adaptive(
                    value: _pushNotifications,
                    onChanged: _togglePushPreference,
                  ),
                  onTap: () => _togglePushPreference(!_pushNotifications),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Email alerts',
                  subtitle: 'Receipts and security notices',
                  icon: Icons.mark_email_unread_outlined,
                  trailing: Switch.adaptive(
                    value: _emailAlerts,
                    onChanged: _toggleEmailAlerts,
                  ),
                  onTap: () => _toggleEmailAlerts(!_emailAlerts),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Auto-save beneficiaries',
                  subtitle: 'Store frequent numbers for faster checkout',
                  icon: Icons.bookmark_border_rounded,
                  trailing: Switch.adaptive(
                    value: _saveBeneficiaries,
                    onChanged: _toggleBeneficiaries,
                  ),
                  onTap: () => _toggleBeneficiaries(!_saveBeneficiaries),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Theme preference',
                  subtitle: themeController.isDark ? 'Dark mode' : 'Light mode',
                  icon: Icons.dark_mode_outlined,
                  trailing: Switch.adaptive(
                    value: themeController.isDark,
                    onChanged: (_) => _toggleThemePreference(),
                  ),
                  onTap: _toggleThemePreference,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          _ProfileSection(
            title: 'Help & support',
            subtitle: 'Quick answers and contact options',
            icon: Icons.support_agent_rounded,
            child: Column(
              children: [
                _ActionTile(
                  label: 'Contact support',
                  subtitle: 'Email the AxisVTU team',
                  icon: Icons.headset_mic_outlined,
                  onTap: _contactSupport,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Help center',
                  subtitle: 'Browse common answers',
                  icon: Icons.help_outline_rounded,
                  onTap: _openFaqSheet,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  label: 'Report an issue',
                  subtitle: 'Flag an issue or failed transaction',
                  icon: Icons.bug_report_outlined,
                  onTap: _openIssueSheet,
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
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
            padding: EdgeInsets.all(compact ? 12 : 14),
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
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: compact ? 18 : 20,
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                        size: compact ? 20 : 24,
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
                    children: [SizedBox(height: compact ? 12 : 14), widget.child],
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
    final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.sizeOf(context).height < 760;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
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
            width: compact ? 34 : 36,
            height: compact ? 34 : 36,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: compact ? 16 : 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.sizeOf(context).height < 760;
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
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
                width: compact ? 34 : 36,
                height: compact ? 34 : 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: compact ? 16 : 18, color: color),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                    size: compact ? 20 : 24,
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
