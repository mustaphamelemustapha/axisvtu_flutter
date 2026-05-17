import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/pin_entry_sheet.dart';
import '../services/purchase_auth_service.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AuthBackdrop(
        showBrandText: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 64,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 24),
            Text(
              'App Locked',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your PIN to continue',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await PurchaseAuthService.authorizePin(
                    context: context,
                    reason: 'unlock',
                  );
                  if (result == true) {
                    if (context.mounted) {
                      context.read<SessionController>().unlock();
                    }
                  }
                },
                icon: const Icon(Icons.key_rounded),
                label: const Text('Unlock App'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                context.read<SessionController>().logout();
              },
              child: const Text('Switch Account'),
            ),
          ],
        ),
      ),
    );
  }
}
