import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_lookup_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_route.dart';
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
    final muted = onSurface.withValues(alpha: 0.7);
    return Scaffold(
      body: AuthBackdrop(
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
            const SizedBox(height: 520),
            Text(
              'Welcome ${_displayName.isNotEmpty ? _displayName : 'back'}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface),
            ),
            const SizedBox(height: 8),
            if (_lookupLoading)
              Text('Fetching your profile...', style: TextStyle(color: muted))
            else
              Text(
                'Enter your password to continue.',
                style: TextStyle(color: muted),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: muted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.identifier,
                            style: TextStyle(color: onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline, color: muted),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: muted),
                ),
                hintText: 'Password',
                hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    AuthRoute(page: ForgotPasswordScreen(identifier: widget.identifier)),
                  );
                },
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _GradientButton(
              label: _loading ? 'Signing in...' : 'Login',
              onTap: _loading ? () {} : _login,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  AuthRoute(
                    page: RegisterScreen(
                      initialPhone: widget.identifier.contains('@') ? null : widget.identifier,
                      initialEmail: widget.identifier.contains('@') ? widget.identifier : null,
                    ),
                  ),
                );
              },
              child: const Text('Create new account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AxisPalette.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
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
