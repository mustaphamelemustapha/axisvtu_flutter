import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/purchase_auth_service.dart';
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
  static const _saveBeneficiaryKey = 'axis_electricity_save_beneficiary_v1';
  static const _beneficiariesKey = 'axis_electricity_beneficiaries_v1';
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
  List<Map<String, dynamic>> _beneficiaries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadPreferences();
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_saveBeneficiaryKey) ?? _saveBeneficiary;
    final raw = prefs.getString(_beneficiariesKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            list.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _saveBeneficiary = enabled;
      _beneficiaries = list;
    });
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveBeneficiaryKey, value);
  }

  Future<void> _saveBeneficiaryFromInput() async {
    if (!_saveBeneficiary) return;
    final meterNumber = _meterNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final amount = _amountCtrl.text.trim();
    if (meterNumber.isEmpty || phone.isEmpty) return;

    final entry = <String, dynamic>{
      'disco': _disco,
      'meter_type': _meterType,
      'meter_number': meterNumber,
      'phone_number': phone,
      'amount': amount,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final identity =
        '${_disco.toLowerCase()}|${_meterType.toLowerCase()}|$meterNumber';
    final next = <Map<String, dynamic>>[
      entry,
      ..._beneficiaries.where((item) {
        final key =
            '${(item['disco'] ?? '').toString().toLowerCase()}|${(item['meter_type'] ?? '').toString().toLowerCase()}|${(item['meter_number'] ?? '').toString()}';
        return key != identity;
      }),
    ].take(10).toList();

    setState(() => _beneficiaries = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_beneficiariesKey, jsonEncode(next));
  }

  void _applyBeneficiary(Map<String, dynamic> item) {
    final disco = (item['disco'] ?? _disco).toString().toLowerCase();
    final meterType = (item['meter_type'] ?? _meterType)
        .toString()
        .toLowerCase();
    final meterNumber = (item['meter_number'] ?? '').toString().trim();
    final phone = (item['phone_number'] ?? '').toString().trim();
    final amount = (item['amount'] ?? '').toString().trim();
    HapticFeedback.mediumImpact();
    setState(() {
      if (_discos.contains(disco)) {
        _disco = disco;
      }
      if (meterType == 'prepaid' || meterType == 'postpaid') {
        _meterType = meterType;
      }
      _meterNumberCtrl.text = meterNumber;
      _phoneCtrl.text = phone;
      if (amount.isNotEmpty) {
        _amountCtrl.text = amount;
      }
    });
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

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'electricity purchase',
    );
    if (!mounted || !authorized) return;

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
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      if (status != 'failed') {
        await _saveBeneficiaryFromInput();
      }
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
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
        title: _statusTitle(
          status: status,
          success: 'Electricity Purchase Successful',
          pending: 'Electricity Purchase Pending',
          failed: 'Electricity Purchase Failed',
        ),
        subtitle: subtitle,
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ...fields,
          ReceiptField(label: 'Reference', value: reference),
        ],
      ),
    );
  }

  String _resolveResultStatus(Map<String, dynamic> payload) {
    final statusRaw = (payload['status'] ?? '').toString().trim().toLowerCase();
    final ok =
        payload['success'] == true ||
        statusRaw == 'success' ||
        statusRaw == 'successful' ||
        statusRaw == 'delivered' ||
        statusRaw == 'completed' ||
        statusRaw == 'order_completed';
    if (ok) return 'success';
    final pending =
        statusRaw == 'pending' ||
        statusRaw == 'processing' ||
        statusRaw == 'queued' ||
        statusRaw == 'order_received' ||
        statusRaw == 'order_onhold';
    if (pending) return 'pending';
    return 'failed';
  }

  String _statusTitle({
    required String status,
    required String success,
    required String pending,
    required String failed,
  }) {
    final normalized = status.toLowerCase();
    if (normalized == 'success') return success;
    if (normalized == 'pending') return pending;
    return failed;
  }

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final message = (payload['message'] ?? payload['detail'] ?? '')
        .toString()
        .trim();
    if (message.isNotEmpty) return message;
    if (status == 'success') {
      return 'Electricity purchase completed successfully.';
    }
    if (status == 'pending') {
      return 'Electricity request received and currently processing.';
    }
    return 'Electricity purchase failed.';
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
            child: Column(
              children: [
                if (_beneficiaries.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _beneficiaries.map((item) {
                        final disco = (item['disco'] ?? '')
                            .toString()
                            .toUpperCase();
                        final meterType = (item['meter_type'] ?? '')
                            .toString()
                            .toUpperCase();
                        final meter = (item['meter_number'] ?? '')
                            .toString()
                            .trim();
                        return ActionChip(
                          avatar: const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            '$disco • $meterType • ${meter.length > 6 ? '${meter.substring(0, 3)}***${meter.substring(meter.length - 3)}' : meter}',
                          ),
                          onPressed: () => _applyBeneficiary(item),
                        );
                      }).toList(),
                    ),
                  ),
                if (_beneficiaries.isNotEmpty) const SizedBox(height: 10),
                Row(
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
                        _savePreference(v);
                      },
                    ),
                  ],
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
