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
import '../services/biometric_service.dart';
import '../services/push_notification_service.dart';
import 'quick_auth_screen.dart';
import 'welcome_screen.dart';
import 'about_screen.dart';
import 'referral_screen.dart';

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
  bool _biometricBusy = false;
  bool _changingPassword = false;
  bool _saveBeneficiaries = true;
  bool _pushNotifications = true;
  bool _biometricEnabled = false;
  final _deleteConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = await BiometricService.isAppLockEnabled;
    if (!mounted) return;
    setState(() {
      _saveBeneficiaries =
          prefs.getBool(_saveBeneficiariesKey) ?? _saveBeneficiaries;
      _pushNotifications =
          prefs.getBool(_pushNotificationsKey) ?? _pushNotifications;
      _emailAlerts = prefs.getBool(_emailAlertsKey) ?? _emailAlerts;
      _biometricEnabled = bioEnabled;
    });
  }

  Future<void> _saveBoolPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _deleteConfirmCtrl.dispose();
    super.dispose();
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
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.65),
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
                                'Purchase PIN',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
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
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.65),
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
                              'Purchase PIN',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.isSet
                                  ? 'Update or reset the PIN that protects your account credit.'
                                  : 'Set up a PIN to protect your orders and approvals.',
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
                        ? 'Your ${status.pinLength}-digit PIN protects your account credit.'
                        : 'Set a ${status.pinLength}-digit PIN to protect your orders and approvals.',
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
    final sheetContext = context;
    final first = await PinEntrySheet.show(
      sheetContext,
      title: 'Create Purchase PIN',
      subtitle: 'Set a $pinLength-digit PIN to protect your account credit.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || first == null) return;

    final confirm = await PinEntrySheet.show(
      sheetContext,
      title: 'Confirm Purchase PIN',
      subtitle: 'Re-enter your $pinLength-digit PIN.',
      confirmLabel: 'Save PIN',
      pinLength: pinLength,
    );
    if (!mounted || confirm == null) return;
    if (first != confirm) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('PIN mismatch. Please try again.')),
      );
      return;
    }

    try {
      await service.setup(pin: first, confirmPin: confirm);
      if (!mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Purchase PIN created successfully.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeTransactionPin(TransactionPinService service) async {
    final status = await service.statusOrNull();
    final pinLength = status?.pinLength == 6 ? 6 : 4;
    final sheetContext = context;
    final current = await PinEntrySheet.show(
      sheetContext,
      title: 'Enter Current PIN',
      subtitle: 'Confirm your identity before changing the PIN.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || current == null) return;

    final next = await PinEntrySheet.show(
      sheetContext,
      title: 'Set New PIN',
      subtitle: 'Choose a fresh $pinLength-digit PIN.',
      confirmLabel: 'Continue',
      pinLength: pinLength,
    );
    if (!mounted || next == null) return;

    final confirm = await PinEntrySheet.show(
      sheetContext,
      title: 'Confirm New PIN',
      subtitle: 'Re-enter the new $pinLength-digit PIN.',
      confirmLabel: 'Save PIN',
      pinLength: pinLength,
    );
    if (!mounted || confirm == null) return;

    if (next != confirm) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
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
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Purchase PIN updated successfully.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _requestTransactionPinReset(
    TransactionPinService service,
  ) async {
    final sheetContext = context;
    try {
      await service.requestReset();
      if (!mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Reset link sent to your email. Open it to reset your PIN.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        sheetContext,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: isDark ? 0.16 : 0.18),
                ),
                boxShadow: AxisShadows.softGlow,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                          ).colorScheme.outline.withValues(alpha: 0.28),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.64),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
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
      helperText:
          'This feature is not live yet. We will unlock it in a future update.',
      actions: [
        PrimaryButton(
          label: 'Got it',
          onPressed: () => Navigator.pop(context),
          icon: Icons.check_rounded,
        ),
      ],
    );
  }

  Future<void> _showDeleteAccountSheet() async {
    final session = context.read<SessionController>();
    final auth = AuthService(token: session.token);
    bool busy = false;
    _deleteConfirmCtrl.clear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete Account',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.redAccent,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'This action is irreversible',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Are you sure you want to delete your AxisVTU account? This will immediately:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _bulletPoint('Disable your access to all services.'),
                      _bulletPoint('Forfeit any remaining wallet balance.'),
                      _bulletPoint('Archive your transaction history.'),
                      const SizedBox(height: 20),
                      Text(
                        'To confirm, please type "DELETE" below:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => setModalState(() {}),
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        controller: _deleteConfirmCtrl,
                        decoration: InputDecoration(
                          hintText: 'DELETE',
                          hintStyle: TextStyle(color: Colors.redAccent.withValues(alpha: 0.3)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: busy ? 'Deleting...' : 'Permanently Delete My Account',
                        backgroundColor: Colors.redAccent,
                        icon: Icons.warning_amber_rounded,
                        onPressed: (_deleteConfirmCtrl.text.trim().toUpperCase() != 'DELETE' || busy)
                            ? null
                            : () async {
                                setModalState(() => busy = true);
                                try {
                                  await auth.deleteMe();
                                  if (!context.mounted) return;
                                  Navigator.pop(context); // Close sheet
                                  await session.logout();
                                  if (!context.mounted) return;
                                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                                    WelcomeScreen.route,
                                    (_) => false,
                                  );
                                } catch (e) {
                                  setModalState(() => busy = false);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Deletion failed: $e')),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.redAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric() async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    try {
      final availability = await BiometricService.getAvailability();
      if (!availability.ready) {
        String message = 'Biometric unlock is not available on this device.';
        if (!availability.supported) {
          message =
              'This device does not support biometrics or device screen lock.';
        } else if (!availability.canCheck || !availability.hasEnrolled) {
          message =
              'No fingerprint/face is set. Add one in your phone settings, then try again.';
        } else if (availability.error != null &&
            availability.error!.trim().isNotEmpty) {
          message = availability.error!.trim();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      if (_biometricEnabled) {
        setState(() => _biometricEnabled = false);
        await BiometricService.setAppLockEnabled(false);
        final session = context.read<SessionController>();
        await session.disableBiometrics();
        return;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric unlock',
      );
      if (authenticated) {
        setState(() => _biometricEnabled = true);
        await BiometricService.setAppLockEnabled(true);
        // Also save the token specifically for biometrics so it persists after logout
        final session = context.read<SessionController>();
        await session.enableBiometrics();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock enabled.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric verification was not completed. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _toggleThemePreference() async {
    HapticFeedback.selectionClick();
    context.read<ThemeController>().toggle();
  }

  Future<void> _togglePushPreference(bool value) async {
    setState(() => _pushNotifications = value);
    await _saveBoolPref(_pushNotificationsKey, value);
    
    // Sync or wipe token in backend in real-time
    final session = context.read<SessionController>();
    await PushNotificationService.initialize(session);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'In-app alerts enabled.' : 'In-app alerts paused.',
        ),
      ),
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
      helperText:
          'These notes cover the most common questions so you can move quickly without leaving the page.',
      actions: [
        _InfoTile(
          label: 'How do I add account credit?',
          value:
              'Transfer to your dedicated top-up details and the credit updates automatically.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Why is an order pending?',
          value:
              'Some providers confirm a little later. We keep the record visible in History.',
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
          value:
              'Wrong PIN attempts return a calm retry message so you can try again right away.',
          icon: Icons.pin_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'What if a payment is pending?',
          value:
              'Pending transactions stay visible in History until the provider gives a final result.',
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
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.14),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Report an issue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write a short summary and we will route it to the mmtechglobe support team.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.66),
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
                    await _launchSupportEmail(subject: subject, body: body);
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

  Future<void> _launchSupportEmail({
    required String subject,
    required String body,
  }) async {
    final sheetContext = context;
    final messenger = ScaffoldMessenger.of(sheetContext);
    final uri = Uri(
      scheme: 'mailto',
      path: 'mmtechglobe@gmail.com',
      queryParameters: {'subject': subject, 'body': body},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await Clipboard.setData(
          const ClipboardData(text: 'mmtechglobe@gmail.com'),
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Support email copied. Send your issue to mmtechglobe@gmail.com.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(
        const ClipboardData(text: 'mmtechglobe@gmail.com'),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Support email copied. Send your issue to mmtechglobe@gmail.com.',
          ),
        ),
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
    final joined = _joinedLabel(user['created_at']);
    final initials = _initialsFromName(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Header Colors
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF1F5F9);
    final tileBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: heroText.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            name,
                            style: TextStyle(
                              color: heroText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          joined,
                          style: TextStyle(
                            color: heroSoftText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings List
            _ProfileTile(
              label: 'Account',
              icon: Icons.person_outline_rounded,
              onTap: _openEditProfileSheet,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Notifications',
              icon: Icons.notifications_none_rounded,
              trailing: Switch.adaptive(
                value: _pushNotifications,
                onChanged: (value) => _togglePushPreference(value),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              onTap: () => _togglePushPreference(!_pushNotifications),
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Security',
              icon: Icons.security_rounded,
              onTap: _openChangePasswordSheet,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Change PIN',
              icon: Icons.vpn_key_outlined,
              onTap: _openTransactionPinSheet,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Biometrics',
              icon: Icons.fingerprint_rounded,
              trailing: Switch.adaptive(
                value: _biometricEnabled,
                onChanged: _biometricBusy ? null : (_) => _toggleBiometric(),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              onTap: _toggleBiometric,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'About',
              icon: Icons.info_outline_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              ),
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Help',
              icon: Icons.help_outline_rounded,
              onTap: _contactSupport,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Delete Account',
              icon: Icons.delete_outline_rounded,
              iconColor: Colors.redAccent.withValues(alpha: 0.7),
              textColor: Colors.redAccent.withValues(alpha: 0.7),
              onTap: _showDeleteAccountSheet,
              backgroundColor: tileBg,
            ),
            _ProfileTile(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: () async {
                await session.logout();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                  QuickAuthScreen.route,
                  (_) => false,
                );
              },
              backgroundColor: tileBg,
            ),


            const SizedBox(height: 32),
            // Social Media Section
            const Text(
              'Social Media',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            _SocialTile(
              label: 'WhatsApp',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => launchUrl(Uri.parse('https://wa.me/2348141114647')),
              backgroundColor: tileBg,
            ),
            _SocialTile(
              label: 'Instagram',
              icon: Icons.camera_alt_outlined,
              onTap: () => launchUrl(Uri.parse('https://instagram.com/axisvtu.app')),
              backgroundColor: tileBg,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final contentColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor ?? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: contentColor.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: iconColor ?? (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? contentColor,
                    ),
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: contentColor.withValues(alpha: 0.3),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor ?? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: contentColor.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: contentColor,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: contentColor.withValues(alpha: 0.3),
              ),
            ],
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
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.sizeOf(context).height < 760;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
