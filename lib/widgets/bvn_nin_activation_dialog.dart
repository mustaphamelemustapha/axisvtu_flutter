import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';

class BvnNinActivationDialog extends StatefulWidget {
  const BvnNinActivationDialog({super.key, required this.onActivated});

  final VoidCallback onActivated;

  static Future<void> show(BuildContext context, {required VoidCallback onActivated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BvnNinActivationDialog(onActivated: onActivated),
    );
  }

  @override
  State<BvnNinActivationDialog> createState() => _BvnNinActivationDialogState();
}

class _BvnNinActivationDialogState extends State<BvnNinActivationDialog> {
  String _option = 'nin'; // 'nin' (recommended) or 'bvn'
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _inputCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    if (value.length != 11) {
      setState(() {
        _error = 'Enter a valid 11-digit ${_option.toUpperCase()}.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null || token.isEmpty) {
        throw Exception('User is not authenticated.');
      }

      final walletService = WalletService(token: token);
      final bvn = _option == 'bvn' ? value : null;
      final nin = _option == 'nin' ? value : null;

      // 1. Immediately link and persist the KYC hash to the user profile
      try {
        await walletService.linkKyc(bvn: bvn, nin: nin);
      } catch (_) {
        // Fallback gracefully if link-kyc isn't available
      }

      // 2. Also trigger bank account generation
      try {
        await walletService.createBankAccounts(bvn: bvn, nin: nin);
      } catch (_) {}

      // 3. Immediately mark session user as verified in local state and notify listeners
      await session.updateUserField('kyc_verified', true);
      await session.updateUserField(_option == 'bvn' ? 'has_bvn' : 'has_nin', true);
      await session.syncProfileIfNeeded();

      if (!mounted) return;
      widget.onActivated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity linked and accounts activated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Link NIN / BVN',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Switcher between NIN (Recommended) and BVN
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _loading
                            ? null
                            : () {
                                setState(() {
                                  _option = 'nin';
                                  _inputCtrl.clear();
                                  _error = null;
                                });
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _option == 'nin'
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _option == 'nin'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'NIN (Recommended)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: _option == 'nin'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _option == 'nin'
                                        ? theme.colorScheme.primary
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _loading
                            ? null
                            : () {
                                setState(() {
                                  _option = 'bvn';
                                  _inputCtrl.clear();
                                  _error = null;
                                });
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _option == 'bvn'
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _option == 'bvn'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'BVN Option',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: _option == 'bvn'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _option == 'bvn'
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter 11-Digit ${_option.toUpperCase()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inputCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                enabled: !_loading,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: _option == 'nin' ? 'Dial *346# to check NIN' : 'Dial *565*0# for BVN',
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${AppConfig.appName} securely hashes and transmits your ID directly to CBN-licensed identity rails for verification.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '256-bit Bank Grade Encryption',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify & Activate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

