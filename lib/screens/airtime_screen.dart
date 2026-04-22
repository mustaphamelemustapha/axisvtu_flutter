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
import '../widgets/primary_button.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';

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

  Future<void> _submit() async {
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
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Buying airtime');

    try {
      _activeRequestId ??= buildRequestId("airtime");
      final res = await ServicesService(
        token: token,
      ).purchaseAirtime(
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
              'Purchase submitted. Provider confirmation is delayed. Check History shortly.',
          reference:
              'AXIS-AIRTIME-PENDING-${DateTime.now().millisecondsSinceEpoch}',
          fields: [
            ReceiptField(label: 'Network', value: _network.toUpperCase()),
            ReceiptField(label: 'Phone', value: phone),
            ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
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
            ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
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
          success: 'Airtime Successful',
          pending: 'Airtime Pending',
          failed: 'Airtime Failed',
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
    if (status == 'success') return 'Airtime purchase completed successfully.';
    if (status == 'pending') {
      return 'Airtime request received and currently processing.';
    }
    return 'Airtime purchase failed.';
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
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return ServiceShell(
      title: 'Airtime',
      subtitle: 'Smart network detect, quick suggestions, and instant top-up.',
      icon: Icons.phone_iphone_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Network',
            subtitle:
                'Detected automatically while typing. You can still change it.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _networks.map((network) {
                return ServiceChoiceChip(
                  label: network.toUpperCase(),
                  selected: _network == network,
                  leading: _networkLogo(network),
                  onTap: () {
                    _invalidateRequestId();
                    setState(() => _network = network);
                  },
                );
              }).toList(),
            ),
          ),
          ServiceSectionCard(
            title: 'Recipient Details',
            subtitle: 'Enter beneficiary number and amount.',
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final detected = _detectNetwork(
                      _normalizePhone(_phoneCtrl.text),
                    );
                    if (detected == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Detected network: ${detected.toUpperCase()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '08123456789',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggestions',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Double tap to fill suggested number',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions.map((number) {
                            final detected = _detectNetwork(number) ?? _network;
                            return GestureDetector(
                              onDoubleTap: () => _applySuggestedNumber(number),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.25),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₦)',
                    hintText: '200',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 200, 500, 1000, 2000]
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
            subtitle: 'Confirm details before purchase.',
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
                    '${_network.toUpperCase()} • ₦${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _normalizePhone(_phoneCtrl.text).isEmpty
                        ? 'Enter phone number to continue'
                        : 'Recipient: ${_normalizePhone(_phoneCtrl.text)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Beneficiaries',
            subtitle: 'Same quick style as Buy Data page.',
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Contacts',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    _TabChip(label: 'Recent', selected: true),
                    SizedBox(width: 10),
                    _TabChip(label: 'Saved', selected: false),
                  ],
                ),
                const SizedBox(height: 14),
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
            ServiceSectionCard(
              title: 'Validation',
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          PrimaryButton(
            label: 'Buy Airtime',
            icon: Icons.send_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _networkLogo(String network) {
    final normalized = _normalizeNetworkName(network);
    final asset = switch (normalized) {
      'mtn' => 'assets/networks/mtn.svg',
      'airtel' => 'assets/networks/airtel.svg',
      'glo' => 'assets/networks/glo.svg',
      '9mobile' => 'assets/networks/9mobile.svg',
      _ => '',
    };
    if (asset.isEmpty) {
      return const Icon(Icons.network_cell, size: 16);
    }
    return SvgPicture.asset(
      asset,
      height: 16,
      width: 16,
      placeholderBuilder: (_) => const Icon(Icons.network_cell, size: 16),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
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
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
