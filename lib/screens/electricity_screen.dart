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

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final _meterNumberCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '2000');

  String _disco = 'ikeja';
  String _meterType = 'prepaid';
  List<String> _discos = const [
    'ikeja',
    'eko',
    'abuja',
    'kano',
    'ibadan',
    'enugu',
    'portharcourt',
    'kaduna',
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
    _meterNumberCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['electricity_discos'];
      if (raw is List && raw.isNotEmpty) {
        final items = raw
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _discos = items;
          if (!_discos.contains(_disco)) {
            _disco = _discos.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final meterNumber = _meterNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (meterNumber.length < 6 || meterNumber.length > 13) {
      setState(() => _error = 'Enter a valid meter number.');
      return;
    }
    if (phone.length < 7 || phone.length > 15) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    if (amount < 500) {
      setState(() => _error = 'Minimum electricity amount is ₦500.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Buying electricity');

    try {
      final res = await ServicesService(token: token).purchaseElectricity(
        disco: _disco,
        meterType: _meterType,
        meterNumber: meterNumber,
        phoneNumber: phone,
        amount: amount,
      );
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: (res['status'] ?? 'success').toString(),
        subtitle: 'Electricity request has been submitted successfully.',
        reference: (res['reference'] ?? '').toString(),
        fields: [
          ReceiptField(label: 'Disco', value: _disco.toUpperCase()),
          ReceiptField(label: 'Meter Number', value: meterNumber),
          ReceiptField(label: 'Meter Type', value: _meterType.toUpperCase()),
          ReceiptField(label: 'Phone', value: phone),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
          ReceiptField(label: 'Token', value: (res['token'] ?? '').toString()),
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
            'AXIS-ELECTRICITY-ATTEMPT-${DateTime.now().millisecondsSinceEpoch}',
        fields: [
          ReceiptField(label: 'Disco', value: _disco.toUpperCase()),
          ReceiptField(label: 'Meter Number', value: meterNumber),
          ReceiptField(label: 'Meter Type', value: _meterType.toUpperCase()),
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
            ? 'Electricity Purchase Failed'
            : 'Electricity Purchase Successful',
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
      title: 'Electricity',
      subtitle: 'Pay prepaid or postpaid meter with a polished checkout.',
      icon: Icons.flash_on_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Disco',
            subtitle: 'Select your electricity distribution company.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _discos
                  .map(
                    (n) => ServiceChoiceChip(
                      label: n.toUpperCase(),
                      selected: _disco == n,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _disco = n);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          ServiceSectionCard(
            title: 'Meter Type',
            child: Wrap(
              spacing: 10,
              children: [
                ServiceChoiceChip(
                  label: 'PREPAID',
                  selected: _meterType == 'prepaid',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _meterType = 'prepaid');
                  },
                ),
                ServiceChoiceChip(
                  label: 'POSTPAID',
                  selected: _meterType == 'postpaid',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _meterType = 'postpaid');
                  },
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Payment Details',
            subtitle: 'Fill meter number, phone and amount.',
            child: Column(
              children: [
                TextField(
                  controller: _meterNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Meter Number',
                    prefixIcon: Icon(Icons.pin_outlined),
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
                  children: [1000, 2000, 5000, 10000]
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
            subtitle: 'Review before buying electricity token.',
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
                    '${_disco.toUpperCase()} • ${_meterType.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meter: ${_meterNumberCtrl.text.trim().isEmpty ? '—' : _meterNumberCtrl.text.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Amount: ₦${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Beneficiary',
            subtitle: 'Save meter details for one-tap next payment.',
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-save meter profile',
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
            label: 'Buy Electricity',
            icon: Icons.flash_on_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
