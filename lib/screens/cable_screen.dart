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
import '../widgets/elite_phone_input.dart';
import '../services/permission_service.dart';

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  static const _saveBeneficiaryKey = 'axis_cable_save_beneficiary_v1';
  static const _beneficiariesKey   = 'axis_cable_beneficiaries_v1';

  final _smartcardCtrl = TextEditingController();
  final _phoneCtrl     = TextEditingController();

  String _provider = 'dstv';
  List<Map<String, String>> _providers = const [
    {'id': 'dstv',      'name': 'DStv'},
    {'id': 'gotv',      'name': 'GOtv'},
    {'id': 'startimes', 'name': 'StarTimes'},
    {'id': 'showmax',   'name': 'Showmax'},
  ];

  // ── package state ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _packages      = [];
  bool                       _packagesLoading = false;
  String?                    _packagesError;
  Map<String, dynamic>?      _selectedPackage;

  // ── purchase / ui state ───────────────────────────────────────────────────
  bool    _loading           = false;
  bool    _verifying         = false;
  String? _activeRequestId;
  bool    _saveBeneficiary   = true;
  List<Map<String, dynamic>> _beneficiaries = [];
  String? _error;

  // ── verification state ────────────────────────────────────────────────────
  bool   _verificationChecked  = false;
  bool   _verificationOk       = false;
  String _verifiedCustomerName = '';
  String _verificationMessage  = '';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _smartcardCtrl.addListener(_invalidateRequestId);
    _smartcardCtrl.addListener(_clearVerification);
    _phoneCtrl.addListener(_invalidateRequestId);
    _loadCatalog();
    _loadPreferences();
    _loadPackages();
  }

  @override
  void dispose() {
    _smartcardCtrl.removeListener(_invalidateRequestId);
    _smartcardCtrl.removeListener(_clearVerification);
    _phoneCtrl.removeListener(_invalidateRequestId);
    _smartcardCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  void _invalidateRequestId() => _activeRequestId = null;

  void _clearVerification() {
    if (_verificationChecked || _verificationOk) {
      setState(() {
        _verificationChecked  = false;
        _verificationOk       = false;
        _verifiedCustomerName = '';
        _verificationMessage  = '';
      });
    }
  }

  double get _selectedAmount {
    final raw = _selectedPackage?['amount'];
    if (raw == null) return 0;
    return (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
  }

  String get _selectedPackageCode =>
      (_selectedPackage?['code'] ?? '').toString();

  String get _selectedPackageName =>
      (_selectedPackage?['name'] ?? '').toString();

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw  = data['cable_providers'];
      if (raw is List && raw.isNotEmpty) {
        final providers = <Map<String, String>>[];
        for (final item in raw) {
          if (item is Map) {
            final id   = (item['id']   ?? '').toString().trim().toLowerCase();
            final name = (item['name'] ?? id).toString().trim();
            if (id.isNotEmpty) {
              providers.add({'id': id, 'name': name.isEmpty ? id.toUpperCase() : name});
            }
          }
        }
        if (!mounted || providers.isEmpty) return;
        setState(() {
          _providers = providers;
          final ids = _providers.map((e) => e['id']).whereType<String>().toList();
          if (!ids.contains(_provider)) _provider = ids.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPackages({String? provider}) async {
    final p     = provider ?? _provider;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _packagesLoading = true;
      _packagesError   = null;
      _packages        = [];
      _selectedPackage = null;
    });

    try {
      final data = await ServicesService(token: token).getCablePackages(provider: p);
      final raw  = data['packages'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _packages = list;
        if (list.isNotEmpty) _selectedPackage = list.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _packagesError = 'Could not load packages. Tap to retry.');
    } finally {
      if (mounted) setState(() => _packagesLoading = false);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_saveBeneficiaryKey) ?? _saveBeneficiary;
    final raw     = prefs.getString(_beneficiariesKey);
    final list    = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) list.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _saveBeneficiary = enabled;
      _beneficiaries   = list;
    });
  }

  // ── verification ──────────────────────────────────────────────────────────

  Future<void> _verifySmartcard() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final smartcard = _smartcardCtrl.text.trim();
    if (smartcard.length < 5) {
      setState(() => _error = 'Enter a valid smartcard number to verify.');
      return;
    }

    setState(() {
      _verifying            = true;
      _verificationChecked  = false;
      _verificationOk       = false;
      _verifiedCustomerName = '';
      _verificationMessage  = '';
      _error                = null;
    });

    try {
      final res = await ServicesService(token: token).verifyCable(
        provider:       _provider,
        smartcardNumber: smartcard,
      );
      final ok = res['ok'] == true;
      setState(() {
        _verificationChecked  = true;
        _verificationOk       = ok;
        _verifiedCustomerName = ok ? (res['customer_name'] ?? '').toString().trim() : '';
        _verificationMessage  = ok
            ? 'Smartcard verified successfully.'
            : (res['message'] ?? 'Unable to verify smartcard number.').toString();
      });
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      setState(() {
        _verificationChecked = true;
        _verificationOk      = false;
        _verificationMessage = msg.isNotEmpty ? msg : 'Unable to verify smartcard number right now.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ── contact picker ────────────────────────────────────────────────────────

  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  Future<void> _pickContact() async {
    try {
      final granted = await PermissionService.requestContactPermission(context);
      if (!granted) return;

      final native_contact.Contact? contact = await _contactPicker.selectContact();
      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        String phone = contact.phoneNumbers!.first.replaceAll(RegExp(r'\D'), '');
        if (phone.startsWith('234') && phone.length > 10) phone = '0${phone.substring(3)}';
        _phoneCtrl.text = phone;
        _invalidateRequestId();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking contact: $e')));
    }
  }

  // ── beneficiary helpers ───────────────────────────────────────────────────

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveBeneficiaryKey, value);
  }

  Future<void> _saveBeneficiaryFromInput() async {
    if (!_saveBeneficiary) return;
    final smartcard   = _smartcardCtrl.text.trim();
    final packageCode = _selectedPackageCode;
    final phone       = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (smartcard.isEmpty || packageCode.isEmpty || phone.isEmpty) return;

    final entry = <String, dynamic>{
      'provider':        _provider,
      'smartcard_number': smartcard,
      'package_code':    packageCode,
      'package_name':    _selectedPackageName,
      'phone_number':    phone,
      'updated_at':      DateTime.now().toIso8601String(),
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
    final provider    = (item['provider'] ?? _provider).toString().toLowerCase();
    final smartcard   = (item['smartcard_number'] ?? '').toString().trim();
    final savedCode   = (item['package_code'] ?? '').toString().trim();
    final phone       = (item['phone_number'] ?? '').toString().trim();
    HapticFeedback.mediumImpact();
    setState(() {
      _invalidateRequestId();
      _verificationChecked  = false;
      _verificationOk       = false;
      _verifiedCustomerName = '';
      _verificationMessage  = '';
      if (_providers.any((p) => p['id'] == provider)) _provider = provider;
      _smartcardCtrl.text = smartcard;
      _phoneCtrl.text     = phone;
    });
    // Load packages for the new provider then restore the saved plan
    _loadPackages(provider: provider).then((_) {
      if (!mounted || savedCode.isEmpty) return;
      final match = _packages.where((p) => (p['code'] ?? '').toString() == savedCode).firstOrNull;
      if (match != null) setState(() => _selectedPackage = match);
    });
  }

  // ── purchase ──────────────────────────────────────────────────────────────

  Future<void> _submit({String authMethod = PurchaseAuthService.methodAuto}) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final smartcard   = _smartcardCtrl.text.trim();
    final phone       = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final packageCode = _selectedPackageCode;
    final amount      = _selectedAmount;

    if (!_verificationOk) {
      setState(() => _error = 'Please verify your smartcard number before paying.');
      return;
    }
    if (smartcard.length < 5) {
      setState(() => _error = 'Enter a valid smartcard number.');
      return;
    }
    if (phone.length < 7 || phone.length > 15) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    if (packageCode.length < 2) {
      setState(() => _error = 'Please select a package.');
      return;
    }
    if (amount < 500) {
      setState(() => _error = 'Selected package has an invalid amount.');
      return;
    }

    final authorized = await PurchaseAuthService.authorizePin(
      context:         context,
      reason:          'cable subscription',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() { _loading = true; _error = null; });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("cable");
      final res = await ServicesService(token: token).purchaseCable(
        provider:         _provider,
        smartcardNumber:  smartcard,
        phoneNumber:      phone,
        packageCode:      packageCode,
        amount:           amount,
        customerName:     _verifiedCustomerName.isNotEmpty ? _verifiedCustomerName : null,
        clientRequestId:  _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      if (status != 'failed') await _saveBeneficiaryFromInput();
      PurchaseLoadingOverlay.hide();
      _showResult(
        status:    status,
        subtitle:  _resultSubtitle(status, res),
        reference: (res['reference'] ?? '').toString(),
        fields: [
          ReceiptField(label: 'Provider',  value: _provider.toUpperCase()),
          ReceiptField(label: 'Smartcard', value: smartcard),
          if (_verifiedCustomerName.isNotEmpty)
            ReceiptField(label: 'Customer', value: _verifiedCustomerName),
          ReceiptField(label: 'Package',   value: _selectedPackageName.isNotEmpty ? _selectedPackageName : packageCode),
          ReceiptField(label: 'Phone',     value: phone),
          ReceiptField(label: 'Amount',    value: '₦${amount.toStringAsFixed(2)}'),
        ],
      );
      if (status != 'pending') _activeRequestId = null;
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      PurchaseLoadingOverlay.hide();
      _showResult(
        status:    'failed',
        subtitle:  message,
        reference: 'AXIS-CABLE-${DateTime.now().millisecondsSinceEpoch}',
        fields: [
          ReceiptField(label: 'Provider',  value: _provider.toUpperCase()),
          ReceiptField(label: 'Smartcard', value: smartcard),
          ReceiptField(label: 'Package',   value: packageCode),
          ReceiptField(label: 'Phone',     value: phone),
          ReceiptField(label: 'Amount',    value: '₦${amount.toStringAsFixed(2)}'),
          ReceiptField(label: 'Failure',   value: message),
        ],
      );
      _activeRequestId = null;
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── auth / result helpers ─────────────────────────────────────────────────

  void _showAuthChoiceSheet() {
    final amount    = _selectedAmount;
    final smartcard = _smartcardCtrl.text.trim();
    final balance   = getUserBalance(context);
    if (balance < amount) {
      InsufficientFundsSheet.show(context, shortfall: amount - balance);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DualAuthSheet(
        title:    'Cable Summary',
        subtitle: '${_provider.toUpperCase()} • $smartcard',
        amount:   '₦${amount.toStringAsFixed(2)}',
        onPin: () { Navigator.pop(context); _submit(authMethod: PurchaseAuthService.methodPin); },
        onBiometric: () { Navigator.pop(context); _submit(authMethod: PurchaseAuthService.methodBiometric); },
      ),
    );
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    if (status != 'failed') context.read<SessionController>().refreshBalance();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status:   status,
        title:    _statusTitle(status: status, success: 'Cable Order Successful', pending: 'Cable Order Pending', failed: 'Cable Order Failed'),
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
    final s = (payload['status'] ?? '').toString().trim().toLowerCase();
    if (payload['success'] == true || s == 'success' || s == 'successful' || s == 'delivered' || s == 'completed' || s == 'order_completed') return 'success';
    if (s == 'pending' || s == 'processing' || s == 'queued' || s == 'order_received' || s == 'order_onhold') return 'pending';
    return 'failed';
  }

  String _statusTitle({required String status, required String success, required String pending, required String failed}) {
    if (status == 'success') return success;
    if (status == 'pending') return pending;
    return failed;
  }

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final msg = (payload['message'] ?? payload['detail'] ?? '').toString().trim();
    if (msg.isNotEmpty) return msg;
    if (status == 'success') return 'Cable order completed successfully.';
    if (status == 'pending') return 'Cable request received and currently processing.';
    return 'Cable order failed.';
  }

  String _formatDate(DateTime v) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(v.day)}/${two(v.month)}/${v.year} ${two(v.hour)}:${two(v.minute)}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final amount = _selectedAmount;
    return ServiceShell(
      title:    'Cable TV',
      subtitle: 'Pay DStv, GOtv, StarTimes and Showmax.',
      icon:     Icons.tv_rounded,
      footer: StickyCheckoutBar(
        title:    _provider.toUpperCase(),
        subtitle: _smartcardCtrl.text.trim().isEmpty
            ? 'Enter decoder number'
            : _smartcardCtrl.text.trim(),
        amount:   amount > 0 ? '₦${amount.toStringAsFixed(2)}' : '—',
        active:   _verificationOk && !_loading && _selectedPackage != null && amount >= 500,
        loading:  _loading,
        onBuy:    _showAuthChoiceSheet,
        actionLabel: 'Confirm',
        icon:     Icons.tv_rounded,
      ),
      child: Column(
        children: [
          // ── Provider chips ──────────────────────────────────────────────
          ServiceSectionCard(
            title: 'Choose Provider',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _providers.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ServiceChoiceChip(
                    label:    (p['name'] ?? p['id'] ?? '').toString(),
                    selected: _provider == p['id'],
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final newProvider = (p['id'] ?? _provider).toString();
                      if (newProvider == _provider) return;
                      _invalidateRequestId();
                      setState(() {
                        _provider             = newProvider;
                        _verificationChecked  = false;
                        _verificationOk       = false;
                        _verifiedCustomerName = '';
                        _verificationMessage  = '';
                      });
                      _loadPackages(provider: newProvider);
                    },
                  ),
                )).toList(),
              ),
            ),
          ),

          // ── Subscription details ────────────────────────────────────────
          ServiceSectionCard(
            title: 'Subscription Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Smartcard input
                TextField(
                  controller:  _smartcardCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText:  'Smartcard / IUC Number',
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),

                // Verify button
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _verifying ? null : _verifySmartcard,
                      icon: _verifying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_user_rounded, size: 18),
                      label: Text(
                        _verifying ? 'Verifying...' : 'Verify Smartcard',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ]),

                // Verification feedback
                if (_verificationChecked) ...[
                  const SizedBox(height: 8),
                  _VerificationBadge(ok: _verificationOk, message: _verificationOk && _verifiedCustomerName.isNotEmpty ? 'Customer: $_verifiedCustomerName' : _verificationMessage),
                ],

                const SizedBox(height: 16),

                // ── Package dropdown ──────────────────────────────────────
                _buildPackageSelector(),

                // ── Auto-amount display ───────────────────────────────────
                if (_selectedPackage != null && _selectedAmount > 0) ...[
                  const SizedBox(height: 12),
                  _AmountDisplay(amount: _selectedAmount),
                ],

                const SizedBox(height: 16),

                // Phone input
                ElitePhoneInput(
                  controller: _phoneCtrl,
                  network:    'mtn',
                  onChanged:  (v) => _invalidateRequestId(),
                  onContactTap: _pickContact,
                ),
              ],
            ),
          ),

          // ── Saved beneficiaries ─────────────────────────────────────────
          if (_beneficiaries.isNotEmpty)
            ServiceSectionCard(
              title: 'Recent Subscriptions',
              child: Column(
                children: _beneficiaries.take(5).map((b) => _BeneficiaryTile(
                  item: b,
                  onTap: () => _applyBeneficiary(b),
                )).toList(),
              ),
            ),

          // ── Save-beneficiary toggle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Switch(
                  value:    _saveBeneficiary,
                  onChanged: (v) {
                    setState(() => _saveBeneficiary = v);
                    _savePreference(v);
                  },
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Save for future subscriptions', style: TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
          ),

          // ── Error banner ────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Package selector widget ───────────────────────────────────────────────

  Widget _buildPackageSelector() {
    if (_packagesLoading) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          border:       Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Loading packages...', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        )),
      );
    }

    if (_packagesError != null) {
      return GestureDetector(
        onTap: () => _loadPackages(),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            border:       Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(20),
            color:        Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
          ),
          child: Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(_packagesError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
            ],
          )),
        ),
      );
    }

    if (_packages.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          border:       Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('No packages available', style: TextStyle(fontWeight: FontWeight.w500))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border:       Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15), width: 1.5),
        borderRadius: BorderRadius.circular(20),
        color:        isDark ? const Color(0xFF1C2333) : const Color(0xFFF8F9FC),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value:      _selectedPackage,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 24),
          ),
          selectedItemBuilder: (context) => _packages.map((pkg) {
            final name   = (pkg['name'] ?? '').toString();
            final amount = (pkg['amount'] != null)
                ? '₦${(pkg['amount'] as num).toStringAsFixed(0)}'
                : '';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                children: [
                  const Icon(Icons.tv_rounded, size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                      if (amount.isNotEmpty)
                        Text(amount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    ],
                  )),
                ],
              ),
            );
          }).toList(),
          items: _packages.map((pkg) {
            final name   = (pkg['name'] ?? '').toString();
            final code   = (pkg['code'] ?? '').toString();
            final amount = (pkg['amount'] != null)
                ? '₦${(pkg['amount'] as num).toStringAsFixed(0)}'
                : 'Price N/A';
            return DropdownMenuItem<Map<String, dynamic>>(
              value: pkg,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(code, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Text(amount, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (pkg) {
            if (pkg == null) return;
            HapticFeedback.selectionClick();
            setState(() {
              _selectedPackage = pkg;
              _invalidateRequestId();
            });
          },
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.ok, required this.message});
  final bool   ok;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = ok ? (isDark ? const Color(0xFF123322) : const Color(0xFFEAF9EF)) : (isDark ? const Color(0xFF3A1818) : const Color(0xFFFDECEC));
    final border  = ok ? (isDark ? const Color(0xFF34D399) : const Color(0xFF22C55E)) : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));
    final txtColor = ok ? (isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534)) : (isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: bg, border: Border.all(color: border)),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, size: 18, color: txtColor),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txtColor))),
      ]),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2540), const Color(0xFF0F1A33)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
        ),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.payments_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text('Subscription Amount', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))),
        Text(
          '₦${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Theme.of(context).colorScheme.primary),
        ),
      ]),
    );
  }
}

