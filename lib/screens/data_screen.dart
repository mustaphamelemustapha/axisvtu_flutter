import 'dart:ui' as ui;
import '../utils/fast_route.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../services/purchase_auth_service.dart';
import '../services/biometric_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';
import '../widgets/sticky_checkout_bar.dart';
import '../widgets/insufficient_funds_sheet.dart';
import '../utils/balance_util.dart';
import '../widgets/elite_phone_input.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/mele_data_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart' as native_contact;
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import 'history_screen.dart';

Color _globalGetNetworkColor(String network, [BuildContext? context]) {
  switch (network.toLowerCase()) {
    case 'mtn': return const Color(0xFFFFCC00);
    case 'airtel': return const Color(0xFFFF0000);
    case 'glo': return const Color(0xFF009900);
    case '9mobile': return const Color(0xFF006600);
    default: return context != null ? Theme.of(context).colorScheme.primary : Colors.blue;
  }
}

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
  String? _phoneErrorMsg;
  String? _shakingPlanCode;
  String? _selectedCategory;
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
    _loadRecentNumbers();
    _loadPreferences();
    _loadPlans(silent: false);
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
    if (_phoneErrorMsg != null) {
      setState(() => _phoneErrorMsg = null);
    }
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
    
    // Ensure UI updates (e.g. StickyCheckoutBar activation) when input changes
    if (mounted) {
      setState(() {});
    }
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
    if (_network == null) return [];
    return _plans.where((plan) {
      if (plan == null || plan is! Map) return false;
      final net = (plan['network'] ?? '').toString().toLowerCase();
      return net == _network;
    }).toList();
  }

  String _extractCategory(dynamic plan) {
    print('DEBUG PLAN: ${plan['plan_name']} - DATA_TYPE: ${plan['data_type']}');
    if (plan['data_type'] != null && plan['data_type'].toString().trim().isNotEmpty) {
      return plan['data_type'].toString().trim().toUpperCase();
    }
    final name = (plan['name'] ?? plan['plan_name'] ?? plan['title'] ?? '').toString().toUpperCase();
    if (name.contains('SME2')) return 'SME2';
    if (name.contains('SME')) return 'SME';
    if (name.contains('CORPORATE') || name.contains('CG')) return 'CORPORATE GIFTING';
    if (name.contains('GIFTING')) return 'GIFTING';
    if (name.contains('AWOOF')) return 'AWOOF DATA';
    return 'GENERAL';
  }

  List<dynamic> get _sortedNetworkPlans {
    final plans = List<dynamic>.from(_networkPlans);
    plans.sort((a, b) {
      if (a == null || b == null || a is! Map || b is! Map) return 0;
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
    
    if (_selectedCategory == null) return [];
    return plans.where((p) => _extractCategory(p) == _selectedCategory).toList();
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
    if (requirePhone && normalizedPhone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number first.');
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
                        : _selectedCategory == null
                            ? const Center(
                                child: Text('Please select a data type category above to view plans.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                              )
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
                                    key: ValueKey(code),
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
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number first.');
      return;
    }

    final priceValue = _planPriceValue(plan);
    final balance = getUserBalance(context);
    
    if (balance < priceValue) {
      InsufficientFundsSheet.show(context, shortfall: priceValue - balance);
      return;
    }

    final price = _planPrice(plan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Data',
        subtitle: 'Review your data purchase details',
        amount: '₦$price',
        primaryColor: _getNetworkColor(_network),
        headerIcon: Icons.wifi,
        items: [
          SummaryItem(label: 'Network', value: _network.toUpperCase(), icon: Icons.cell_tower_rounded),
          SummaryItem(label: 'Phone Number', value: phone, icon: Icons.phone_android_rounded),
          SummaryItem(label: 'Data Plan', value: _planCapacity(plan), icon: Icons.data_usage_rounded),
          SummaryItem(label: 'Validity', value: _planValidity(plan), icon: Icons.schedule_rounded),
        ],
        onProceedPin: () {
          Navigator.pop(context);
          if (mounted) _buy(authMethod: PurchaseAuthService.methodPin);
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          if (mounted) _buy(authMethod: PurchaseAuthService.methodBiometric);
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
        'provider': 'MELE DATA',
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

    if (status != 'failed') {
      context.read<SessionController>().refreshBalance();
    }

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

    final isSuccess = status.toLowerCase() != 'failed';
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
                : '${selected['name'] ?? selected['plan_name'] ?? _planDisplayTitle(selected, _network)} (${_planValidity(selected)})',
          ),
          ReceiptField(label: 'Reference', value: reference),
        ],
      ),
    ).then((_) {
      if (isSuccess && mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _selectNetwork(String value) {
    if (_network == value) return;
    HapticFeedback.selectionClick();
    setState(() {
      _invalidateRequestId();
      _network = value;
      // Clear selection if it doesn't belong to the new network
      final plans = _plans.where((p) => p != null && (p as Map)['network']?.toString().toLowerCase() == value).toList();
      final current = _selectedPlanCode;
      if (current != null && !plans.any((p) => p != null && (p as Map)['plan_code']?.toString() == current)) {
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

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn': return const Color(0xFFFFCC00);
      case 'airtel': return const Color(0xFFFF0000);
      case 'glo': return const Color(0xFF009900);
      case '9mobile': return const Color(0xFF006600);
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  void _showNetworkSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.only(top: 24, bottom: 32, left: 24, right: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change mobile network',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...['Airtel', 'Glo', 'MTN', '9Mobile'].map((net) {
                final netCode = net.toLowerCase();
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _selectNetwork(netCode);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: _networkLogoByName(netCode),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            net == '9Mobile' ? 'T2(9Mobile)' : net,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPlan;
    final hasPhone = _normalizePhone(_phoneCtrl.text).length >= 10;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Buy Data',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                FastRoute(page: const HistoryScreen()),
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone Input Section
                  const Text(
                    'Enter phone number',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _network.isNotEmpty ? _getNetworkColor(_network).withValues(alpha: 0.3) : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: _network.isNotEmpty ? [
                        BoxShadow(
                          color: _getNetworkColor(_network).withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ] : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _showNetworkSelector,
                                child: Row(
                                  children: [
                                    if (_network.isNotEmpty) ...[
                                      Container(
                                        width: 32,
                                        height: 32,
                                        clipBehavior: Clip.hardEdge,
                                        decoration: const BoxDecoration(shape: BoxShape.circle),
                                        child: _networkLogoByName(_network),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                    ] else
                                      const Icon(Icons.cell_tower, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (v) => _onPhoneChanged(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.contact_phone, color: Theme.of(context).colorScheme.primary),
                          onPressed: _pickContact,
                        )
                      ],
                    ),
                  ),
                  if (_phoneErrorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16),
                      child: Text(
                        _phoneErrorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Animated Recent Avatars (Restored functional feature)
                  if (_recentNumbers.isNotEmpty) ...[
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentNumbers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final number = _recentNumbers[index];
                          return GestureDetector(
                            onTap: () => _applySuggestedNumber(number),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    number,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  if (_network.isEmpty && !hasPhone) ...[
                    const Text('Select a network', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['mtn', 'airtel', 'glo', '9mobile'].map((net) => GestureDetector(
                        onTap: () => _selectNetwork(net),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161E2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Text(net[0].toUpperCase(), style: TextStyle(color: _getNetworkColor(net), fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  
                  if (_network.isNotEmpty) ...[
                    const Text('Select Data Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    
                    // Custom Dropdown for Categories
                    GestureDetector(
                      onTap: () {
                        final cats = _networkPlans
                            .map((p) => _extractCategory(p))
                            .toSet()
                            .toList();
                        
                        if (cats.isEmpty) return;
                        
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (sheetContext) => Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('Select Data Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  ...cats.map((cat) => ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                    title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                    trailing: _selectedCategory == cat ? Icon(Icons.check_circle, color: _getNetworkColor(_network)) : null,
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      setState(() => _selectedCategory = cat);
                                    },
                                  )),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161E2E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _network.isNotEmpty ? _getNetworkColor(_network).withValues(alpha: 0.3) : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCategory ?? 'Select Data Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedCategory != null ? FontWeight.bold : FontWeight.normal,
                                color: _selectedCategory != null ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, color: _network.isNotEmpty ? _getNetworkColor(_network) : Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (_loadingPlans && _plans.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: MeleDataLoader(size: 80.0)),
                      )
                    else if (_error != null)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                    else if (_selectedCategory == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 32, bottom: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _getNetworkColor(_network).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.data_usage_rounded, size: 48, color: _getNetworkColor(_network)),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Select a Data Type',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Please select a data category from the dropdown above to view available plans.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_sortedNetworkPlans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32, bottom: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.inbox_rounded, size: 48, color: Colors.orange),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Plans Found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'There are currently no active plans for $_selectedCategory on $_network.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _sortedNetworkPlans.length,
                        itemBuilder: (context, index) {
                          final plan = _sortedNetworkPlans[index];
                          final code = plan['plan_code']?.toString();
                          final isSelected = _selectedPlanCode == code;
                          final netColor = _getNetworkColor(_network);
                          
                          return GestureDetector(
                            onTap: () {
                              if (!hasPhone) {
                                setState(() {
                                  _phoneErrorMsg = "Please enter a valid phone number";
                                  _shakingPlanCode = code;
                                });
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) setState(() => _shakingPlanCode = null);
                                });
                                return;
                              }
                              setState(() {
                                _selectedPlanCode = code;
                                _phoneErrorMsg = null;
                              });
                              _showSummaryModal();
                            },
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(_shakingPlanCode == code ? code : null),
                              tween: Tween(begin: _shakingPlanCode == code ? 1.0 : 0.0, end: 0.0),
                              duration: const Duration(milliseconds: 400),
                              builder: (context, value, child) {
                                final offset = value > 0 ? math.sin(value * math.pi * 4) * 8 : 0.0;
                                return Transform.translate(
                                  offset: Offset(offset, 0),
                                  child: child,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            isDark ? netColor.withValues(alpha: 0.15) : netColor.withValues(alpha: 0.08),
                                            isDark ? const Color(0xFF0F141E) : Colors.white,
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDark 
                                            ? [const Color(0xFF1E2638), const Color(0xFF0B101A)]
                                            : [Colors.white, const Color(0xFFF8FAFC)],
                                        ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? netColor : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: netColor.withValues(alpha: 0.25),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    )
                                  ] : (isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _planCapacity(plan),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? netColor : (isDark ? Colors.white : Colors.black87),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '₦${_planPrice(plan)}',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                          ),
                                        ),
                                        if (plan['promo_old_price'] != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '₦${plan['promo_old_price']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.grey,
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: isDark ? Colors.red.withValues(alpha: 0.6) : Colors.red,
                                              decorationThickness: 2,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black12,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _planValidity(plan),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (plan['promo_label'] != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              plan['promo_label'].toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (plan['cashback_label'] != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: plan['cashback_label'].toString().toLowerCase().contains('new') 
                                                ? [Colors.orange.shade400, Colors.orange.shade600]
                                                : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: plan['cashback_label'].toString().toLowerCase().contains('new') 
                                                  ? Colors.orange.withValues(alpha: 0.3) 
                                                  : Colors.green.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          plan['cashback_label'].toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            ),
                          );
                        }),
                  ],
                  const SizedBox(height: 100), // Space for checkout button
                ],
              ),
            ),
          ),
          

        ],
      ),
    ),);
  }


}


class _EpicCheckoutButton extends StatelessWidget {
  final String network;
  final String amount;
  final bool loading;
  final VoidCallback onBuy;
  final Color netColor;

  const _EpicCheckoutButton({
    required this.network,
    required this.amount,
    required this.loading,
    required this.onBuy,
    required this.netColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: loading ? null : onBuy,
            style: FilledButton.styleFrom(
              backgroundColor: netColor,
              foregroundColor: netColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: loading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pay $amount',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded, size: 24),
                  ],
                ),
          ),
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

class _PremiumCheckoutCard extends StatelessWidget {
  final String network;
  final String phone;
  final String plan;
  final String amount;
  final bool loading;
  final VoidCallback onBuy;

  const _PremiumCheckoutCard({
    required this.network,
    required this.phone,
    required this.plan,
    required this.amount,
    required this.loading,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: primary.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYABLE AMOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  network.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: loading ? null : onBuy,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                backgroundColor: primary,
              ),
              child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
          color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF08101F) : const Color(0xFFE2E8F0),
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                      color: isDark ? const Color(0xFF1B3171) : const Color(0xFFD3E0FF),
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
                      color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
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
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF2A3A52) 
              : const Color(0xFFE2E8F0),
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

class _PurchaseSummaryModal extends StatefulWidget {
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
  State<_PurchaseSummaryModal> createState() => _PurchaseSummaryModalState();
}

class _PurchaseSummaryModalState extends State<_PurchaseSummaryModal> {
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final enabled = await BiometricService.isAppLockEnabled;
    final availability = await BiometricService.getAvailability();
    if (mounted) {
      setState(() {
        _bioAvailable = enabled && availability.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netColor = _globalGetNetworkColor(widget.network, context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: netColor.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
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
            
            // Header Icon & Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: netColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: netColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              ),
              child: Icon(Icons.check_circle_rounded, color: netColor, size: 36),
            ).animate().scale(duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            const Text(
              'Confirm Transaction',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please review your order details below',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Hero Amount Card
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
                  color: netColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: netColor.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL AMOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦${widget.price}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: netColor,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.2, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
            
            const SizedBox(height: 24),
            
            // Details List
            _PremiumSummaryItem(
              label: 'Network Provider',
              value: widget.network.toUpperCase(),
              icon: Icons.cell_tower_rounded,
              isDark: isDark,
            ),
            _PremiumSummaryItem(
              label: 'Phone Number',
              value: widget.phone,
              icon: Icons.phone_android_rounded,
              isDark: isDark,
            ),
            _PremiumSummaryItem(
              label: 'Data Package',
              value: widget.planName,
              icon: Icons.wifi_tethering_rounded,
              isDark: isDark,
            ),
            _PremiumSummaryItem(
              label: 'Validity Period',
              value: widget.planValidity,
              icon: Icons.event_available_rounded,
              isDark: isDark,
            ),
            
            const SizedBox(height: 40),
            
            // Modern Pay Button Block
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  if (_bioAvailable) {
                    widget.onProceedBiometric();
                  } else {
                    widget.onProceedPin();
                  }
                },
                icon: Icon(
                  _bioAvailable ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  _bioAvailable ? 'Confirm with Biometrics' : 'Confirm & Pay with PIN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: netColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 8,
                  shadowColor: netColor.withValues(alpha: 0.4),
                ),
              ),
            ).animate().slideY(begin: 0.3, delay: const Duration(milliseconds: 100), duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
            
            if (_bioAvailable) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onProceedPin();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: Text(
                  'Pay with PIN instead',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: netColor,
                  ),
                ),
              ),
            ],
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
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
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

class _NetworkCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color netColor;

  const _NetworkCard({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.netColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 86,
        height: 86,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? netColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? netColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2457F5).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NetworkIcon(network: name, size: 30),
            const SizedBox(height: 8),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
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
    if (n.contains('airtel')) {
      asset = 'assets/networks/airtel.svg';
    } else if (n.contains('glo')) {
      asset = 'assets/networks/glo.svg';
    } else if (n.contains('9mobile')) {
      asset = 'assets/networks/9mobile.svg';
    }

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ElitePlanTile extends StatelessWidget {
  final dynamic plan;
  final bool selected;
  final VoidCallback onTap;
  final Color? netColor;

  const _ElitePlanTile({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
    this.netColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final network = (plan['network'] ?? '').toString().toLowerCase();
    final capacity = _planDisplayTitle(plan, network);
    final price = _planPriceValueFormatted(plan);
    final validity = plan['validity']?.toString() ?? '30d';

    final bool promoActive = plan['promo_active'] == true ||
        plan['promo_active'] == 1 ||
        plan['promo_active']?.toString().toLowerCase() == 'true';
    final String? promoLabel = plan['promo_label']?.toString();
    final String? cashbackLabel = plan['cashback_label']?.toString();
    
    double? promoOldPrice;
    if (plan['promo_old_price'] != null) {
      promoOldPrice = double.tryParse(plan['promo_old_price'].toString());
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
              : (isDark ? const Color(0xFF111827) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected 
                ? primary 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0xFF08101F) : const Color(0xFFE2E8F0),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Capacity / Name
            Text(
              capacity,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 2. Price row (strikethrough previous price)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '₦$price',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? primary : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (promoActive && promoOldPrice != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '₦${_formatMoneyValue(promoOldPrice)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 3. Validity & Promo discount labels
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    validity,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                 if (promoActive && promoLabel != null && promoLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                      color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      promoLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
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
              color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
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
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : (isDark
                  ? const Color(0xFF111827)
                  : const Color(0xFFF4F6FA)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? primary
              : (isDark
                    ? const Color(0xFF2A3A52)
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
            label: 'MELE Bolt',
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
                      'assets/brand/meledata-logo.png',
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
                'MELE DATA',
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
                value: 'MELE DATA',
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
                'meledata.ng',
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
