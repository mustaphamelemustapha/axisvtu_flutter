import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../widgets/glass_card.dart';
import '../widgets/elite_phone_input.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart' as native_contact;
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  static const _recentNumbersKey = 'axis_airtime_recent_numbers_v1';
  static const _beneficiariesEnabledKey = 'axis_airtime_beneficiaries_v1';
  static const _smartSuggestionEnabledKey = 'axis_airtime_suggestions_v1';
  static const Map<String, List<String>> _networkPrefixes = {
    'mtn': [
      '07025',
      '07026',
      '0803',
      '0806',
      '0703',
      '0706',
      '0810',
      '0813',
      '0814',
      '0816',
      '0903',
      '0906',
      '0913',
      '0916',
      '0704',
    ],
    'airtel': [
      '0802',
      '0808',
      '0708',
      '0812',
      '0701',
      '0902',
      '0907',
      '0901',
      '0912',
    ],
    'glo': ['0805', '0807', '0705', '0815', '0811', '0905', '0915'],
    '9mobile': ['0809', '0817', '0818', '0908', '0909'],
  };

  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '200');

  String _network = 'mtn';
  bool _loading = false;
  String? _activeRequestId;
  bool _beneficiariesEnabled = true;
  bool _smartSuggestionEnabled = true;
  String? _error;
  List<String> _networks = const ['mtn', 'glo', 'airtel', '9mobile'];
  List<String> _recentNumbers = [];
  List<String> _suggestions = [];

  bool _isUncertainPurchaseError(String message) {
    final text = message.toLowerCase();
    return text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('unable to reach server') ||
        text.contains('failed to fetch') ||
        text.contains('network error') ||
        text.contains('connection');
  }

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
    _amountCtrl.addListener(_invalidateRequestId);
    _loadCatalog();
    _loadPreferences();
    _loadRecentNumbers();
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
    _amountCtrl.removeListener(_invalidateRequestId);
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['airtime_networks'];
      if (raw is List && raw.isNotEmpty) {
        final items = raw
            .map(_normalizeNetworkName)
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (!mounted || items.isEmpty) return;
        setState(() {
          _invalidateRequestId();
          _networks = items;
          if (!_networks.contains(_network)) {
            _network = _networks.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final numbers = prefs.getStringList(_recentNumbersKey) ?? <String>[];
    if (!mounted) return;
    setState(() => _recentNumbers = numbers);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final beneficiariesEnabled =
        prefs.getBool(_beneficiariesEnabledKey) ?? _beneficiariesEnabled;
    final smartSuggestionEnabled =
        prefs.getBool(_smartSuggestionEnabledKey) ?? _smartSuggestionEnabled;
    if (!mounted) return;
    setState(() {
      _beneficiariesEnabled = beneficiariesEnabled;
      _smartSuggestionEnabled = smartSuggestionEnabled;
    });
    _onPhoneChanged();
  }

  Future<void> _saveTogglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveRecentNumber(String number) async {
    final normalized = _normalizePhone(number);
    if (normalized.length < 10) return;
    final next = [normalized, ..._recentNumbers.where((n) => n != normalized)];
    final trimmed = next.take(8).toList();
    setState(() => _recentNumbers = trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentNumbersKey, trimmed);
  }

  void _onPhoneChanged() {
    _activeRequestId = null;
    final rawDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final normalized = _normalizePhone(rawDigits);

    final detected = _detectNetwork(normalized);
    if (detected != null &&
        detected != _network &&
        _networks.contains(detected)) {
      setState(() => _network = detected);
    }

    if (!_smartSuggestionEnabled || normalized.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    final nextSuggestions = _recentNumbers
        .where((n) => n.startsWith(normalized) && n != normalized)
        .take(3)
        .toList();

    if (nextSuggestions.join('|') != _suggestions.join('|')) {
      setState(() => _suggestions = nextSuggestions);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _networkLogo(String network) {
    final asset = switch (network.toLowerCase()) {
      'mtn' => 'assets/networks/mtn.svg',
      'airtel' => 'assets/networks/airtel.svg',
      'glo' => 'assets/networks/glo.svg',
      '9mobile' => 'assets/networks/9mobile.svg',
      _ => '',
    };

    if (asset.isEmpty) return const Icon(Icons.cell_tower_rounded, size: 14);

    return SvgPicture.asset(
      asset,
      width: 14,
      height: 14,
      fit: BoxFit.contain,
    );
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
        _onPhoneChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
    }
  }

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  String _normalizeNetworkName(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'etisalat') return '9mobile';
    if (raw == 'mtn' || raw == 'glo' || raw == 'airtel' || raw == '9mobile') {
      return raw;
    }
    return raw;
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234') && digits.length >= 13) {
      return '0${digits.substring(3)}';
    }
    if (!digits.startsWith('0') && digits.length == 10) {
      return '0$digits';
    }
    return digits;
  }

  String? _detectNetwork(String normalizedPhone) {
    if (normalizedPhone.length < 4) return null;
    final prefixes = <MapEntry<String, String>>[];
    _networkPrefixes.forEach((network, items) {
      for (final prefix in items) {
        prefixes.add(MapEntry(prefix, network));
      }
    });
    prefixes.sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in prefixes) {
      if (normalizedPhone.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _submit({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final phone = _normalizePhone(_phoneCtrl.text);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (phone.length < 10 || phone.length > 15) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    final detectedNetwork = _detectNetwork(phone);
    if (detectedNetwork != null && detectedNetwork != _network) {
      setState(() {
        _error =
            'Detected ${detectedNetwork.toUpperCase()} number. Please use ${detectedNetwork.toUpperCase()} network.';
        _network = detectedNetwork;
      });
      return;
    }
    if (amount < 50) {
      setState(() => _error = 'Minimum airtime amount is ₦50.');
      return;
    }

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'airtime purchase',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("airtime");
      final res = await ServicesService(token: token).purchaseAirtime(
        network: _network,
        phoneNumber: phone,
        amount: amount,
        clientRequestId: _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      await _saveRecentNumber(phone);
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
        reference: (res['reference'] ?? '').toString(),
        fields: [
          ReceiptField(label: 'Network', value: _network.toUpperCase()),
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
      if (_isUncertainPurchaseError(message)) {
        _showResult(
          status: 'pending',
          subtitle:
              'Order submitted. Provider confirmation is delayed. Check History shortly.',
          reference:
              'AXIS-AIRTIME-PENDING-${DateTime.now().millisecondsSinceEpoch}',
          fields: [
            ReceiptField(label: 'Network', value: _network.toUpperCase()),
            ReceiptField(label: 'Phone', value: phone),
            ReceiptField(
              label: 'Amount',
              value: '₦${amount.toStringAsFixed(2)}',
            ),
          ],
        );
      } else {
        _showResult(
          status: 'failed',
          subtitle: message,
          reference:
              'AXIS-AIRTIME-ATTEMPT-${DateTime.now().millisecondsSinceEpoch}',
          fields: [
            ReceiptField(label: 'Network', value: _network.toUpperCase()),
            ReceiptField(label: 'Phone', value: phone),
            ReceiptField(
              label: 'Amount',
              value: '₦${amount.toStringAsFixed(2)}',
            ),
            ReceiptField(label: 'Failure', value: message),
          ],
        );
        _activeRequestId = null;
      }
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _navigateToAmount() {
    final phone = _normalizePhone(_phoneCtrl.text);
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AirtimeAmountScreen(
          network: _network,
          phone: phone,
        ),
      ),
    );
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    final ok = status == 'success';
    final userName =
        context.read<SessionController>().user?['full_name'] ?? 'User';
    final phone = _normalizePhone(_phoneCtrl.text);
    final amount = _amountCtrl.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuccessModal(
        ok: ok,
        time: _formatDate(DateTime.now()),
        sender: userName,
        provider: 'AxisVTU',
        type: 'Airtime',
        network: _network.toUpperCase(),
        phone: phone,
        amount: '₦$amount',
        onSave: () => _shareReceipt(ok, userName, phone, amount),
      ),
    );
  }

  void _shareReceipt(bool ok, String sender, String phone, String amount) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ShareableReceipt(
          ok: ok,
          sender: sender,
          phone: phone,
          type: 'Airtime',
          network: _network.toUpperCase(),
          amount: '₦$amount',
          time: _formatDate(DateTime.now()),
        ),
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

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final message = (payload['message'] ?? payload['detail'] ?? '')
        .toString()
        .trim();
    if (message.isNotEmpty) return message;
    if (status == 'success') return 'Airtime order completed successfully.';
    if (status == 'pending') {
      return 'Airtime request received and currently processing.';
    }
    return 'Airtime order failed.';
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)} ${_monthName(value.month)} ${value.year} at ${two(value.hour)}:${two(value.minute)}';
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  void _applySuggestedNumber(String phone) {
    HapticFeedback.mediumImpact();
    _phoneCtrl.value = TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = _normalizePhone(_phoneCtrl.text).isNotEmpty;

    return ServiceShell(
      title: 'Airtime',
      subtitle: 'Smart network detect, quick suggestions, and instant top-up.',
      icon: Icons.phone_iphone_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Network',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _networks.map((network) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ServiceChoiceChip(
                      label: network.toUpperCase(),
                      selected: _network == network,
                      leading: _NetworkIcon(network: network, size: 20),
                      onTap: () {
                        _invalidateRequestId();
                        setState(() => _network = network);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Recipient',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElitePhoneInput(
                  controller: _phoneCtrl,
                  network: _network,
                  onContactTap: _pickContact,
                  onChanged: (v) => _onPhoneChanged(),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PremiumSmallButton(
                      label: 'Next: Choose Amount',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _navigateToAmount,
                    ),
                  ),
                ],
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Smart Suggestions',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions.map((number) {
                            final detected = _detectNetwork(number) ?? _network;
                            return GestureDetector(
                              onTap: () => _applySuggestedNumber(number),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _networkLogo(detected),
                                    const SizedBox(width: 6),
                                    Text(
                                      number,
                                      style: Theme.of(context).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _PremiumSectionCard(
                title: 'Validation Error',
                subtitle: 'Please check your inputs.',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AirtimeAmountScreen extends StatefulWidget {
  final String network;
  final String phone;

  const AirtimeAmountScreen({
    super.key,
    required this.network,
    required this.phone,
  });

  @override
  State<AirtimeAmountScreen> createState() => _AirtimeAmountScreenState();
}

class _AirtimeAmountScreenState extends State<AirtimeAmountScreen> {
  final _amountCtrl = TextEditingController(text: '200');
  bool _loading = false;
  String? _activeRequestId;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  bool _isUncertainPurchaseError(String message) {
    final text = message.toLowerCase();
    return text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('unable to reach server') ||
        text.contains('failed to fetch') ||
        text.contains('network error') ||
        text.contains('connection');
  }

  Future<void> _saveRecentNumber(String number) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    String normalized = digits;
    if (digits.startsWith('234') && digits.length >= 13) {
      normalized = '0${digits.substring(3)}';
    } else if (!digits.startsWith('0') && digits.length == 10) {
      normalized = '0$digits';
    }
    
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('axis_airtime_recent_numbers_v1') ?? [];
    final next = [normalized, ...recent.where((n) => n != normalized)];
    await prefs.setStringList('axis_airtime_recent_numbers_v1', next.take(8).toList());
  }

  Future<void> _submit({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 50) {
      setState(() => _error = 'Minimum airtime amount is ₦50.');
      return;
    }

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'airtime purchase',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("airtime");
      final res = await ServicesService(token: token).purchaseAirtime(
        network: widget.network,
        phoneNumber: widget.phone,
        amount: amount,
        clientRequestId: _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      await _saveRecentNumber(widget.phone);
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
        fields: [
          ReceiptField(label: 'Network', value: widget.network.toUpperCase()),
          ReceiptField(label: 'Phone', value: widget.phone),
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
      if (_isUncertainPurchaseError(message)) {
        _showResult(
          status: 'pending',
          subtitle: 'Order submitted. Provider confirmation is delayed.',
          fields: [
            ReceiptField(label: 'Network', value: widget.network.toUpperCase()),
            ReceiptField(label: 'Phone', value: widget.phone),
            ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
          ],
        );
      } else {
        setState(() => _error = message);
        _activeRequestId = null;
      }
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSummaryModal() {
    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PurchaseSummaryModal(
        phone: widget.phone,
        network: widget.network,
        title: 'Airtime Recharge',
        amount: '₦${amount.toStringAsFixed(2)}',
        onProceedPin: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodPin);
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodBiometric);
        },
      ),
    );
  }

  void _showResult({
    required String status,
    required String subtitle,
    required List<ReceiptField> fields,
  }) {
    final ok = status == 'success';
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';
    final amount = _amountCtrl.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuccessModal(
        ok: ok,
        time: _formatDate(DateTime.now()),
        sender: userName,
        provider: 'AxisVTU',
        type: 'Airtime',
        network: widget.network.toUpperCase(),
        phone: widget.phone,
        amount: '₦$amount',
        onSave: () => _shareReceipt(ok, userName, widget.phone, amount),
      ),
    );
  }

  void _shareReceipt(bool ok, String sender, String phone, String amount) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ShareableReceipt(
          ok: ok,
          sender: sender,
          phone: phone,
          type: 'Airtime',
          network: widget.network.toUpperCase(),
          amount: '₦$amount',
          time: _formatDate(DateTime.now()),
        ),
      ),
    );
  }

  String _resolveResultStatus(Map<String, dynamic> payload) {
    final statusRaw = (payload['status'] ?? '').toString().trim().toLowerCase();
    final ok = payload['success'] == true || statusRaw == 'success' || statusRaw == 'successful' || statusRaw == 'delivered';
    if (ok) return 'success';
    if (statusRaw == 'pending' || statusRaw == 'processing') return 'pending';
    return 'failed';
  }

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final message = (payload['message'] ?? payload['detail'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;
    if (status == 'success') return 'Airtime order completed successfully.';
    return 'Airtime order failed.';
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)} ${_monthName(value.month)} ${value.year} at ${two(value.hour)}:${two(value.minute)}';
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Amount',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _NetworkIcon(network: widget.network, size: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.phone,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.network.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _AirtimeAmountPicker(
              amountCtrl: _amountCtrl,
              onProceed: _showSummaryModal,
              loading: _loading,
              network: widget.network,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumSmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _AirtimeAmountPicker extends StatefulWidget {
  final TextEditingController amountCtrl;
  final VoidCallback onProceed;
  final bool loading;
  final String network;

  const _AirtimeAmountPicker({
    required this.amountCtrl,
    required this.onProceed,
    required this.loading,
    required this.network,
  });

  @override
  State<_AirtimeAmountPicker> createState() => _AirtimeAmountPickerState();
}

class _AirtimeAmountPickerState extends State<_AirtimeAmountPicker> {
  @override
  void initState() {
    super.initState();
    widget.amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    widget.amountCtrl.removeListener(_onAmountChanged);
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  void _addAmount(int value) {
    HapticFeedback.mediumImpact();
    final current = double.tryParse(widget.amountCtrl.text) ?? 0;
    widget.amountCtrl.text = (current + value).toStringAsFixed(0);
  }

  void _setAmount(int value) {
    HapticFeedback.selectionClick();
    widget.amountCtrl.text = value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_rounded, size: 14, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      'Airtime',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '₦',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.amountCtrl.text.isEmpty ? '0' : widget.amountCtrl.text,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Enter amount or tap a preset below',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [200, 500, 1000, 2000].map((v) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PresetButton(
                  label: '+$v',
                  onTap: () => _addAmount(v),
                  isAdd: true,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            50, 100, 200, 300, 500, 1000, 2000, 3000, 5000, 10000, 15000, 20000
          ].map((v) {
            final label = v >= 1000 ? '₦${(v/1000).toStringAsFixed(0)}K' : '₦$v';
            return _PresetButton(
              label: label,
              onTap: () => _setAmount(v),
              isAdd: false,
            );
          }).toList(),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: widget.loading ? null : widget.onProceed,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 8,
              shadowColor: primary.withValues(alpha: 0.4),
            ),
            child: widget.loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Proceed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAdd;

  const _PresetButton({
    required this.label,
    required this.onTap,
    required this.isAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAdd 
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAdd ? primary.withValues(alpha: 0.2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isAdd ? primary : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }
}

class _NetworkIcon extends StatelessWidget {
  final String network;
  final double size;
  const _NetworkIcon({required this.network, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = switch (network.toLowerCase()) {
      'mtn' => 'assets/networks/mtn.svg',
      'airtel' => 'assets/networks/airtel.svg',
      'glo' => 'assets/networks/glo.svg',
      '9mobile' => 'assets/networks/9mobile.svg',
      _ => '',
    };

    if (asset.isEmpty) {
      return Icon(Icons.cell_tower_rounded, size: size * 0.7);
    }

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => Icon(Icons.cell_tower_rounded, size: size * 0.7),
        ),
      ),
    );
  }
}

class _PremiumSectionCard extends StatelessWidget {
  const _PremiumSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PurchaseSummaryModal extends StatelessWidget {
  final String phone;
  final String network;
  final String title;
  final String amount;
  final VoidCallback onProceedPin;
  final VoidCallback onProceedBiometric;

  const _PurchaseSummaryModal({
    required this.phone,
    required this.network,
    required this.title,
    required this.amount,
    required this.onProceedPin,
    required this.onProceedBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt_rounded, color: primary, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Recharge',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your airtime top-up details',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL RECHARGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _PremiumSummaryItem(
              label: 'Network',
              value: network.toUpperCase(),
              icon: Icons.cell_tower_rounded,
              isDark: isDark,
            ),
            _PremiumSummaryItem(
              label: 'Recipient',
              value: phone,
              icon: Icons.phone_android_rounded,
              isDark: isDark,
            ),
            _PremiumSummaryItem(
              label: 'Transaction',
              value: title,
              icon: Icons.local_activity_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 40),
            _PremiumPaymentButton(
              label: 'Pay with Biometrics',
              sublabel: 'Fast & Secure Authentication',
              icon: Icons.fingerprint_rounded,
              isPrimary: true,
              onTap: onProceedBiometric,
            ),
            const SizedBox(height: 16),
            _PremiumPaymentButton(
              label: 'Authorize with Secret PIN',
              sublabel: 'Standard Transaction Security',
              icon: Icons.dialpad_rounded,
              isPrimary: false,
              onTap: onProceedPin,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _PremiumSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPaymentButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PremiumPaymentButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isPrimary ? primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: isPrimary 
            ? null 
            : Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 2),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.white.withValues(alpha: 0.2) : primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isPrimary ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: isPrimary ? Colors.white.withValues(alpha: 0.7) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isPrimary ? Colors.white.withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessModal extends StatefulWidget {
  final bool ok;
  final String time;
  final String sender;
  final String provider;
  final String type;
  final String network;
  final String phone;
  final String amount;
  final VoidCallback onSave;

  const _SuccessModal({
    required this.ok,
    required this.time,
    required this.sender,
    required this.provider,
    required this.type,
    required this.network,
    required this.phone,
    required this.amount,
    required this.onSave,
  });

  @override
  State<_SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<_SuccessModal> {
  bool _bolt = true;
  bool _saveBene = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            child: Icon(
              widget.ok ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.ok ? 'Purchase Successful' : 'Purchase Failed',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Transfer Receipt',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (widget.ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.ok ? 'Successful' : 'Failed',
                        style: TextStyle(
                          color: widget.ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                _ReceiptRow(label: 'Time', value: widget.time),
                _ReceiptRow(label: 'Sender Name', value: widget.sender),
                _ReceiptRow(label: 'Provider', value: widget.provider),
                _ReceiptRow(label: 'Type', value: widget.type),
                _ReceiptRow(label: 'Network', value: widget.network),
                _ReceiptRow(label: 'Receiver Phone', value: widget.phone),
                _ReceiptRow(label: 'Amount', value: widget.amount),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SuccessToggle(
            icon: Icons.person_add_outlined,
            label: 'Beneficiaries',
            value: _saveBene,
            onChanged: (v) => setState(() => _saveBene = v),
          ),
          const SizedBox(height: 12),
          _SuccessToggle(
            icon: Icons.bolt_outlined,
            label: 'Axis Bolt',
            value: _bolt,
            onChanged: (v) => setState(() => _bolt = v),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Save Receipt',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.ok ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SuccessToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SuccessToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ShareableReceipt extends StatelessWidget {
  final bool ok;
  final String sender;
  final String phone;
  final String type;
  final String network;
  final String amount;
  final String time;

  const _ShareableReceipt({
    required this.ok,
    required this.sender,
    required this.phone,
    required this.type,
    required this.network,
    required this.amount,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ok ? [const Color(0xFF2463EB), const Color(0xFF3B82F6)] : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/brand/axisvtu-logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Icon(
                        ok ? Icons.local_florist : Icons.error_outline_rounded,
                        color: ok ? const Color(0xFF2463EB) : const Color(0xFF64748B),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AxisVTU',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Transaction Receipt',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.cancel,
                        color: ok ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ok ? 'Successful' : 'Failed',
                        style: TextStyle(
                          color: ok ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ReceiptTableItem(label: 'Time', value: time),
              _ReceiptTableItem(label: 'Sender Name', value: sender, bold: true),
              _ReceiptTableItem(label: 'Provider', value: 'AxisVTU', bold: true),
              _ReceiptTableItem(label: 'Type', value: type, bold: true),
              _ReceiptTableItem(label: 'Network', value: network, bold: true),
              _ReceiptTableItem(label: 'Receiver Phone', value: phone, bold: true),
              _ReceiptTableItem(label: 'Amount', value: amount, bold: true),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text(
                'axisvtu.com',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(double.infinity, 20),
          painter: _ZigZagPainter(),
        ),
      ],
    );
  }
}

class _ReceiptTableItem extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _ReceiptTableItem({
    required this.label,
    required this.value,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.withValues(alpha: 0.1)),
        ],
      ),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    double x = 0;
    const dashWidth = 10.0;
    const dashHeight = 10.0;
    while (x < size.width) {
      path.lineTo(x + dashWidth / 2, dashHeight);
      path.lineTo(x + dashWidth, 0);
      x += dashWidth;
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
