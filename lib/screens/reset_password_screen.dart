import 'package:flutter/material.dart';

import '../services/password_service.dart';
import '../services/transaction_pin_service.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/primary_button.dart';
import 'reset_pin_screen.dart';
import 'welcome_screen.dart';

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
  bool _success = false;
  bool _checkingToken = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveResetToken();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveResetToken() async {
    try {
      final isPinReset = await TransactionPinService(token: widget.token)
          .isResetTokenValid(widget.token);
      if (!mounted) return;
      if (isPinReset) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResetPinScreen(token: widget.token)),
        );
        return;
      }
    } catch (_) {
      // Stay on password reset when the PIN resolver is unavailable.
    }
    if (mounted) {
      setState(() => _checkingToken = false);
    }
  }

  Future<void> _reset() async {
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (password.length < 6 || password != confirm) {
      setState(
        () => _error = 'Passwords must match and be at least 6 characters.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PasswordService().resetPassword(
        token: widget.token,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() => _success = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildForm(BuildContext context, Color onSurface, Color muted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10182B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set New Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use a strong password you can remember.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: isDark ? const Color(0xFF151E31) : const Color(0xFFF7FAFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: isDark ? const Color(0xFF151E31) : const Color(0xFFF7FAFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: !_obscure,
                onChanged: (_) => setState(() => _obscure = !_obscure),
              ),
              Text('Show password', style: TextStyle(color: muted)),
            ],
          ),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            label: _loading ? 'Resetting...' : 'Reset Password',
            loading: _loading,
            icon: Icons.check_circle_outline_rounded,
            onPressed: _loading ? null : _reset,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, Color onSurface, Color muted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10182B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF3B82F6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Password reset successfully',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your password has been updated securely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'You can now log in with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Back to Login',
              icon: Icons.login_rounded,
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If you did not request this reset, contact support immediately.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackdrop(
          showBrandText: false,
          child: Column(
            children: [
              AuthTopBar(
                onBack: () => Navigator.of(context).pop(),
              ),
              if (_checkingToken)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...[
                  AuthHeroBlock(
                    title: 'Create new password',
                    subtitle: 'Use the link in your email to finish resetting.',
                    logoSize: 74,
                    titleSize: 24,
                    tight: true,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: _success
                          ? _buildSuccess(context, onSurface, muted)
                          : _buildForm(context, onSurface, muted),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
