import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/purchase_auth_service.dart';
import '../services/request_id.dart';
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
  static const _saveBeneficiaryKey = 'axis_cable_save_beneficiary_v1';
  static const _beneficiariesKey = 'axis_cable_beneficiaries_v1';
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
  String? _activeRequestId;
  bool _saveBeneficiary = true;
  List<Map<String, dynamic>> _beneficiaries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _smartcardCtrl.addListener(_invalidateRequestId);
    _phoneCtrl.addListener(_invalidateRequestId);
    _packageCtrl.addListener(_invalidateRequestId);
    _amountCtrl.addListener(_invalidateRequestId);
    _loadCatalog();
    _loadPreferences();
  }

  @override
  void dispose() {
    _smartcardCtrl.removeListener(_invalidateRequestId);
    _phoneCtrl.removeListener(_invalidateRequestId);
    _packageCtrl.removeListener(_invalidateRequestId);
    _amountCtrl.removeListener(_invalidateRequestId);
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

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveBeneficiaryKey, value);
  }

  Future<void> _saveBeneficiaryFromInput() async {
    if (!_saveBeneficiary) return;
    final smartcard = _smartcardCtrl.text.trim();
    final packageCode = _packageCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (smartcard.isEmpty || packageCode.isEmpty || phone.isEmpty) return;

    final entry = <String, dynamic>{
      'provider': _provider,
      'smartcard_number': smartcard,
      'package_code': packageCode,
      'phone_number': phone,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final identity = '${_provider.toLowerCase()}|$smartcard|$packageCode';
    final next = <Map<String, dynamic>>[
      entry,
      ..._beneficiaries.where((item) {
        final key =
            '${(item['provider'] ?? '').toString().toLowerCase()}|${(item['smartcard_number'] ?? '').toString()}|${(item['package_code'] ?? '').toString().toLowerCase()}';
        return key != identity;
      }),
    ].take(10).toList();

    setState(() => _beneficiaries = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_beneficiariesKey, jsonEncode(next));
  }

  void _applyBeneficiary(Map<String, dynamic> item) {
    final provider = (item['provider'] ?? _provider).toString().toLowerCase();
    final smartcard = (item['smartcard_number'] ?? '').toString().trim();
    final packageCode = (item['package_code'] ?? '').toString().trim();
    final phone = (item['phone_number'] ?? '').toString().trim();
    HapticFeedback.mediumImpact();
    setState(() {
      _invalidateRequestId();
      if (_providers.any((p) => p['id'] == provider)) {
        _provider = provider;
      }
      _smartcardCtrl.text = smartcard;
      _packageCtrl.text = packageCode;
      _phoneCtrl.text = phone;
    });
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

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'cable subscription',
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Paying cable subscription');

    try {
      _activeRequestId ??= buildRequestId("cable");
      final res = await ServicesService(token: token).purchaseCable(
        provider: _provider,
        smartcardNumber: smartcard,
        phoneNumber: phone,
        packageCode: packageCode,
        amount: amount,
        clientRequestId: _activeRequestId,
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
          ReceiptField(label: 'Provider', value: _provider.toUpperCase()),
          ReceiptField(label: 'Smartcard', value: smartcard),
          ReceiptField(label: 'Package', value: packageCode),
          ReceiptField(label: 'Phone', value: phone),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
        ],
      );
      if (status != 'pending') {
        _activeRequestId = null;
      }
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
      _activeRequestId = null;
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
          success: 'Cable Purchase Successful',
          pending: 'Cable Purchase Pending',
          failed: 'Cable Purchase Failed',
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
    if (status == 'success') return 'Cable purchase completed successfully.';
    if (status == 'pending') {
      return 'Cable request received and currently processing.';
    }
    return 'Cable purchase failed.';
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
                        _invalidateRequestId();
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
                          onPressed: () => setState(() {
                            _invalidateRequestId();
                            _amountCtrl.text = v.toString();
                          }),
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
                        final provider = (item['provider'] ?? '')
                            .toString()
                            .toUpperCase();
                        final smartcard = (item['smartcard_number'] ?? '')
                            .toString();
                        final package = (item['package_code'] ?? '')
                            .toString()
                            .toUpperCase();
                        return ActionChip(
                          avatar: const Icon(Icons.live_tv_rounded, size: 16),
                          label: Text(
                            '$provider • $package • ${smartcard.length > 6 ? '${smartcard.substring(0, 3)}***${smartcard.substring(smartcard.length - 3)}' : smartcard}',
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
                        'Auto-save smartcard and package',
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
