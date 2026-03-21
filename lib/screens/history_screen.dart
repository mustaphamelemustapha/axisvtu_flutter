import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/transactions_service.dart';
import '../state/session.dart';
import '../widgets/app_header.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<dynamic>>? _txFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<SessionController>().token;
    if (_txFuture == null && token != null && token.isNotEmpty) {
      _txFuture = TransactionsService(token: token).getTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppHeader(
            title: 'Transactions',
            subtitle: 'Recent purchases and funding.',
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(0),
            child: FutureBuilder<List<dynamic>>(
              future: _txFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No transactions yet.'),
                  );
                }
                return Column(
                  children: List.generate(items.length, (index) {
                    final tx = items[index] as Map<String, dynamic>;
                    final title = _titleFor(tx);
                    final subtitle = _subtitleFor(tx);
                    final amount = tx['amount']?.toString() ?? '0';
                    final status = tx['status']?.toString() ?? 'pending';
                    return Column(
                      children: [
                        _TransactionRow(
                          title: title,
                          subtitle: subtitle,
                          amount: '₦$amount',
                          status: status,
                        ),
                        if (index != items.length - 1) const Divider(height: 1),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(Map<String, dynamic> tx) {
    final type = (tx['tx_type'] ?? '').toString();
    if (type == 'data') return 'Data Purchase';
    if (type == 'wallet_fund') return 'Wallet Funding';
    if (type == 'airtime') return 'Airtime Purchase';
    if (type == 'cable') return 'Cable TV';
    if (type == 'electricity') return 'Electricity';
    return type.isEmpty ? 'Transaction' : type.toUpperCase();
  }

  String _subtitleFor(Map<String, dynamic> tx) {
    final meta = tx['meta'] as Map<String, dynamic>?;
    final phone = meta?['recipient_phone'] ?? meta?['phone_number'];
    final network = tx['network']?.toString();
    if (phone != null && phone.toString().isNotEmpty) return phone.toString();
    if (network != null && network.isNotEmpty) return network;
    return tx['reference']?.toString() ?? '';
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isSuccess = status.toLowerCase() == 'success';
    final color = isSuccess ? Colors.green : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.receipt_long),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
