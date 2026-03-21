import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialIdentifier});
  static const String route = '/login';

  final String? initialIdentifier;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
      _emailCtrl.text = widget.initialIdentifier!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    final ok = await session.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(ShellScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const SizedBox(height: 12),
            const AppHeader(
              title: 'Welcome back',
              subtitle: 'Sign in to continue managing your AxisVTU wallet.',
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email or phone',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (session.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  session.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: session.isLoading ? 'Signing in...' : 'Login',
              loading: session.isLoading,
              onPressed: session.isLoading ? null : _submit,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed(RegisterScreen.route),
                child: const Text('Create an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
