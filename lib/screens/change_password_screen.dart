import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/session.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPassword = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final current = _currentCtrl.text.trim();
    final newer = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newer.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All password fields are required')),
      );
      return;
    }
    if (newer.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password must be at least 6 characters')),
      );
      return;
    }
    if (newer != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final session = context.read<SessionController>();
      final token = session.token ?? '';
      await AuthService(token: token).changePassword(
        currentPassword: current,
        newPassword: newer,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569), // Slate 600
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    required String labelText,
    required IconData prefixIcon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 24),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Create New Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Your new password must be at least 6 characters long.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildTextField(
                            _currentCtrl,
                            labelText: 'Current Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscureCurrent,
                            onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _newCtrl,
                            labelText: 'New Password',
                            prefixIcon: Icons.password_rounded,
                            obscureText: _obscureNew,
                            onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _confirmCtrl,
                            labelText: 'Confirm New Password',
                            prefixIcon: Icons.password_rounded,
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          const SizedBox(height: 32),
                          PrimaryButton(
                            label: _changingPassword ? 'Updating...' : 'Update Password',
                            loading: _changingPassword,
                            icon: Icons.check_circle_outline_rounded,
                            onPressed: _changingPassword ? null : _updatePassword,
                          ),
                        ],
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
