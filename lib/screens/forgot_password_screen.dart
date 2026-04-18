import 'dart:async';

import 'package:flutter/material.dart';

import '../services/password_service.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.identifier});

  final String identifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isEmail(widget.identifier)) {
      _emailCtrl.text = widget.identifier;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEmail(_emailCtrl.text)) {
        _sendReset();
      }
    });
    _emailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _isEmail(String value) => value.contains('@');

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_isEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PasswordService().requestReset(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'We could not send the reset link right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading) return;
    await _sendReset();
  }

  Widget _buildRequestCard(BuildContext context, Color onSurface, Color muted) {
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
            'Forgot Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We’ll send a secure reset link to your email.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'you@email.com',
              prefixIcon: const Icon(Icons.email_outlined),
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
          const SizedBox(height: 12),
          Text(
            'We’ll email a link so you can reset your password in your browser.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _loading ? 'Sending link...' : 'Send Reset Link',
            loading: _loading,
            icon: Icons.send_rounded,
            onPressed: _loading ? null : _sendReset,
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context, Color onSurface, Color muted) {
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
                Icons.mark_email_read_rounded,
                color: Color(0xFF3B82F6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Reset link sent',
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
              'We’ve sent a password reset link to ${_emailCtrl.text.trim().isEmpty ? 'your email' : _emailCtrl.text.trim()}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Open your inbox and follow the link to create a new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _loading ? 'Resending...' : 'Resend Link',
              loading: _loading,
              icon: Icons.refresh_rounded,
              onPressed: _loading ? null : _resend,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Login'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If the email does not arrive, check spam or try again in a minute.',
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
                AuthHeroBlock(
                  title: 'Reset by email',
                  subtitle: 'We’ll send a secure link to your inbox.',
                  logoSize: 74,
                  titleSize: 24,
                  tight: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: _sent
                        ? _buildSuccessCard(context, onSurface, muted)
                        : _buildRequestCard(context, onSurface, muted),
                  ),
                ),
              ],
              ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF151F34)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