class _BeneficiaryTile extends StatelessWidget {
  const _BeneficiaryTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback          onTap;

  @override
  Widget build(BuildContext context) {
    final provider  = (item['provider'] ?? '').toString().toUpperCase();
    final smartcard = (item['smartcard_number'] ?? '').toString();
    final pkgName   = (item['package_name'] ?? item['package_code'] ?? '').toString();
    final phone     = (item['phone_number'] ?? '').toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        ),
        child: Center(child: Icon(Icons.tv_rounded, size: 20, color: Theme.of(context).colorScheme.primary)),
      ),
      title:    Text('$provider • $smartcard', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text('$pkgName • $phone',      style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
      onTap:    onTap,
    );
  }
}

// ── Auth bottom sheet ─────────────────────────────────────────────────────────

class _DualAuthSheet extends StatelessWidget {
  const _DualAuthSheet({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onPin,
    required this.onBiometric,
  });

  final String       title;
  final String       subtitle;
  final String       amount;
  final VoidCallback onPin;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(amount,   style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onPin,      icon: const Icon(Icons.lock_outline_rounded),  label: const Text('Use PIN'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(  onPressed: onBiometric, icon: const Icon(Icons.fingerprint_rounded), label: const Text('Use Biometric'))),
          ]),
        ],
      ),
    );
  }
}
