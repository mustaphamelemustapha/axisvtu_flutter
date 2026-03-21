import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/glass_card.dart';
import '../widgets/quick_action_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Map<String, dynamic>>? _walletFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<SessionController>().token;
    if (_walletFuture == null && token != null && token.isNotEmpty) {
      _walletFuture = WalletService(token: token).getWallet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user ?? {};
    final name = user['full_name'] ?? user['name'] ?? 'AxisVTU User';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppHeader(
            title: 'Hi $name',
            subtitle: 'Your VTU command center is ready.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AxisPalette.gradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Axis Wallet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, dynamic>>(
                  future: _walletFuture,
                  builder: (context, snapshot) {
                    final balance = snapshot.data?['balance'] ?? 0;
                    return Text(
                      '₦$balance',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white, fontSize: 28),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Instant funding', style: TextStyle(color: Colors.white)),
                    ),
                    const Spacer(),
                    const Icon(Icons.account_balance_wallet, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Column(
            children: [
              QuickActionTile(label: 'Buy Data', icon: Icons.wifi, accent: const Color(0xFF1E88E5), onTap: () {}),
              const SizedBox(height: 12),
              QuickActionTile(label: 'Airtime', icon: Icons.phone_iphone, accent: const Color(0xFF0FB5AE), onTap: () {}),
              const SizedBox(height: 12),
              QuickActionTile(label: 'Electricity', icon: Icons.flash_on, accent: const Color(0xFFFFB020), onTap: () {}),
              const SizedBox(height: 12),
              QuickActionTile(label: 'Cable TV', icon: Icons.tv, accent: const Color(0xFF7C4DFF), onTap: () {}),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.campaign_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AxisVTU is live. Enjoy quick VTU services with instant receipts.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
