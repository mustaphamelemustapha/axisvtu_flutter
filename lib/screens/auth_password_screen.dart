import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_lookup_service.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class AuthPasswordScreen extends StatefulWidget {
  const AuthPasswordScreen({super.key, required this.identifier});

  final String identifier;

  @override
  State<AuthPasswordScreen> createState() => _AuthPasswordScreenState();
}

class _AuthPasswordScreenState extends State<AuthPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _fullName;
  bool _lookupLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  Future<void> _fetchName() async {
    setState(() => _lookupLoading = true);
    try {
      final data = await UserLookupService().lookup(widget.identifier);
      setState(() => _fullName = data['full_name'] ?? data['name']);
    } catch (_) {
      setState(() => _fullName = null);
    } finally {
      setState(() => _lookupLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _displayName {
    if (_fullName != null && _fullName!.isNotEmpty) return _fullName!;
    if (widget.identifier.contains('@')) {
      return widget.identifier.split('@').first;
    }
    return widget.identifier;
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final ok = await session.login(widget.identifier, _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
      return;
    }
    setState(() {
      _loading = false;
      _error = session.error ?? 'Login failed';
    });
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
              const SizedBox(height: 500),
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
                      'Welcome ${_displayName.isEmpty ? 'back' : _displayName}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_lookupLoading)
                      Text(
                        'Checking profile...',
                        style: TextStyle(color: muted),
                      )
                    else
                      Text(
                        'Enter your password to continue.',
                        style: TextStyle(color: muted),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.identifier,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: onSurface),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                        ),
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            AuthRoute(
                              page: ForgotPasswordScreen(
                                identifier: widget.identifier,
                              ),
                            ),
                          );
                        },
                        child: const Text('Forgot password?'),
                      ),
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
                      label: _loading ? 'Signing in...' : 'Login',
                      loading: _loading,
                      icon: Icons.login_rounded,
                      onPressed: _loading ? null : _login,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          AuthRoute(
                            page: RegisterScreen(
                              initialPhone: widget.identifier.contains('@')
                                  ? null
                                  : widget.identifier,
                              initialEmail: widget.identifier.contains('@')
                                  ? widget.identifier
                                  : null,
                            ),
                          ),
                        );
                      },
                      child: const Text('Create new account'),
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
