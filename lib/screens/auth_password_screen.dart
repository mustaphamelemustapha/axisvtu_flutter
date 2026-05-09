import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_lookup_service.dart';
import '../state/session.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_route.dart';
import '../widgets/primary_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                title: 'Welcome ${_displayName.isEmpty ? 'back' : _displayName}',
                subtitle: _lookupLoading
                    ? 'Checking profile...'
                    : 'Enter your password to continue.',
                logoSize: 86,
                titleSize: 24,
                tight: true,
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF10182B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.28 : 0.1,),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ListView(
                    children: [
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
                            ).colorScheme.outline.withOpacity(0.2),
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
                              ).colorScheme.outline.withOpacity(0.2),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
