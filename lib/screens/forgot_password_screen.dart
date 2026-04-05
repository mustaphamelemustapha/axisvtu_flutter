import 'dart:async';

import 'package:flutter/material.dart';

import '../services/password_service.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.identifier});

  final String identifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  bool _loading = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;
  String _tokenFull = '';

  @override
  void initState() {
    super.initState();
    if (_isEmail(widget.identifier)) {
      _emailCtrl.text = widget.identifier;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEmail(_emailCtrl.text)) _sendReset();
    });
    _emailCtrl.addListener(() => setState(() {}));
    _codeCtrl.addListener(() {
      setState(() => _tokenFull = _codeCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _otpFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _isEmail(String value) => value.contains('@');

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_isEmail(email)) {
      setState(() => _error = 'Enter a valid email to receive a reset code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PasswordService().requestReset(email);
      _startTimer();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String _formatTimer() {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verify() async {
    if (_tokenFull.length < 6) {
      setState(() => _error = 'Enter the reset code sent to your email.');
      return;
    }
    Navigator.of(
      context,
    ).push(AuthRoute(page: ResetPasswordScreen(token: _tokenFull)));
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackdrop(
          showBrandText: false,
          overlay: Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const ThemeToggleButton(),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 470),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10182B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.28 : 0.1,
                      ),
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
                      'We will verify and let you set a new password.',
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
                        fillColor: isDark
                            ? const Color(0xFF151E31)
                            : const Color(0xFFF7FAFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter the 6-digit code sent to ${_emailCtrl.text.isEmpty ? 'your email' : _emailCtrl.text}.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 10),
                    _OtpRow(controller: _codeCtrl, focusNode: _otpFocus),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _loading ? 'Verifying...' : 'Verify OTP',
                      loading: _loading,
                      icon: Icons.verified_rounded,
                      onPressed: _loading ? null : _verify,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _secondsLeft == 0 && !_loading
                              ? _sendReset
                              : null,
                          child: const Text('Resend Code'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _secondsLeft == 0 ? '' : _formatTimer(),
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpRow extends StatelessWidget {
  const _OtpRow({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 1,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.visiblePassword,
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          Row(
            children: List.generate(6, (index) {
              final char = index < text.length ? text[index] : '';
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF151E31)
                      : const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  char,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
        ],
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
