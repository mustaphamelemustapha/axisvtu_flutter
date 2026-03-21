import 'package:flutter/material.dart';

import '../services/password_service.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/theme_toggle_button.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (password.length < 6 || password != confirm) {
      setState(() => _error = 'Passwords must match and be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PasswordService().resetPassword(token: widget.token, newPassword: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please login.')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.7);
    return Scaffold(
      body: AuthBackdrop(
        showBrandText: false,
        overlay: Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
              const ThemeToggleButton(),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 460),
            Text(
              'Set New Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a strong password you can remember.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline, color: muted),
                hintText: 'New password',
                hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline, color: muted),
                hintText: 'Confirm password',
                hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: !_obscure,
                  onChanged: (_) => setState(() => _obscure = !_obscure),
                ),
                Text('Show password', style: TextStyle(color: muted)),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _reset,
              child: Text(_loading ? 'Resetting...' : 'Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}
