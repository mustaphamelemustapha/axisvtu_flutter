import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../state/session.dart';
import '../widgets/glass_card.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _phoneCtrl = TextEditingController();
  final bool _ported = false;
  String _network = 'all';
  String? _selectedPlanCode;
  List<dynamic> _plans = [];
  bool _loadingPlans = true;
  String? _error;
  bool _refreshing = false;
  Future<List<dynamic>>? _plansFuture;

  @override
  void initState() {
    super.initState();
    if (DataService.hasCache) {
      _plans = DataService.cachedPlans;
      _loadingPlans = false;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans({bool forceRefresh = false}) async {
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _loadingPlans = true;
      _refreshing = forceRefresh;
      _error = null;
    });
    try {
      final data = await DataService(token: token).getPlans(forceRefresh: forceRefresh);
      setState(() {
        _plans = data;
        final current = _selectedPlanCode;
        _selectedPlanCode = _filteredPlans.isEmpty
            ? null
            : (_filteredPlans.any((p) => p['plan_code']?.toString() == current)
                ? current
                : _filteredPlans.first['plan_code']?.toString());
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _loadingPlans = false;
        _refreshing = false;
      });
    }
  }

  List<dynamic> get _filteredPlans {
    if (_network == 'all') return _plans;
    return _plans.where((plan) {
      final net = (plan['network'] ?? '').toString().toLowerCase();
      return net == _network;
    }).toList();
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)} ${_monthName(value.month)} ${value.year} at ${two(value.hour)}:${two(value.minute)}';
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  String _planLabel(dynamic plan) {
    final capacity = plan['data_capacity'] ?? plan['size'] ?? plan['capacity'] ?? '';
    final validity = plan['validity'] ?? '';
    final price = plan['price'] ?? plan['amount'] ?? '';
    return '$capacity • $validity days • ₦$price';
  }

  String _planCapacity(dynamic plan) {
    return (plan['data_capacity'] ?? plan['size'] ?? plan['capacity'] ?? '').toString();
  }

  String _planPrice(dynamic plan) {
    return (plan['price'] ?? plan['amount'] ?? '').toString();
  }

  String _planValidity(dynamic plan) {
    return (plan['validity'] ?? '').toString();
  }

  String _planNetwork(dynamic plan) {
    return (plan['network'] ?? '').toString().toUpperCase();
  }

  Future<void> _buy() async {
    if (_selectedPlanCode == null || _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a phone number and select a plan.');
      return;
    }
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    setState(() => _error = null);
    try {
      final res = await DataService(token: token).purchase(
        planCode: _selectedPlanCode!,
        phoneNumber: _phoneCtrl.text.trim(),
        ported: _ported,
      );
      if (!mounted) return;
      _showResult(res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {}
  }

  void _showResult(Map<String, dynamic> res) {
    final bool ok = res['success'] == true ||
        (res['status']?.toString().toLowerCase() == 'delivered') ||
        (res['status']?.toString().toLowerCase() == 'success');
    final plans = _filteredPlans;
    final selected = plans.firstWhere(
      (p) => p['plan_code']?.toString() == _selectedPlanCode,
      orElse: () => null,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PurchaseResultSheet(
        success: ok,
        message: res['message']?.toString() ?? (ok ? 'Purchase successful.' : 'Purchase failed.'),
        customerName: (context.read<SessionController>().user?['full_name'] ?? 'AxisVTU User').toString(),
        provider: (res['provider'] ?? 'Amigo').toString(),
        network: selected == null ? '' : _planNetwork(selected),
        capacity: selected == null ? '' : _planCapacity(selected),
        phone: _phoneCtrl.text.trim(),
        timeLabel: _formatDate(DateTime.now()),
        amount: selected == null ? '' : _planPrice(selected),
      ),
    );
  }

  void _openPlansSheet() {
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a phone number to continue.');
      return;
    }
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    setState(() => _error = null);
    setState(() => _loadingPlans = true);
    _plansFuture = DataService(token: token).getPlans().whenComplete(() {
      if (mounted) {
        setState(() => _loadingPlans = false);
      }
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? selectedCode = _selectedPlanCode;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 5,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Available Plans', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    FutureBuilder<List<dynamic>>(
                      future: _plansFuture,
                      builder: (context, snapshot) {
                        if (_loadingPlans || snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: LinearProgressIndicator(minHeight: 2),
                          );
                        }
                        final data = snapshot.data ?? [];
                        _plans = data;
                        final plans = _filteredPlans;
                        if (plans.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('No plans available.', style: Theme.of(context).textTheme.bodySmall),
                          );
                        }
                        selectedCode ??= plans.first['plan_code']?.toString();
                        return Flexible(
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: plans.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              final isSelected = plan['plan_code']?.toString() == selectedCode;
                              return _PlanTile(
                                capacity: _planCapacity(plan),
                                price: _planPrice(plan),
                                validity: _planValidity(plan),
                                selected: isSelected,
                                onTap: () => setSheetState(
                                  () => selectedCode = plan['plan_code']?.toString(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (selectedCode == null) return;
                              setState(() => _selectedPlanCode = selectedCode);
                              Navigator.of(context).pop();
                              _buy();
                            },
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _filteredPlans;
    final selected = plans.firstWhere(
      (p) => p['plan_code']?.toString() == _selectedPlanCode,
      orElse: () => null,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              _CircleAction(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi, size: 18),
                        const SizedBox(width: 6),
                        Text('Data', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: _refreshing ? Icons.sync : Icons.refresh_rounded,
                onTap: () => _loadPlans(forceRefresh: true),
              ),
              const SizedBox(width: 10),
              _CircleAction(
                icon: Icons.history,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send to:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (080...)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _NetworkChip(
                      label: 'MTN',
                      selected: _network == 'mtn',
                      onTap: () => _selectNetwork('mtn'),
                    ),
                    _NetworkChip(
                      label: 'Airtel',
                      selected: _network == 'airtel',
                      onTap: () => _selectNetwork('airtel'),
                    ),
                    _NetworkChip(
                      label: 'Glo',
                      selected: _network == 'glo',
                      onTap: () => _selectNetwork('glo'),
                    ),
                    _NetworkChip(
                      label: '9mobile',
                      selected: _network == '9mobile',
                      onTap: () => _selectNetwork('9mobile'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 140,
                    child: FilledButton.icon(
                      onPressed: _openPlansSheet,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
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
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected: ${_planLabel(selected)}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectNetwork(String value) {
    setState(() {
      _network = value;
      final plans = _filteredPlans;
      _selectedPlanCode = plans.isNotEmpty ? plans.first['plan_code']?.toString() : null;
    });
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600),
        ),
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.capacity,
    required this.price,
    required this.validity,
    required this.selected,
    required this.onTap,
  });

  final String capacity;
  final String price;
  final String validity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(capacity, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('₦$price', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Text('$validity days', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseResultSheet extends StatelessWidget {
  const _PurchaseResultSheet({
    required this.success,
    required this.message,
    required this.customerName,
    required this.provider,
    required this.network,
    required this.capacity,
    required this.phone,
    required this.timeLabel,
    required this.amount,
  });

  final bool success;
  final String message;
  final String customerName;
  final String provider;
  final String network;
  final String capacity;
  final String phone;
  final String timeLabel;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: success ? const Color(0xFFD1FADF) : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.close_rounded,
              color: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            success ? 'Purchase Successful' : 'Purchase Failed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long),
                    const SizedBox(width: 8),
                    Text('Transfer Receipt', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: success ? const Color(0xFFD1FADF) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(success ? 'Successful' : 'Failed'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ReceiptRow(label: 'Time', value: timeLabel),
                _ReceiptRow(label: 'Sender Name', value: customerName),
                _ReceiptRow(label: 'Provider', value: provider),
                _ReceiptRow(label: 'Data Capacity', value: capacity),
                _ReceiptRow(label: 'Network', value: network),
                _ReceiptRow(label: 'Receiver Phone', value: phone),
                if (amount.isNotEmpty) _ReceiptRow(label: 'Amount', value: '₦$amount'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Download Receipt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
