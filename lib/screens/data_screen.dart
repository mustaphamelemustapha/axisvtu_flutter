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
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';
import '../widgets/sticky_checkout_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  // Removed manual ordering to allow price-based sorting for all bundles
  static const Map<String, int> _airtelBundleOrder = {};

  static const double _planTileExtent = 174;

  final _phoneCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final bool _ported = false;
  final GlobalKey _planStepKey = GlobalKey();

  String _network = 'mtn';
  String? _selectedPlanCode;
  List<dynamic> _plans = [];

  bool _loadingPlans = true;
  bool _autoAdvancedToPlans = false;
  bool _refreshing = false;
  bool _submitting = false;
  String? _activeRequestId;
  bool _beneficiariesEnabled = true;
  bool _smartSuggestionEnabled = true;
  bool _fastRouteEnabled = false;
  List<String> _recentNumbers = [];
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (_plansLoadFuture != null) {
      if (forceRefresh) {
        return _plansLoadFuture!.then(
          (_) => _loadPlans(forceRefresh: true, silent: silent),
        );
      }
      return _plansLoadFuture!;
    }

    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;
    if (forceRefresh) {
      DataService.clearCache();
    }

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
          _error = null;
          final plans = _sortedNetworkPlans;
          final current = _selectedPlanCode;
          _selectedPlanCode =
              plans.any((plan) => plan['plan_code']?.toString() == current)
              ? current
              : null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = _friendlyPlanLoadError(e));
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
    _activeRequestId = null;
    final normalized = _normalizePhone(_phoneCtrl.text);

    final detected = _detectNetwork(normalized);
    if (detected != null && detected != _network) {
      setState(() {
        _network = detected;
        _error = null;
        // Validate if existing selection is still valid for new network
        final plans = _plans.where((p) => p['network']?.toString().toLowerCase() == detected).toList();
        final current = _selectedPlanCode;
        if (current != null && !plans.any((p) => p['plan_code']?.toString() == current)) {
          _selectedPlanCode = null;
        }
        _refreshing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadPlans(silent: true);
      });
    }

    if (normalized.length >= 10 && !_autoAdvancedToPlans) {
      _autoAdvancedToPlans = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _planStepKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: AxisDurations.normal,
            curve: Curves.easeOutCubic,
            alignment: 0.12,
          );
        }
      });
    }

    if (normalized.length < 10) {
      _autoAdvancedToPlans = false;
    }
  }

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  String _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) {
      digits = '0${digits.substring(3)}';
    }
    if (digits.length == 10 && !digits.startsWith('0')) {
      digits = '0$digits';
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

  List<dynamic> get _networkPlans {
    return _plans.where((plan) {
      final net = (plan['network'] ?? '').toString().toLowerCase();
      return net == _network;
    }).toList();
  }

  List<dynamic> get _sortedNetworkPlans {
    final plans = List<dynamic>.from(_networkPlans);
    plans.sort((a, b) {
      if (_network == 'airtel') {
        final aOrder =
            _airtelBundleOrder[_planCapacity(a).toUpperCase()] ?? 999;
        final bOrder =
            _airtelBundleOrder[_planCapacity(b).toUpperCase()] ?? 999;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      }
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
    for (final plan in _sortedNetworkPlans) {
      if (plan['plan_code']?.toString() == code) {
        return plan;
      }
    }
    return null;
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

  String _formatMoney(dynamic value) {
    return _formatMoneyValue(value);
  }

  double? _toDouble(dynamic value) {
    return _toDoubleValue(value);
  }

  String _planCapacity(dynamic plan) {
    return _planCapacityValue(plan);
  }

  String _planPrice(dynamic plan) {
    return _planPriceValueFormatted(plan);
  }

  double _planPriceValue(dynamic plan) {
    final val = plan['price'] ?? plan['amount'] ?? 0;
    return _toDoubleValue(val) ?? 0;
  }

  String _planValidity(dynamic plan) {
    final validity = (plan['validity'] ?? '').toString().trim();
    return validity.isEmpty ? '—' : validity;
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

  String _friendlyPlanLoadError(Object error) {
    final raw = error is ApiException ? error.message : error.toString();
    final text = raw.toLowerCase();
    if (text.contains('network') ||
        text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('connection') ||
        text.contains('server')) {
      return 'Plans are taking longer than usual. Please try again shortly.';
    }
    return 'Plans are temporarily unavailable. Please try again.';
  }

  Future<void> _openPlansSheet({bool requirePhone = true}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    if (requirePhone && normalizedPhone.isEmpty) {
      setState(() => _error = 'Enter a phone number first.');
      return;
    }

    if (_plans.isEmpty) {
      _loadPlans();
    }

    String? selectedCode = _selectedPlanCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentPlans = _sortedNetworkPlans;
            final isLoading = _loadingPlans && currentPlans.isEmpty;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECT PLAN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _network.toUpperCase(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: isLoading
                        ? const _PlanShimmerGrid()
                        : currentPlans.isEmpty
                            ? _EmptyPlansState(onRetry: () => _loadPlans(forceRefresh: true))
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.95,
                                ),
                                itemCount: currentPlans.length,
                                itemBuilder: (context, index) {
                                  final plan = currentPlans[index];
                                  final code = plan['plan_code']?.toString();
                                  final isSelected = selectedCode == code;

                                  return _ElitePlanTile(
                                    plan: plan,
                                    selected: isSelected,
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      setSheetState(() => selectedCode = code);
                                    },
                                  );
                                },
                              ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL PRICE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              Text(
                                (() {
                                  if (selectedCode == null) return '₦0.00';
                                  try {
                                    // Robust plan lookup to prevent "Red Flash" crash
                                    final plan = currentPlans.firstWhere(
                                      (p) => p['plan_code']?.toString() == selectedCode,
                                      orElse: () => null,
                                    );
                                    if (plan == null) return '₦0.00';
                                    return '₦${_planPrice(plan)}';
                                  } catch (_) {
                                    return '₦0.00';
                                  }
                                })(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _GradientActionButton(
                            label: 'Confirm Selection',
                            icon: Icons.check_circle_rounded,
                            onTap: selectedCode == null
                                ? () {}
                                : () {
                                    Navigator.pop(context);
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      if (!mounted) return;
                                      setState(() => _selectedPlanCode = selectedCode);
                                      _showSummaryModal();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSummaryModal() {
    final plan = _selectedPlan;
    if (plan == null) return;

    final phone = _normalizePhone(_phoneCtrl.text);
    final price = _planPrice(plan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PurchaseSummaryModal(
        phone: phone,
        network: _network,
        planName: _planCapacity(plan),
        planValidity: _planValidity(plan),
        price: price,
        onProceedPin: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            _buy(authMethod: PurchaseAuthService.methodPin);
          });
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            _buy(authMethod: PurchaseAuthService.methodBiometric);
          });
        },
      ),
    );
  }

  Future<void> _buy({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    if (_selectedPlanCode == null || normalizedPhone.isEmpty) {
      setState(() => _error = 'Enter phone number and select a plan.');
      return;
    }

    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'data purchase',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _error = null;
      _submitting = true;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= "DATA_${DateTime.now().microsecondsSinceEpoch}";
      final response = await DataService(token: token).purchase(
        planCode: _selectedPlanCode!,
        phoneNumber: normalizedPhone,
        ported: _ported,
        clientRequestId: _activeRequestId,
      );
      if (!mounted) return;
      await _saveRecentNumber(normalizedPhone);
      PurchaseLoadingOverlay.hide();
      final finalStatus = (response['status'] ?? '').toString().toLowerCase();
      _showResult(response);
      if (finalStatus != 'pending') {
        _activeRequestId = null;
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      final uncertain = _isUncertainPurchaseError(message);
      setState(() => _error = uncertain ? null : message);
      PurchaseLoadingOverlay.hide();
      _showResult({
        'status': uncertain ? 'pending' : 'failed',
        'message': uncertain
            ? 'Order submitted. Provider confirmation is delayed. Check History shortly.'
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
        statusRaw == 'successful' ||
        statusRaw == 'completed' ||
        statusRaw == 'order_completed';
    final pending =
        statusRaw == 'pending' ||
        statusRaw == 'processing' ||
        statusRaw == 'queued' ||
        statusRaw == 'order_received' ||
        statusRaw == 'order_onhold';
    final status = ok ? 'success' : (pending ? 'pending' : 'failed');

    final selected = _selectedPlan;
    final userName =
        context.read<SessionController>().user?['full_name'] ?? 'User';
    final phone = _normalizePhone(_phoneCtrl.text);
    final message = (res['message'] ?? res['detail'] ?? '').toString().trim();
    final reference = (res['reference'] ?? _activeRequestId ?? '—')
        .toString()
        .trim();
    final subtitle = message.isNotEmpty
        ? message
        : status == 'success'
        ? 'Data order completed successfully.'
        : status == 'pending'
        ? 'Order submitted and currently processing.'
        : 'Data order failed.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: status == 'success'
            ? 'Data Order Successful'
            : (status == 'pending'
                  ? 'Data Order Pending'
                  : 'Data Order Failed'),
        subtitle: subtitle,
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ReceiptField(label: 'Sender Name', value: userName),
          ReceiptField(label: 'Network', value: _network.toUpperCase()),
          ReceiptField(label: 'Recipient', value: phone),
          ReceiptField(
            label: 'Plan',
            value: selected == null
                ? '—'
                : '${_planCapacity(selected)} • ${_planValidity(selected)}',
          ),
          ReceiptField(
            label: 'Amount',
            value: selected == null ? '₦0.00' : '₦${_planPrice(selected)}',
          ),
          ReceiptField(label: 'Reference', value: reference),
        ],
      ),
    );
  }

  void _selectNetwork(String value) {
    if (_network == value) return;
    HapticFeedback.selectionClick();
    setState(() {
      _invalidateRequestId();
      _network = value;
      // Clear selection if it doesn't belong to the new network
      final plans = _plans.where((p) => p['network']?.toString().toLowerCase() == value).toList();
      final current = _selectedPlanCode;
      if (current != null && !plans.any((p) => p['plan_code']?.toString() == current)) {
        _selectedPlanCode = null;
      }
      _error = null;
      _plans = [];
      _loadingPlans = true;
      _refreshing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPlans(silent: true);
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final selected = _selectedPlan;
    final hasPhone = _normalizePhone(_phoneCtrl.text).isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ServiceShell(
      title: 'Buy Data',
      subtitle: 'Experience the fastest data top-up in the industry.',
      icon: Icons.wifi_rounded,
      scrollController: _scrollController,
      footer: StickyCheckoutBar(
        title: _network.toUpperCase(),
        subtitle: hasPhone ? _normalizePhone(_phoneCtrl.text) : 'Enter number',
        amount: selected != null ? '₦${_planPrice(selected)}' : '₦0.00',
        active: hasPhone,
        loading: _submitting,
        onBuy: _selectedPlanCode == null
            ? () => _openPlansSheet()
            : _showSummaryModal,
        actionLabel: _selectedPlanCode == null ? 'Select Plan' : 'Buy Data Now',
        icon: _selectedPlanCode == null
            ? Icons.layers_outlined
            : Icons.bolt_rounded,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1: Select Network (Elite Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. CHOOSE NETWORK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NetworkCard(
                        name: 'mtn',
                        isSelected: _network == 'mtn',
                        onTap: () => _selectNetwork('mtn'),
                        isDark: isDark,
                      ),
                      _NetworkCard(
                        name: 'airtel',
                        isSelected: _network == 'airtel',
                        onTap: () => _selectNetwork('airtel'),
                        isDark: isDark,
                      ),
                      _NetworkCard(
                        name: 'glo',
                        isSelected: _network == 'glo',
                        onTap: () => _selectNetwork('glo'),
                        isDark: isDark,
                      ),
                      _NetworkCard(
                        name: '9mobile',
                        isSelected: _network == '9mobile',
                        onTap: () => _selectNetwork('9mobile'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // Step 2: Recipient Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. RECIPIENT DETAILS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Phone Number',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.phone_iphone_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          suffixIcon: hasPhone ? IconButton(
                            onPressed: () => _phoneCtrl.clear(),
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                          ) : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                      const Divider(height: 1),
                      InkWell(
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (sheetContext) => _RecentRecipientsSheet(
                            recentNumbers: _recentNumbers,
                            currentNetwork: _network,
                            onApply: _applySuggestedNumber,
                            onClose: () => Navigator.pop(sheetContext),
                          ),
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Select from recent numbers',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // Step 3: Select Plan (Elite Reveal)
          if (hasPhone) Padding(
            key: _planStepKey,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. SELECT DATA PLAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    if (_selectedPlanCode != null) TextButton(
                      onPressed: _openPlansSheet,
                      child: const Text('Change Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selected == null) _EliteSelectionCard(
                  onTap: _openPlansSheet,
                  label: 'Tap to view available plans',
                  icon: Icons.grid_view_rounded,
                ) else Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _planCapacity(selected),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              _planValidity(selected),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₦${_planPrice(selected)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}


class _EliteSelectionCard extends StatelessWidget {
  const _EliteSelectionCard({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  final VoidCallback onTap;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}







class _RecentRecipientsSheet extends StatelessWidget {
  const _RecentRecipientsSheet({
    required this.recentNumbers,
    required this.currentNetwork,
    required this.onApply,
    required this.onClose,
  });

  final List<String> recentNumbers;
  final String currentNetwork;
  final ValueChanged<String> onApply;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1624) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contacts_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent recipients',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Tap any number to fill it quickly.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
            const SizedBox(height: 12),
            if (recentNumbers.isEmpty)
              _EmptyStateCard(
                title: 'Nothing saved yet',
                subtitle: 'Your successful purchases will appear here.',
                icon: Icons.people_outline_rounded,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recentNumbers.map((number) {
                  return GestureDetector(
                    onTap: () => onApply(number),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        number,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionHeroCard extends StatelessWidget {
  const _TransactionHeroCard({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.trailingLabel,
    required this.trailingIcon,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final String trailingLabel;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0E1726),
                  Color(0xFF12233A),
                  Color(0xFF0A1220),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFFF1F6FF),
                  Color(0xFFE8F1FF),
                  Color(0xFFF7FAFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -14,
            right: -8,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.wifi_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.60),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trailingIcon,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trailingLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HeroButton(
                      label: primaryLabel,
                      icon: Icons.grid_view_rounded,
                      onTap: onPrimary,
                      primary: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroButton(
                      label: secondaryLabel,
                      icon: Icons.refresh_rounded,
                      onTap: onSecondary,
                      primary: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    return SizedBox(
      height: 48,
      child: primary
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  letterSpacing: 0.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: disabled
                  ? const SizedBox(width: 0, height: 0)
                  : Icon(icon, size: 18),
              label: Text(label),
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
      padding: EdgeInsets.all(AxisSpacing.md),
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

class _ReceiptPreviewLine extends StatelessWidget {
  const _ReceiptPreviewLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: onSurface,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkMetaPill extends StatelessWidget {
  const _NetworkMetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ? 'On' : 'Off',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.suggestions,
    required this.networkResolver,
    required this.onApply,
  });

  final List<String> suggestions;
  final String Function(String phone) networkResolver;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Double tap a suggestion to fill it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((number) {
              final detected = networkResolver(number);
              return GestureDetector(
                onDoubleTap: () => onApply(number),
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
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        number,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        detected.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecentRecipientsInline extends StatelessWidget {
  const _RecentRecipientsInline({
    required this.recentNumbers,
    required this.currentNetwork,
    required this.onApply,
  });

  final List<String> recentNumbers;
  final String currentNetwork;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recentNumbers.take(6).map((number) {
        return GestureDetector(
          onDoubleTap: () => onApply(number),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Text(number, style: Theme.of(context).textTheme.labelMedium),
          ),
        );
      }).toList(),
    );
  }
}

class _PurchaseSummaryModal extends StatelessWidget {
  final String phone;
  final String network;
  final String planName;
  final String planValidity;
  final String price;
  final VoidCallback onProceedPin;
  final VoidCallback onProceedBiometric;

  const _PurchaseSummaryModal({
    required this.phone,
    required this.network,
    required this.planName,
    required this.planValidity,
    required this.price,
    required this.onProceedPin,
    required this.onProceedBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Confirm Order',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                _EliteSummaryRow(label: 'Recipient', value: phone, isDark: isDark),
                const Divider(height: 24),
                _EliteSummaryRow(label: 'Network', value: network.toUpperCase(), isDark: isDark),
                const Divider(height: 24),
                _EliteSummaryRow(label: 'Data Plan', value: planName, isDark: isDark),
                const Divider(height: 24),
                _EliteSummaryRow(label: 'Validity', value: planValidity, isDark: isDark),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount to Pay',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    Text(
                      '₦$price',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _GradientActionButton(
                  label: 'Pay with Biometric',
                  icon: Icons.fingerprint_rounded,
                  onTap: onProceedBiometric,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onProceedPin,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: const Text(
                    'Pay with PIN',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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

class _EliteSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _EliteSummaryRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _MasterpieceActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _MasterpieceActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ElitePhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final String network;
  final bool isDark;
  final VoidCallback onContactTap;

  const _ElitePhoneInput({
    required this.controller,
    required this.network,
    required this.isDark,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _NetworkIcon(network: network, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Enter Phone Number',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: onContactTap,
            icon: Icon(
              Icons.contact_page_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NetworkCard({
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NetworkIcon(network: name, size: 32),
            const SizedBox(height: 8),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
    String asset = 'assets/networks/mtn.svg';
    final n = network.toLowerCase();
    if (n.contains('airtel')) asset = 'assets/networks/airtel.svg';
    else if (n.contains('glo')) asset = 'assets/networks/glo.svg';
    else if (n.contains('9mobile')) asset = 'assets/networks/9mobile.svg';

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      errorBuilder: (c, e, s) => Icon(Icons.signal_cellular_alt_rounded, size: size),
    );
  }
}

class _ElitePlanTile extends StatelessWidget {
  final dynamic plan;
  final bool selected;
  final VoidCallback onTap;

  const _ElitePlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final network = (plan['network'] ?? '').toString().toLowerCase();
    final capacity = _planDisplayTitle(plan, network);
    final price = _planPriceValueFormatted(plan);
    final validity = plan['validity']?.toString() ?? '30d';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NetworkIcon(network: network, size: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? primary : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    validity,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              capacity,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₦$price',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanShimmerGrid extends StatelessWidget {
  const _PlanShimmerGrid();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A2438) : const Color(0xFFF2F4F8);
    final highlight = isDark
        ? const Color(0xFF283656)
        : const Color(0xFFE7EBF3);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        opacity: 0.88,
        child: Container(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 20,
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 34,
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 22,
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanMetaPill extends StatelessWidget {
  const _PlanMetaPill({
    required this.label,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.compact,
  });

  final String label;
  final bool selected;
  final Color primary;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: selected
            ? primary.withValues(alpha: 0.16)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF4F6FA)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? primary.withValues(alpha: 0.5)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFDDE4F0)),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: selected
              ? primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.78)
                    : const Color(0xFF64748B)),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// File-level utility functions for DataScreen
String _planCapacityValue(dynamic plan) {
  final raw =
      plan['data_capacity'] ??
      plan['size'] ??
      plan['capacity'] ??
      plan['name'] ??
      plan['plan_name'] ??
      '';
  return _formatCapacityValue(raw);
}

String _planDisplayTitle(dynamic plan, String network) {
  final raw =
      plan['name'] ??
      plan['plan_name'] ??
      plan['data_capacity'] ??
      plan['size'] ??
      plan['capacity'] ??
      '';
  var value = _formatCapacityValue(raw);
  if (value.isEmpty) return 'Data Plan';

  final prefixes = ['MTN', 'AIRTEL', 'GLO', '9MOBILE', 'SMILE', 'T2'];
  for (final p in prefixes) {
    if (value.toUpperCase().startsWith(p)) {
      value = value.substring(p.length).trim();
      break;
    }
  }

  value = value.replaceAllMapped(
    RegExp(r'([A-Z]+)(\d)'),
    (m) => '${m[1]} ${m[2]}',
  );
  value = value.replaceAllMapped(
    RegExp(r'(\d)([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (value.isEmpty) {
    final net = network.isEmpty
        ? 'Plan'
        : '${network[0].toUpperCase()}${network.substring(1)}';
    return '$net Plan';
  }
  return value;
}

String _planPriceValueFormatted(dynamic plan) {
  return _formatMoneyValue(plan['price'] ?? plan['amount'] ?? 0);
}

String _formatCapacityValue(dynamic raw) {
  if (raw == null) return '';
  if (raw is Map || raw is List) return 'Plan';
  final value = raw.toString().trim();
  if (value.isEmpty) return '';

  final upper = value.toUpperCase();
  if (upper.contains('GB') || upper.contains('MB')) {
    return upper.replaceAll(' ', '');
  }

  final parsed = _toDoubleValue(value);
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

String _formatMoneyValue(dynamic value) {
  final number = _toDoubleValue(value);
  if (number == null) return value.toString();

  // Format with commas for thousands
  String base;
  if (number % 1 == 0) {
    base = number.toInt().toString();
  } else {
    base = number.toStringAsFixed(2);
  }

  final parts = base.split('.');
  final main = parts[0];
  final decimal = parts.length > 1 ? '.${parts[1]}' : '';

  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final formattedMain = main.replaceAllMapped(reg, (Match m) => '${m[1]},');

  return '$formattedMain$decimal';
}

double? _toDoubleValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class _EmptyPlansState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyPlansState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No plans available right now',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try refreshing the catalog in a moment.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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
  final String capacity;
  final String validity;
  final String network;
  final String phone;
  final VoidCallback onSave;

  const _SuccessModal({
    required this.ok,
    required this.time,
    required this.sender,
    required this.provider,
    required this.capacity,
    required this.validity,
    required this.network,
    required this.phone,
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
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
                _ReceiptRow(
                  label: 'Data Capacity',
                  value: widget.capacity,
                  extra: widget.validity.isNotEmpty
                      ? Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.ok
                                ? Colors.green[100]
                                : Colors.red[100]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.validity,
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.ok
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : null,
                ),
                _ReceiptRow(label: 'Network', value: widget.network),
                _ReceiptRow(label: 'Receiver Phone', value: widget.phone),
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
  final Widget? extra;
  const _ReceiptRow({required this.label, required this.value, this.extra});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (extra != null) extra!,
            ],
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
  final String planName;
  final String planValidity;
  final String network;
  final String time;

  const _ShareableReceipt({
    required this.ok,
    required this.sender,
    required this.phone,
    required this.planName,
    required this.planValidity,
    required this.network,
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
              _ReceiptTableItem(
                label: 'Data Capacity',
                value: planName,
                bold: true,
                extra: planValidity.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ok ? Colors.green[100] : Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          planValidity,
                          style: TextStyle(
                            fontSize: 10,
                            color: ok ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : null,
              ),
              _ReceiptTableItem(label: 'Network', value: network, bold: true),
              _ReceiptTableItem(
                label: 'Receiver Phone',
                value: phone,
                bold: true,
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text(
                'www.axisvtu.com',
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
  final Widget? extra;
  const _ReceiptTableItem({
    required this.label,
    required this.value,
    this.bold = false,
    this.extra,
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
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (extra != null) extra!,
            ],
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

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.70);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
