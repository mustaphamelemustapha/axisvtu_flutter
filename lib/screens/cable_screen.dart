import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import '../widgets/primary_button.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  final _smartcardCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _packageCtrl = TextEditingController(text: 'basic');
  final _amountCtrl = TextEditingController(text: '5000');

  String _provider = 'dstv';
  List<Map<String, String>> _providers = const [
    {'id': 'dstv', 'name': 'DStv'},
    {'id': 'gotv', 'name': 'GOtv'},
    {'id': 'startimes', 'name': 'StarTimes'},
  ];
  bool _loading = false;
  bool _saveBeneficiary = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _smartcardCtrl.dispose();
    _phoneCtrl.dispose();
    _packageCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['cable_providers'];
      if (raw is List && raw.isNotEmpty) {
        final providers = <Map<String, String>>[];
        for (final item in raw) {
          if (item is Map) {
            final id = (item['id'] ?? '').toString().trim().toLowerCase();
            final name = (item['name'] ?? id).toString().trim();
            if (id.isNotEmpty) {
              providers.add({
                'id': id,
                'name': name.isEmpty ? id.toUpperCase() : name,
              });
            }
          }
        }
        if (!mounted || providers.isEmpty) return;
        setState(() {
          _providers = providers;
          final ids = _providers
              .map((e) => e['id'])
              .whereType<String>()
              .toList();
          if (!ids.contains(_provider)) {
            _provider = ids.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final smartcard = _smartcardCtrl.text.trim();
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final packageCode = _packageCtrl.text.trim().toLowerCase();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (smartcard.length < 5) {
      setState(() => _error = 'Enter a valid smartcard number.');
      return;
    }
    if (phone.length < 7 || phone.length > 15) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    if (packageCode.length < 2) {
      setState(() => _error = 'Enter a valid package code.');
      return;
    }
    if (amount < 500) {
      setState(() => _error = 'Minimum cable amount is ₦500.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Paying cable subscription');

    try {
      final res = await ServicesService(token: token).purchaseCable(
        provider: _provider,
        smartcardNumber: smartcard,
        phoneNumber: phone,
        packageCode: packageCode,
        amount: amount,
      );
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: (res['status'] ?? 'success').toString(),
        subtitle: 'Cable request has been submitted successfully.',
        reference: (res['reference'] ?? '').toString(),
        fields: [
          ReceiptField(label: 'Provider', value: _provider.toUpperCase()),
          ReceiptField(label: 'Smartcard', value: smartcard),
          ReceiptField(label: 'Package', value: packageCode),
          ReceiptField(label: 'Phone', value: phone),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: 'failed',
        subtitle: message,
        reference:
            'AXIS-CABLE-ATTEMPT-${DateTime.now().millisecondsSinceEpoch}',
        fields: [
          ReceiptField(label: 'Provider', value: _provider.toUpperCase()),
          ReceiptField(label: 'Smartcard', value: smartcard),
          ReceiptField(label: 'Package', value: packageCode),
          ReceiptField(label: 'Phone', value: phone),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
          ReceiptField(label: 'Failure', value: message),
        ],
      );
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: status.toLowerCase() == 'failed'
            ? 'Cable Purchase Failed'
            : 'Cable Purchase Successful',
        subtitle: subtitle,
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ...fields,
          ReceiptField(label: 'Reference', value: reference),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return ServiceShell(
      title: 'Cable TV',
      subtitle: 'Pay DStv, GOtv and StarTimes with premium checkout flow.',
      icon: Icons.tv_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Choose Provider',
            subtitle: 'Select your cable platform.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _providers
                  .map(
                    (p) => ServiceChoiceChip(
                      label: (p['name'] ?? p['id'] ?? '').toString(),
                      selected: _provider == p['id'],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(
                          () => _provider = (p['id'] ?? _provider).toString(),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          ServiceSectionCard(
            title: 'Subscription Details',
            subtitle: 'Fill decoder number, package and contact.',
            child: Column(
              children: [
                TextField(
                  controller: _smartcardCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Smartcard Number',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _packageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Package Code',
                    hintText: 'e.g. basic',
                    prefixIcon: Icon(Icons.grid_view_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₦)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2500, 5000, 10000, 15000]
                      .map(
                        (v) => ActionChip(
                          label: Text('₦$v'),
                          onPressed: () =>
                              setState(() => _amountCtrl.text = v.toString()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Checkout',
            subtitle: 'Review details before payment.',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    const Color(0xFF0FB5AE).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_provider.toUpperCase()} • ₦${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smartcard: ${_smartcardCtrl.text.trim().isEmpty ? '—' : _smartcardCtrl.text.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Package: ${_packageCtrl.text.trim().isEmpty ? '—' : _packageCtrl.text.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Beneficiary',
            subtitle: 'Keep this decoder details for faster repeat payment.',
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-save smartcard and package',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _saveBeneficiary,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _saveBeneficiary = v);
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            ServiceSectionCard(
              title: 'Validation',
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          PrimaryButton(
            label: 'Pay Cable',
            icon: Icons.tv_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
