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

  void _showSummaryModal() {
    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    final phone = _normalizePhone(_phoneCtrl.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PurchaseSummaryModal(
        phone: phone,
        network: _network,
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

  void _applySuggestedNumber(String phone) {
    HapticFeedback.mediumImpact();
    _phoneCtrl.value = TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    final hasPhone = _normalizePhone(_phoneCtrl.text).isNotEmpty;

    return ServiceShell(
      title: 'Airtime',
      subtitle: 'Smart network detect, quick suggestions, and instant top-up.',
      icon: Icons.phone_iphone_rounded,
      footer: StickyCheckoutBar(
        title: _network.toUpperCase(),
        subtitle: hasPhone ? _normalizePhone(_phoneCtrl.text) : 'Enter number',
        amount: amount > 0 ? '₦${amount.toStringAsFixed(2)}' : '₦0.00',
        active: hasPhone && amount >= 50,
        loading: _loading,
        onBuy: _showSummaryModal,
        actionLabel: 'Confirm',
        icon: Icons.check_circle_outline_rounded,
      ),
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
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _networkLogo(detected),
                                    const SizedBox(width: 6),
                                    Text(
                                      number,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
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
                    hintText: 'Enter amount',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [100, 200, 500, 1000, 2000, 5000].map((v) {
                      final isSelected = _amountCtrl.text == v.toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('₦$v'),
                          selected: isSelected,
                          onSelected: (s) {
                            HapticFeedback.selectionClick();
                            setState(() => _amountCtrl.text = v.toString());
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Settings',
            subtitle: 'Personalize your airtime experience.',
            child: Column(
              children: [
                _ToggleTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Auto-save Beneficiaries',
                  subtitle: 'Keep frequently used numbers ready.',
                  value: _beneficiariesEnabled,
                  onChanged: (v) {
                    setState(() => _beneficiariesEnabled = v);
                    _saveTogglePreference(_beneficiariesEnabledKey, v);
                  },
                ),
                const SizedBox(height: 10),
                _ToggleTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Smart Suggestions',
                  subtitle: 'Use recent numbers while typing.',
                  value: _smartSuggestionEnabled,
                  onChanged: (v) {
                    setState(() => _smartSuggestionEnabled = v);
                    _saveTogglePreference(_smartSuggestionEnabledKey, v);
                    _onPhoneChanged();
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            _PremiumSectionCard(
              title: 'Validation Error',
              subtitle: 'Please check your inputs.',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.2),
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

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.14),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
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
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: muted),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SummaryRow(label: 'Phone', value: phone),
          _SummaryRow(label: 'Network', value: network.toUpperCase()),
          _SummaryRow(label: 'Service', value: title),
          _SummaryRow(label: 'Amount', value: amount),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total to Pay',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                amount,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProceedPin,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text(
                    'Use PIN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onProceedBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text(
                    'Use Biometric',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
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
              color: widget.ok
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (widget.ok
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.ok ? 'Successful' : 'Failed',
                        style: TextStyle(
                          color: widget.ok
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
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
                    backgroundColor: widget.ok
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
              colors: ok
                  ? [const Color(0xFF2463EB), const Color(0xFF3B82F6)]
                  : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/brand/axisvtu-logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Icon(
                        ok ? Icons.local_florist : Icons.error_outline_rounded,
                        color: ok
                            ? const Color(0xFF2463EB)
                            : const Color(0xFF64748B),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AxisVTU',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ok
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.cancel,
                        color: ok
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ok ? 'Successful' : 'Failed',
                        style: TextStyle(
                          color: ok
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
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
              _ReceiptTableItem(
                label: 'Sender Name',
                value: sender,
                bold: true,
              ),
              _ReceiptTableItem(
                label: 'Provider',
                value: 'AxisVTU',
                bold: true,
              ),
              _ReceiptTableItem(label: 'Type', value: type, bold: true),
              _ReceiptTableItem(label: 'Network', value: network, bold: true),
              _ReceiptTableItem(
                label: 'Receiver Phone',
                value: phone,
                bold: true,
              ),
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
