import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../services/purchase_auth_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  static const _recentNumbersKey = 'axis_airtime_recent_numbers_v1';
  static const _beneficiariesEnabledKey = 'axis_data_beneficiaries_v1';
  static const _smartSuggestionEnabledKey = 'axis_data_suggestions_v1';
  static const _fastRouteEnabledKey = 'axis_data_fast_route_v1';
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
  final bool _ported = false;

  String _network = 'mtn';
  String? _selectedPlanCode;
  List<dynamic> _plans = [];

  bool _loadingPlans = true;
  bool _refreshing = false;
  bool _submitting = false;
  bool _beneficiariesEnabled = true;
  bool _smartSuggestionEnabled = true;
  bool _fastRouteEnabled = false;
  List<String> _recentNumbers = [];
  List<String> _suggestions = [];
  String? _error;
  Future<void>? _plansLoadFuture;

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
    if (DataService.hasCache) {
      _plans = DataService.cachedPlans;
      _loadingPlans = false;
    }
    _loadPreferences();
    _loadRecentNumbers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans(silent: DataService.hasCache);
    });
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (_plansLoadFuture != null) {
      return _plansLoadFuture!;
    }

    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;

    final future = () async {
      if (mounted) {
        if (silent) {
          if (_error != null) {
            setState(() => _error = null);
          }
        } else {
          setState(() {
            _loadingPlans = true;
            _refreshing = forceRefresh;
            _error = null;
          });
        }
      }

      try {
        final data = await DataService(
          token: token,
        ).getPlans(forceRefresh: forceRefresh);

        if (!mounted) return;
        setState(() {
          _plans = data;
          final plans = _sortedFilteredPlans;
          final current = _selectedPlanCode;
          _selectedPlanCode = plans.isEmpty
              ? null
              : (plans.any((p) => p['plan_code']?.toString() == current)
                    ? current
                    : plans.first['plan_code']?.toString());
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e is ApiException ? e.message : e.toString());
      } finally {
        if (mounted && (_loadingPlans || _refreshing)) {
          setState(() {
            _loadingPlans = false;
            _refreshing = false;
          });
        }
      }
    }();

    _plansLoadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_plansLoadFuture, future)) {
        _plansLoadFuture = null;
      }
    }
  }

  Future<void> _loadRecentNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final numbers = prefs.getStringList(_recentNumbersKey) ?? <String>[];
    if (!mounted) return;
    setState(() => _recentNumbers = numbers);
    _onPhoneChanged();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final beneficiariesEnabled =
        prefs.getBool(_beneficiariesEnabledKey) ?? _beneficiariesEnabled;
    final smartSuggestionEnabled =
        prefs.getBool(_smartSuggestionEnabledKey) ?? _smartSuggestionEnabled;
    final fastRouteEnabled =
        prefs.getBool(_fastRouteEnabledKey) ?? _fastRouteEnabled;
    if (!mounted) return;
    setState(() {
      _beneficiariesEnabled = beneficiariesEnabled;
      _smartSuggestionEnabled = smartSuggestionEnabled;
      _fastRouteEnabled = fastRouteEnabled;
    });
    _onPhoneChanged();
  }

  Future<void> _saveTogglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveRecentNumber(String number) async {
    if (!_beneficiariesEnabled) return;
    final normalized = _normalizePhone(number);
    if (normalized.length < 10) return;
    final next = [normalized, ..._recentNumbers.where((n) => n != normalized)];
    final trimmed = next.take(8).toList();
    setState(() => _recentNumbers = trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentNumbersKey, trimmed);
    _onPhoneChanged();
  }

  void _onPhoneChanged() {
    final normalized = _normalizePhone(_phoneCtrl.text);

    final detected = _detectNetwork(normalized);
    if (detected != null && detected != _network) {
      setState(() {
        _network = detected;
        final plans = _sortedFilteredPlans;
        _selectedPlanCode = plans.isNotEmpty
            ? plans.first['plan_code']?.toString()
            : null;
      });
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

  List<dynamic> get _filteredPlans {
    return _plans.where((plan) {
      final net = (plan['network'] ?? '').toString().toLowerCase();
      return net == _network;
    }).toList();
  }

  List<dynamic> get _sortedFilteredPlans {
    final plans = List<dynamic>.from(_filteredPlans);
    plans.sort((a, b) {
      final aPrice = _planPriceValue(a);
      final bPrice = _planPriceValue(b);
      if (aPrice != bPrice) return aPrice.compareTo(bPrice);
      return _capacityToGb(
        _planCapacity(a),
      ).compareTo(_capacityToGb(_planCapacity(b)));
    });
    return plans;
  }

  dynamic get _selectedPlan {
    final code = _selectedPlanCode;
    if (code == null) return null;
    return _sortedFilteredPlans.firstWhere(
      (p) => p['plan_code']?.toString() == code,
      orElse: () => null,
    );
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

  String _planCapacity(dynamic plan) {
    final raw =
        plan['data_capacity'] ??
        plan['size'] ??
        plan['capacity'] ??
        plan['name'] ??
        plan['plan_name'] ??
        '';
    return _formatCapacity(raw);
  }

  String _planPrice(dynamic plan) {
    return _formatMoney(plan['price'] ?? plan['amount'] ?? 0);
  }

  String _planValidity(dynamic plan) {
    final validity = (plan['validity'] ?? '').toString().trim();
    final days = _extractDays(validity);
    if (days != null) return '$days day${days == 1 ? '' : 's'}';
    return validity.isEmpty ? 'Flexible' : validity;
  }

  String _planNetwork(dynamic plan) {
    return (plan['network'] ?? '').toString().toUpperCase();
  }

  String _formatCapacity(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map || raw is List) return 'Plan';
    final value = raw.toString().trim();
    if (value.isEmpty) return '';

    final upper = value.toUpperCase();
    if (upper.contains('GB') || upper.contains('MB')) {
      return upper.replaceAll(' ', '');
    }

    final parsed = _toDouble(value);
    if (parsed == null) return value;

    if (parsed < 1) {
      final mb = (parsed * 1000).round();
      return '${mb}MB';
    }

    final gb = parsed % 1 == 0
        ? parsed.toInt().toString()
        : parsed.toStringAsFixed(1);
    return '${gb}GB';
  }

  double _planPriceValue(dynamic plan) {
    final value = _toDouble(plan['price'] ?? plan['amount'] ?? 0);
    return value ?? double.infinity;
  }

  String _formatMoney(dynamic value) {
    final number = _toDouble(value);
    if (number == null) return value.toString();
    if (number % 1 == 0) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int? _extractDays(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  double _capacityToGb(String capacity) {
    final upper = capacity.toUpperCase();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(upper);
    if (match == null) return 0;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return 0;
    if (upper.contains('MB')) return number / 1000;
    if (upper.contains('GB')) return number;
    return 0;
  }

  Future<void> _openPlansSheet({bool requirePhone = true}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    if (requirePhone && normalizedPhone.isEmpty) {
      setState(() => _error = 'Enter a phone number first.');
      return;
    }

    if (_plans.isEmpty) {
      await _loadPlans();
    }
    if (!mounted) return;

    final plans = _sortedFilteredPlans;
    if (plans.isEmpty) {
      setState(() {
        _error = 'No plans available for ${_network.toUpperCase()} right now.';
      });
      return;
    }

    String? selectedCode =
        _selectedPlanCode ?? plans.first['plan_code']?.toString();
    final bestValueCode = plans.first['plan_code']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.84,
              minChildSize: 0.62,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Container(
                    color: isDark ? const Color(0xFF0F1725) : Colors.white,
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                    child: Column(
                      children: [
                        Container(
                          height: 5,
                          width: 56,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Available Plans',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_network.toUpperCase()} • choose your best fit',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: GridView.builder(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            itemCount: plans.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              final code = plan['plan_code']?.toString();
                              final selected = selectedCode == code;
                              final bestValue = code == bestValueCode;
                              return _PlanSheetTile(
                                capacity: _planCapacity(plan),
                                price: _planPrice(plan),
                                validity: _planValidity(plan),
                                selected: selected,
                                bestValue: bestValue,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedCode = code);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: selectedCode == null
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        setState(
                                          () =>
                                              _selectedPlanCode = selectedCode,
                                        );
                                        Navigator.of(context).pop();
                                        if (_normalizePhone(
                                          _phoneCtrl.text,
                                        ).isNotEmpty) {
                                          Future.microtask(
                                            _openPurchaseSummary,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openPurchaseSummary() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    final selected = _selectedPlan;
    if (selected == null || normalizedPhone.isEmpty) {
      setState(() => _error = 'Enter phone number and select a plan.');
      return;
    }

    double totalAmount = _planPriceValue(selected);
    if (!totalAmount.isFinite) {
      totalAmount = _toDouble(_planPrice(selected)) ?? 0;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool usingPin = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF091225),
                    Color(0xFF0A1630),
                    Color(0xFF0B1D3E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Purchase Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SummaryLine(label: 'Phone', value: normalizedPhone),
                    const SizedBox(height: 10),
                    _SummaryLine(
                      label: 'Network',
                      value: _planNetwork(selected),
                    ),
                    const SizedBox(height: 10),
                    _SummaryLine(
                      label: 'Plan',
                      value:
                          '${_planCapacity(selected)} • ${_planValidity(selected)}',
                    ),
                    const SizedBox(height: 10),
                    _SummaryLine(
                      label: 'Plan Price',
                      value: '₦${_planPrice(selected)}',
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.12),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    _SummaryToggleLine(label: 'Amigo Earn', amount: '₦0.00'),
                    const SizedBox(height: 10),
                    _SummaryToggleLine(label: 'Cashback', amount: '₦0.00'),
                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.12),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    const _SummaryLine(
                      label: 'Referral Applied',
                      value: '₦0.00',
                    ),
                    const SizedBox(height: 8),
                    const _SummaryLine(
                      label: 'Cashback Applied',
                      value: '₦0.00',
                    ),
                    const SizedBox(height: 10),
                    _SummaryLine(
                      label: 'Total to Pay',
                      value: '₦${totalAmount.toStringAsFixed(2)}',
                      highlight: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: usingPin
                                ? null
                                : () async {
                                    setSheetState(() => usingPin = true);
                                    final authorized =
                                        await PurchaseAuthService.authorizePin(
                                          context: context,
                                          reason: 'data purchase',
                                        );
                                    if (!mounted) return;
                                    setSheetState(() => usingPin = false);
                                    if (!authorized) return;
                                    Navigator.of(this.context).pop();
                                    await _buy();
                                  },
                            icon: usingPin
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline_rounded),
                            label: const Text('Use Pin'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: usingPin
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Biometric verification coming soon. Use PIN for now.',
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Biometric'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4C8DFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _buy() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    if (_selectedPlanCode == null || normalizedPhone.isEmpty) {
      setState(() => _error = 'Enter phone number and select a plan.');
      return;
    }

    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _error = null;
      _submitting = true;
    });
    PurchaseLoadingOverlay.show(context, title: 'Buying data');

    try {
      final response = await DataService(token: token).purchase(
        planCode: _selectedPlanCode!,
        phoneNumber: normalizedPhone,
        ported: _ported,
      );
      if (!mounted) return;
      await _saveRecentNumber(normalizedPhone);
      PurchaseLoadingOverlay.hide();
      _showResult(response);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      final uncertain = _isUncertainPurchaseError(message);
      setState(() => _error = uncertain ? null : message);
      PurchaseLoadingOverlay.hide();
      _showResult({
        'status': uncertain ? 'pending' : 'failed',
        'message': uncertain
            ? 'Purchase submitted. Provider confirmation is delayed. Check History shortly.'
            : message,
        'provider': 'AxisVTU',
      });
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showResult(Map<String, dynamic> res) {
    final statusRaw = (res['status'] ?? '').toString().toLowerCase();
    final ok =
        res['success'] == true ||
        statusRaw == 'delivered' ||
        statusRaw == 'success' ||
        statusRaw == 'successful';
    final pending =
        !ok &&
        (statusRaw == 'pending' ||
            statusRaw == 'processing' ||
            statusRaw == 'queued');
    final status = ok ? 'success' : (pending ? 'pending' : 'failed');

    final selected = _selectedPlan;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: ok
            ? 'Purchase Successful'
            : (pending ? 'Purchase Pending' : 'Purchase Failed'),
        subtitle:
            res['message']?.toString() ??
            (ok ? 'Data purchase completed.' : 'Purchase was not completed.'),
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ReceiptField(
            label: 'Sender Name',
            value:
                (context.read<SessionController>().user?['full_name'] ??
                        'AxisVTU User')
                    .toString(),
          ),
          ReceiptField(
            label: 'Provider',
            value: (res['provider'] ?? 'AxisVTU').toString(),
          ),
          ReceiptField(
            label: 'Data Capacity',
            value: selected == null ? '—' : _planCapacity(selected),
          ),
          ReceiptField(
            label: 'Network',
            value: selected == null
                ? _network.toUpperCase()
                : _planNetwork(selected),
          ),
          ReceiptField(
            label: 'Receiver Phone',
            value: _normalizePhone(_phoneCtrl.text),
          ),
          if (selected != null)
            ReceiptField(label: 'Amount', value: '₦${_planPrice(selected)}'),
          if ((res['reference'] ?? '').toString().isNotEmpty)
            ReceiptField(
              label: 'Reference',
              value: (res['reference'] ?? '').toString(),
            ),
        ],
      ),
    );
  }

  void _selectNetwork(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      _network = value;
      final plans = _sortedFilteredPlans;
      _selectedPlanCode = plans.isNotEmpty
          ? plans.first['plan_code']?.toString()
          : null;
    });
  }

  void _applySuggestedNumber(String phone) {
    HapticFeedback.mediumImpact();
    _phoneCtrl.value = TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
  }

  Widget _networkLogoByName(String network) {
    final asset = switch (network.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPlan;

    return ServiceShell(
      title: 'Buy Data',
      subtitle: 'Fast checkout, premium plan sheet, and instant receipt.',
      icon: Icons.wifi_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Send To',
            subtitle: 'Enter number, pick network, then continue.',
            child: Column(
              children: [
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '080...',
                    prefixIcon: Icon(Icons.phone_outlined),
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
                                    _networkLogoByName(detected),
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _NetworkChip(
                      label: 'MTN',
                      assetPath: 'assets/networks/mtn.svg',
                      selected: _network == 'mtn',
                      onTap: () => _selectNetwork('mtn'),
                    ),
                    _NetworkChip(
                      label: 'Airtel',
                      assetPath: 'assets/networks/airtel.svg',
                      selected: _network == 'airtel',
                      onTap: () => _selectNetwork('airtel'),
                    ),
                    _NetworkChip(
                      label: 'Glo',
                      assetPath: 'assets/networks/glo.svg',
                      selected: _network == 'glo',
                      onTap: () => _selectNetwork('glo'),
                    ),
                    _NetworkChip(
                      label: '9mobile',
                      assetPath: 'assets/networks/9mobile.svg',
                      selected: _network == '9mobile',
                      onTap: () => _selectNetwork('9mobile'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _refreshing
                            ? null
                            : () => _loadPlans(forceRefresh: true),
                        icon: Icon(
                          _refreshing ? Icons.sync : Icons.refresh_rounded,
                        ),
                        label: Text(
                          _refreshing ? 'Refreshing...' : 'Refresh Plans',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GradientActionButton(
                        label: 'Next',
                        icon: Icons.arrow_forward_rounded,
                        onTap: _openPlansSheet,
                      ),
                    ),
                  ],
                ),
                if (_loadingPlans && _plans.isEmpty) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Plan Checkout',
            subtitle: 'Review selected plan, then buy.',
            child: Column(
              children: [
                if (selected == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      'No plan selected yet. Tap "Next" to open available plans.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  _SelectedPlanCard(
                    network: _planNetwork(selected),
                    capacity: _planCapacity(selected),
                    price: _planPrice(selected),
                    validity: _planValidity(selected),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openPlansSheet(requirePhone: false),
                        icon: const Icon(Icons.grid_view_rounded),
                        label: const Text('Change Plan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Buy Data',
                        icon: Icons.send_rounded,
                        loading: _submitting,
                        onPressed: _selectedPlanCode == null
                            ? null
                            : _openPurchaseSummary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Beneficiaries',
            subtitle: 'Keep quick buy smooth and organized.',
            child: Column(
              children: [
                TextField(
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
                if (_recentNumbers.isNotEmpty)
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
                      children: _recentNumbers.take(6).map((number) {
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
                              ).colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _networkLogoByName(detected),
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
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Center(
                      child: Text(
                        'No recent transfers yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _ToggleTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Beneficiaries',
                  subtitle: 'Auto-save recipients for quick buy',
                  value: _beneficiariesEnabled,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _beneficiariesEnabled = v);
                    _saveTogglePreference(_beneficiariesEnabledKey, v);
                  },
                ),
                const SizedBox(height: 10),
                _ToggleTile(
                  icon: Icons.bolt_rounded,
                  label: 'Smart Suggestions',
                  subtitle: 'Show matching recent numbers while typing',
                  value: _smartSuggestionEnabled,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _smartSuggestionEnabled = v);
                    _saveTogglePreference(_smartSuggestionEnabledKey, v);
                    _onPhoneChanged();
                  },
                ),
                const SizedBox(height: 12),
                _ToggleTile(
                  icon: Icons.rocket_launch_rounded,
                  label: 'Fast Route',
                  subtitle: 'Fast route preference',
                  value: _fastRouteEnabled,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _fastRouteEnabled = v);
                    _saveTogglePreference(_fastRouteEnabledKey, v);
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            ServiceSectionCard(
              title: 'Notice',
              child: Text(
                _error!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: highlight ? 0.96 : 0.78),
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: highlight ? 18 : 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
              fontSize: highlight ? 24 : 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryToggleLine extends StatefulWidget {
  const _SummaryToggleLine({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  State<_SummaryToggleLine> createState() => _SummaryToggleLineState();
}

class _SummaryToggleLineState extends State<_SummaryToggleLine> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${widget.label}: ${widget.amount}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch.adaptive(
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          activeThumbColor: const Color(0xFF4C8DFF),
          activeTrackColor: const Color(0xFF7FB0FF),
        ),
      ],
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.assetPath,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    return ServiceChoiceChip(
      label: label,
      selected: selected,
      onTap: onTap,
      leading: assetPath == null
          ? const Icon(Icons.network_cell, size: 16)
          : SvgPicture.asset(
              assetPath!,
              height: 18,
              width: 18,
              placeholderBuilder: (_) =>
                  const Icon(Icons.network_cell, size: 16),
            ),
    );
  }
}

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({
    required this.network,
    required this.capacity,
    required this.price,
    required this.validity,
  });

  final String network;
  final String capacity;
  final String price;
  final String validity;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            const Color(0xFF0FB5AE).withValues(alpha: 0.11),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  network,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  validity,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  capacity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '₦$price',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _PlanSheetTile extends StatelessWidget {
  const _PlanSheetTile({
    required this.capacity,
    required this.price,
    required this.validity,
    required this.selected,
    required this.bestValue,
    required this.onTap,
  });

  final String capacity;
  final String price;
  final String validity;
  final bool selected;
  final bool bestValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? color
                    : Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.24),
                width: selected ? 1.7 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        capacity.isEmpty ? '—' : capacity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (bestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFF16A34A,
                            ).withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Text(
                          'Best',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₦$price',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(text: validity),
                    if (selected)
                      _Pill(
                        text: 'Selected',
                        background: color,
                        foreground: Colors.white,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.background, this.foreground});

  final String text;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).colorScheme.surface;
    final fg = foreground ?? Theme.of(context).textTheme.bodySmall?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
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

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: AxisPalette.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white),
          ],
        ),
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
