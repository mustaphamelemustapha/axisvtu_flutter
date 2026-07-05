import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/session.dart';
import '../theme/axis_tokens.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/primary_button.dart';
import '../services/transaction_pin_service.dart';
import '../services/biometric_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _changingPassword = false;
  bool _biometricBusy = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final bioEnabled = await BiometricService.isAppLockEnabled;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bioEnabled;
    });
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
                        'Are you sure you want to delete your MELE DATA account? This will immediately:',
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
        final session = context.read<SessionController>();
        setState(() => _biometricEnabled = false);
        await BiometricService.setAppLockEnabled(false);
        await BiometricService.deletePin();
        await session.disableBiometrics();
        return;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric unlock',
      );
      if (authenticated) {
        if (!mounted) return;
        final session = context.read<SessionController>();
        final token = (session.token ?? '').trim();
        if (token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please log in again.')),
          );
          return;
        }

        final pinService = TransactionPinService(token: token);

        try {
          final status = await pinService.status();
          if (!status.isSet) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please create a transaction PIN in settings first.'),
              ),
            );
            return;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to verify PIN status: ${e.toString()}'),
            ),
          );
          return;
        }

        if (!mounted) return;

        final pin = await PinEntrySheet.show(
          context,
          title: 'Enter Transaction PIN',
          subtitle: 'Verify your PIN to secure biometric purchases.',
          confirmLabel: 'Verify',
          pinLength: 4,
          onSubmit: (val) async {
            try {
              await pinService.verify(val);
              return null; // success
            } on ApiException catch (e) {
              if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 423 || e.statusCode == 429) {
                return 'Incorrect PIN, try again.';
              }
              return e.message;
            } catch (e) {
              return e.toString();
            }
          },
        );

        if (pin == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric activation cancelled.')),
          );
          return;
        }

        await BiometricService.savePin(pin);

        setState(() => _biometricEnabled = true);
        await BiometricService.setAppLockEnabled(true);
        // Also save the token specifically for biometrics so it persists after logout
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



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Security', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ConcentricCirclesBg(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openChangePasswordSheet,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: const Text('Reset MELE DATA PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openTransactionPinSheet,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Biometrics', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Switch.adaptive(
                      value: _biometricEnabled, 
                      onChanged: _biometricBusy ? null : (_) => _toggleBiometric(), 
                      activeColor: Theme.of(context).colorScheme.primary
                    ),
                    onTap: _toggleBiometric,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
