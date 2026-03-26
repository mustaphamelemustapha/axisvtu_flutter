import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../state/session.dart';
import '../widgets/app_header.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<SessionController>().token;
    if (_walletFuture == null && token != null && token.isNotEmpty) {
      final service = WalletService(token: token);
      _walletFuture = service.getWallet();
      _accountsFuture = service.getBankAccounts();
    }
  }

  Future<void> _generateAccount() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final token = context.read<SessionController>().token;
      if (token == null || token.isEmpty) return;
      final service = WalletService(token: token);
      setState(() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate account: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _promptPhoneNumber() async {
    final session = context.read<SessionController>();
    final controller = TextEditingController(text: session.user?['phone_number'] ?? '');
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppHeader(
            title: 'Wallet',
            subtitle: 'Manage your balance and recent funding.',
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available balance', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: _walletFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text('Loading...', style: Theme.of(context).textTheme.headlineSmall);
                    }
                    final balance = snapshot.data?['balance'] ?? 0;
                    return Text('₦$balance', style: Theme.of(context).textTheme.headlineSmall);
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Fund wallet', onPressed: () {}, icon: Icons.add),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Linked accounts', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>>(
                  future: _accountsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading accounts...');
                    }
                    final accounts = (snapshot.data?['accounts'] as List?) ?? [];
                    final requiresKyc = snapshot.data?['requires_kyc'] == true;
                    if (accounts.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requiresKyc
                                ? 'Generate a bank account to fund your wallet.'
                                : 'No bank accounts yet.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _generating ? null : _generateAccount,
                              icon: const Icon(Icons.account_balance),
                              label: Text(_generating ? 'Generating...' : 'Generate account'),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: accounts
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _BankRow(
                                name: item['bank_name'] ?? 'Bank',
                                number: item['account_number'] ?? '',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({required this.name, required this.number});

  final String name;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: Theme.of(context).textTheme.bodyMedium),
        Text(number, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
