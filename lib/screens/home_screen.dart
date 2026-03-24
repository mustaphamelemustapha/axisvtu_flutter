import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
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
    final role = user['role'] ?? 'AxisVTU Member';
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final surface = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  gradient: AxisPalette.warmGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'AX' : initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi, $name', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(role, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              _CircleAction(
                icon: Icons.settings_outlined,
                onTap: () {},
              ),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.notifications_none_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 10,
                      width: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E88E5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Account Balance', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('₦0', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: _walletFuture,
                  builder: (context, snapshot) {
                    final balance = snapshot.data?['balance'] ?? 0;
                    return Text(
                      '₦$balance',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: outline),
                  ),
                  child: Row(
                    children: [
                      Text('Axis Wallet', style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      Text('—', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      Icon(Icons.copy, size: 18, color: onSurface.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'Balance',
                        icon: Icons.add,
                        filled: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: 'Transfer',
                        icon: Icons.swap_horiz,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: 'Pay',
                        icon: Icons.qr_code_scanner,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Services', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _ServiceIcon(label: 'Data', icon: Icons.wifi),
                _ServiceIcon(label: 'Airtime', icon: Icons.phone_iphone),
                _ServiceIcon(label: 'Electricity', icon: Icons.flash_on),
                _ServiceIcon(label: 'Cable TV', icon: Icons.tv),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
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

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: filled ? Colors.white : color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
