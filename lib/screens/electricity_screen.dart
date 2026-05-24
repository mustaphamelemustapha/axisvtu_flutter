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
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';
import '../widgets/sticky_checkout_bar.dart';
import '../widgets/insufficient_funds_sheet.dart';
import '../utils/balance_util.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart' as native_contact;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/elite_phone_input.dart';
import '../services/permission_service.dart';

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
  bool _verifying = false;
  String? _activeRequestId;
  bool _saveBeneficiary = true;
  List<Map<String, dynamic>> _beneficiaries = [];
  String? _error;

  // Verification state
  bool _verificationChecked = false;
  bool _verificationOk = false;
  String _verifiedCustomerName = '';
  String _verificationMessage = '';

  @override
  void initState() {
    super.initState();
    _meterNumberCtrl.addListener(_invalidateRequestId);
    _meterNumberCtrl.addListener(_clearVerification);
    _phoneCtrl.addListener(_invalidateRequestId);
    _amountCtrl.addListener(_invalidateRequestId);
    _loadCatalog();
    _loadPreferences();
  }

  @override
  void dispose() {
    _meterNumberCtrl.removeListener(_invalidateRequestId);
    _meterNumberCtrl.removeListener(_clearVerification);
    _phoneCtrl.removeListener(_invalidateRequestId);
    _amountCtrl.removeListener(_invalidateRequestId);
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
          _invalidateRequestId();
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

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  Future<void> _pickContact() async {
    try {
      final granted = await PermissionService.requestContactPermission(context);
      if (!granted) return;

      final native_contact.Contact? contact = await _contactPicker.selectContact();
      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        String phone = contact.phoneNumbers!.first.replaceAll(RegExp(r'\D'), '');
        // Strip 234 prefix if present
        if (phone.startsWith('234') && phone.length > 10) {
          phone = '0${phone.substring(3)}';
        }
        _phoneCtrl.text = phone;
        _invalidateRequestId();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
    }
  }

  void _clearVerification() {
    if (_verificationChecked || _verificationOk) {
      setState(() {
        _verificationChecked = false;
        _verificationOk = false;
        _verifiedCustomerName = '';
        _verificationMessage = '';
      });
    }
  }

  Future<void> _verifyMeter() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final meterNumber = _meterNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (meterNumber.length < 5) {
      setState(() => _error = 'Enter a valid meter number to verify.');
      return;
    }

    setState(() {
      _verifying = true;
      _verificationChecked = false;
      _verificationOk = false;
      _verifiedCustomerName = '';
      _verificationMessage = '';
      _error = null;
    });

    try {
      final res = await ServicesService(token: token).verifyElectricity(
        disco: _disco,
        meterType: _meterType,
        meterNumber: meterNumber,
      );
      final ok = res['ok'] == true;
      setState(() {
        _verificationChecked = true;
        _verificationOk = ok;
        _verifiedCustomerName = ok
            ? (res['customer_name'] ?? '').toString().trim()
            : '';
        _verificationMessage = ok
            ? 'Meter verified successfully.'
            : (res['message'] ?? 'Unable to verify meter number.').toString();
      });
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      setState(() {
        _verificationChecked = true;
        _verificationOk = false;
        _verificationMessage = msg.isNotEmpty
            ? msg
            : 'Unable to verify meter number right now.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
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
      _invalidateRequestId();
      _verificationChecked = false;
      _verificationOk = false;
      _verifiedCustomerName = '';
      _verificationMessage = '';
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

  Future<void> _submit({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final meterNumber = _meterNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (!_verificationOk) {
      setState(() => _error = 'Please verify your meter number before paying.');
      return;
    }
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
      reason: 'electricity subscription',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("electricity");
      final res = await ServicesService(token: token).purchaseElectricity(
        disco: _disco,
        meterType: _meterType,
        meterNumber: meterNumber,
        phoneNumber: phone,
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
          ReceiptField(label: 'Disco', value: _disco.toUpperCase()),
          ReceiptField(label: 'Meter Number', value: meterNumber),
          ReceiptField(label: 'Meter Type', value: _meterType.toUpperCase()),
          if (_verifiedCustomerName.isNotEmpty)
            ReceiptField(label: 'Customer Name', value: _verifiedCustomerName),
          ReceiptField(label: 'Phone', value: phone),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
          ReceiptField(label: 'Token', value: (res['token'] ?? '').toString()),
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
      _activeRequestId = null;
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAuthChoiceSheet() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final meter = _meterNumberCtrl.text.trim();

    final balance = getUserBalance(context);
    if (balance < amount) {
      InsufficientFundsSheet.show(context, shortfall: amount - balance);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DualAuthSheet(
        title: 'Electricity Summary',
        subtitle: '${_disco.toUpperCase()} • $meter',
        amount: '₦${amount.toStringAsFixed(2)}',
        onPin: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodPin);
        },
        onBiometric: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodBiometric);
        },
      ),
    );
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    if (status != 'failed') {
      context.read<SessionController>().refreshBalance();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: _statusTitle(
          status: status,
          success: 'Electricity Order Successful',
          pending: 'Electricity Order Pending',
          failed: 'Electricity Order Failed',
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
      return 'Electricity order completed successfully.';
    }
    if (status == 'pending') {
      return 'Electricity request received and currently processing.';
    }
    return 'Electricity order failed.';
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
      footer: StickyCheckoutBar(
        title: _disco.toUpperCase(),
        subtitle: _meterNumberCtrl.text.trim().isEmpty
            ? 'Enter meter number'
            : _meterNumberCtrl.text.trim(),
        amount: '₦${amount.toStringAsFixed(2)}',
        active: _verificationOk && !_loading && amount >= 500,
        loading: _loading,
        onBuy: _showAuthChoiceSheet,
        actionLabel: 'Confirm',
        icon: Icons.flash_on_rounded,
      ),
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Disco',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _discos.map((n) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ServiceChoiceChip(
                      label: n.toUpperCase(),
                      selected: _disco == n,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _invalidateRequestId();
                        setState(() {
                          _disco = n;
                          _verificationChecked = false;
                          _verificationOk = false;
                          _verifiedCustomerName = '';
                          _verificationMessage = '';
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Meter Type',
            child: Row(
              children: [
                ServiceChoiceChip(
                  label: 'PREPAID',
                  selected: _meterType == 'prepaid',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _invalidateRequestId();
                    setState(() {
                      _meterType = 'prepaid';
                      _verificationChecked = false;
                      _verificationOk = false;
                      _verifiedCustomerName = '';
                      _verificationMessage = '';
                    });
                  },
                ),
                const SizedBox(width: 10),
                ServiceChoiceChip(
                  label: 'POSTPAID',
                  selected: _meterType == 'postpaid',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _invalidateRequestId();
                    setState(() {
                      _meterType = 'postpaid';
                      _verificationChecked = false;
                      _verificationOk = false;
                      _verifiedCustomerName = '';
                      _verificationMessage = '';
                    });
                  },
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Payment Details',
            child: Column(
              children: [
                TextField(
                  controller: _meterNumberCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'Meter Number',
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // --- Verify Meter button & feedback ---
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _verifying ? null : _verifyMeter,
                        icon: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 18),
                        label: Text(
                          _verifying ? 'Verifying...' : 'Verify Meter Account',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_verificationChecked) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final okBg = isDark
                          ? const Color(0xFF123322)
                          : const Color(0xFFEAF9EF);
                      final failBg = isDark
                          ? const Color(0xFF3A1818)
                          : const Color(0xFFFDECEC);
                      final okBorder = isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF22C55E);
                      final failBorder = isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFEF4444);
                      final okText = isDark
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFF166534);
                      final failText = isDark
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFF991B1B);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _verificationOk ? okBg : failBg,
                          border: Border.all(
                            color: _verificationOk ? okBorder : failBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _verificationOk
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.cancel_outlined,
                              size: 18,
                              color: _verificationOk ? okText : failText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _verificationOk &&
                                        _verifiedCustomerName.isNotEmpty
                                    ? 'Customer: $_verifiedCustomerName'
                                    : _verificationMessage,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _verificationOk ? okText : failText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                ElitePhoneInput(
                  controller: _phoneCtrl,
                  network: 'mtn',
                  onChanged: (v) => _invalidateRequestId(),
                  onContactTap: _pickContact,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'Amount (₦)',
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DualAuthSheet extends StatelessWidget {
  const _DualAuthSheet({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onPin,
    required this.onBiometric,
  });

  final String title;
  final String subtitle;
  final String amount;
  final VoidCallback onPin;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPin,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Use PIN'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use Biometric'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
