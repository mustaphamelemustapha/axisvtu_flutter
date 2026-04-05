import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<Map<String, dynamic>>? _walletFuture;
  Future<Map<String, dynamic>>? _accountsFuture;
  bool _generating = false;
  String _activeToken = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = (context.watch<SessionController>().token ?? '').trim();
    if (token.isNotEmpty &&
        (token != _activeToken ||
            _walletFuture == null ||
            _accountsFuture == null)) {
      _reloadWallet(token);
      _activeToken = token;
    }
  }

  void _reloadWallet(String token) {
    final service = WalletService(token: token);
    _walletFuture = service.getWallet();
    _accountsFuture = service.getBankAccounts();
  }

  Future<void> _refresh() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    setState(() => _reloadWallet(token));
    await Future.wait([_walletFuture!, _accountsFuture!]);
  }

  String _formatNaira(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  double _extractBalance(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final direct = data['balance'];
    if (direct != null) return double.tryParse(direct.toString()) ?? 0;
    final nested = data['wallet'];
    if (nested is Map) {
      return double.tryParse((nested['balance'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _generateAccount() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final token = context.read<SessionController>().token;
      if (token == null || token.isEmpty) return;
      final service = WalletService(token: token);
      setState(() {
        _walletFuture = service.getWallet();
        _accountsFuture = service.createBankAccounts();
      });
      await _accountsFuture;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('phone')) {
        await _promptPhoneNumber();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate account: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to generate account: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _promptPhoneNumber() async {
    final session = context.read<SessionController>();
    final controller = TextEditingController(
      text: session.user?['phone_number'] ?? '',
    );
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add phone number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'e.g. 08123456789'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (phone == null || phone.trim().isEmpty) return;
    final token = session.token;
    if (token == null || token.isEmpty) return;
    try {
      final service = AuthService(token: token);
      final updated = await service.updateProfile(phoneNumber: phone.trim());
      session.updateUser(updated);
      final walletService = WalletService(token: token);
      setState(() {
        _walletFuture = walletService.getWallet();
        _accountsFuture = walletService.createBankAccounts();
      });
      await _accountsFuture;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save phone number: $e')),
      );
    }
  }

  Future<void> _copyText(String value, String label) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user ?? {};
    final name = (user['full_name'] ?? user['name'] ?? 'AxisVTU User')
        .toString()
        .trim();
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AxisPalette.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Manage balance and dedicated account',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh wallet',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? const LinearGradient(
                        colors: [Color(0xFF0E1B2C), Color(0xFF172A46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEAF2FF), Color(0xFFD9E8FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $name',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate one account and get wallet credit instantly whenever money lands.',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.verified_user_rounded, size: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Available Balance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _walletFuture,
                    builder: (context, snapshot) {
                      final balance = _extractBalance(snapshot.data);
                      return Text(
                        '₦${_formatNaira(balance)}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _generating ? 'Generating...' : 'Generate Account',
                    onPressed: _generating ? null : _generateAccount,
                    loading: _generating,
                    icon: Icons.add_card_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Linked Accounts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Loading accounts...'),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load accounts. Pull down to retry.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: 'Generate Account',
                          icon: Icons.account_balance_rounded,
                          onPressed: _generating ? null : _generateAccount,
                        ),
                      ],
                    ),
                  );
                }

                final accounts = (snapshot.data?['accounts'] as List?) ?? [];
                final requiresKyc = snapshot.data?['requires_kyc'] == true;
                if (accounts.isEmpty) {
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requiresKyc
                              ? 'No account yet. Tap generate to create your dedicated funding account.'
                              : 'No linked accounts yet.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: _generating
                              ? 'Generating...'
                              : 'Generate Account',
                          icon: Icons.account_balance_rounded,
                          loading: _generating,
                          onPressed: _generating ? null : _generateAccount,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    ...accounts.map((item) {
                      final account = item is Map
                          ? Map<String, dynamic>.from(item)
                          : <String, dynamic>{};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BankCard(
                          bankName: (account['bank_name'] ?? 'Bank').toString(),
                          accountNumber: (account['account_number'] ?? '')
                              .toString(),
                          accountName: (account['account_name'] ?? name)
                              .toString(),
                          onCopyAccount: () => _copyText(
                            (account['account_number'] ?? '').toString(),
                            'Account number',
                          ),
                          onCopyName: () => _copyText(
                            (account['account_name'] ?? name).toString(),
                            'Account name',
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 2),
                    OutlinedButton.icon(
                      onPressed: _generating ? null : _generateAccount,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(
                        _generating ? 'Generating...' : 'Generate / Refresh',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Once your bank transfer lands, your wallet updates automatically. No manual funding needed.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.onCopyAccount,
    required this.onCopyName,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;
  final VoidCallback onCopyAccount;
  final VoidCallback onCopyName;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bankName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KeyValueRow(
            label: 'Account Number',
            value: accountNumber,
            onCopy: onCopyAccount,
          ),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Account Name',
            value: accountName,
            onCopy: onCopyName,
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value.isEmpty ? null : onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
