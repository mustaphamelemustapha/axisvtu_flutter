import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../state/session.dart';
import '../widgets/app_header.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _phoneCtrl = TextEditingController();
  bool _ported = false;
  String _network = 'all';
  String? _selectedPlanCode;
  List<dynamic> _plans = [];
  bool _loadingPlans = true;
  bool _loadingPurchase = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _loadingPlans = true;
      _error = null;
    });
    try {
      final data = await DataService(token: token).getPlans();
      setState(() {
        _plans = data;
        _selectedPlanCode = _filteredPlans.isNotEmpty ? _filteredPlans.first['plan_code']?.toString() : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingPlans = false);
    }
  }

  List<dynamic> get _filteredPlans {
    if (_network == 'all') return _plans;
    return _plans.where((plan) {
      final net = (plan['network'] ?? '').toString().toLowerCase();
      return net == _network;
    }).toList();
  }

  String _planLabel(dynamic plan) {
    final capacity = plan['data_capacity'] ?? plan['size'] ?? plan['capacity'] ?? '';
    final validity = plan['validity'] ?? '';
    final price = plan['price'] ?? plan['amount'] ?? '';
    return '$capacity • $validity days • ₦$price';
  }

  Future<void> _buy() async {
    if (_selectedPlanCode == null || _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a phone number and select a plan.');
      return;
    }
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _loadingPurchase = true;
      _error = null;
    });
    try {
      final res = await DataService(token: token).purchase(
        planCode: _selectedPlanCode!,
        phoneNumber: _phoneCtrl.text.trim(),
        ported: _ported,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Purchase Result'),
          content: Text(res['message']?.toString() ?? 'Request submitted.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingPurchase = false);
    }
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
          const AppHeader(
            title: 'Buy Data',
            subtitle: 'Fast top-up with instant receipt.',
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                DropdownMenu<String>(
                  initialSelection: _network,
                  label: const Text('Network'),
                  expandedInsets: const EdgeInsets.all(0),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'all', label: 'All Networks'),
                    DropdownMenuEntry(value: 'mtn', label: 'MTN'),
                    DropdownMenuEntry(value: 'glo', label: 'GLO'),
                    DropdownMenuEntry(value: 'airtel', label: 'Airtel'),
                    DropdownMenuEntry(value: '9mobile', label: '9mobile'),
                  ],
                  onSelected: (value) {
                    setState(() {
                      _network = value ?? 'all';
                      _selectedPlanCode = plans.isNotEmpty ? plans.first['plan_code']?.toString() : null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_loadingPlans)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  DropdownMenu<String>(
                    initialSelection: _selectedPlanCode,
                    label: const Text('Plan'),
                    expandedInsets: const EdgeInsets.all(0),
                    dropdownMenuEntries: plans
                        .map(
                          (plan) => DropdownMenuEntry(
                            value: plan['plan_code']?.toString() ?? '',
                            label: _planLabel(plan),
                          ),
                        )
                        .toList(),
                    onSelected: (value) => setState(() => _selectedPlanCode = value),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Receiver phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _ported,
                  onChanged: (value) => setState(() => _ported = value),
                  title: const Text('Ported number'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                PrimaryButton(
                  label: _loadingPurchase ? 'Processing...' : 'Buy now',
                  loading: _loadingPurchase,
                  onPressed: _loadingPurchase ? null : _buy,
                ),
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Selected: ${_planLabel(selected)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
