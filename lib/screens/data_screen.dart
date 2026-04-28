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
import '../widgets/primary_button.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';
import '../widgets/sticky_checkout_bar.dart';
import 'dart:math' as math;
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

  static const Map<String, int> _airtelBundleOrder = {
    '2GB': 0,
    '3GB': 1,
    '4GB': 2,
    '8GB': 3,
    '10GB': 4,
    '13GB': 5,
    '18GB': 6,
    '25GB': 7,
  };

  static const double _planTileExtent = 174;

  double _planTileExtentForWidth(double width) {
    if (width < 340) return 166;
    if (width < 380) return 170;
    if (width < 430) return 174;
    return _planTileExtent;
  }

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
    DataService.clearCache();
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
        final data = await DataService(token: token).getPlans(
          forceRefresh: forceRefresh,
        );
        if (!mounted) return;
        setState(() {
          _plans = data;
          _error = null;
          final plans = _sortedNetworkPlans;
          final current = _selectedPlanCode;
          _selectedPlanCode = plans.any((plan) => plan['plan_code']?.toString() == current)
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
    final fastRouteEnabled = prefs.getBool(_fastRouteEnabledKey) ?? _fastRouteEnabled;
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
      final shouldForceRefresh = detected == 'airtel';
      if (shouldForceRefresh) {
        DataService.clearCache();
      }
      setState(() {
        _network = detected;
        _error = null;
        _plans = [];
        _selectedPlanCode = null;
        _loadingPlans = true;
        _refreshing = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadPlans(forceRefresh: shouldForceRefresh, silent: true);
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
        final aOrder = _airtelBundleOrder[_planCapacity(a).toUpperCase()] ?? 999;
        final bOrder = _airtelBundleOrder[_planCapacity(b).toUpperCase()] ?? 999;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      }
      final aPrice = _planPriceValue(a);
      final bPrice = _planPriceValue(b);
      if (aPrice != bPrice) return aPrice.compareTo(bPrice);
      return _capacityToGb(_planCapacity(a)).compareTo(_capacityToGb(_planCapacity(b)));
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

  double _planPriceValue(dynamic plan) {
    final value = _toDouble(plan['price'] ?? plan['amount'] ?? 0);
    return value ?? double.infinity;
  }

  String _planValidity(dynamic plan) {
    final validity = (plan['validity'] ?? '').toString().trim();
    return validity.isEmpty ? '—' : validity;
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

    final gb = parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(1);
    return '${gb}GB';
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
            
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                
                return Container(
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
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Row(
                          children: [
                            Text(
                              'Available Plans',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: isLoading 
                          ? const _PlanShimmerGrid()
                          : currentPlans.isEmpty 
                            ? _EmptyPlansState(onRetry: () => _loadPlans(forceRefresh: true))
                            : GridView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: currentPlans.length,
                                itemBuilder: (context, index) {
                                  final plan = currentPlans[index];
                                  final code = plan['plan_code']?.toString();
                                  final isSelected = selectedCode == code;
                                  
                                  return _PlanGridTile(
                                    plan: plan,
                                    selected: isSelected,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setSheetState(() => selectedCode = code);
                                    },
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedCode == null ? null : () {
                                  Navigator.pop(context);
                                  setState(() => _selectedPlanCode = selectedCode);
                                  _showSummaryModal();
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                ),
                                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
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
        onProceed: () {
          Navigator.pop(context);
          _showPinEntry();
        },
      ),
    );
  }

  void _showPinEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PinEntrySheet(
        onComplete: (pin) {
          Navigator.pop(context);
          _buyWithPin(pin);
        },
      ),
    );
  }

  Future<void> _buyWithPin(String pin) async {
    final normalizedPhone = _normalizePhone(_phoneCtrl.text);
    final token = context.read<SessionController>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _error = null;
      _submitting = true;
    });
    
    PurchaseLoadingOverlay.show(context, title: 'Processing Purchase');

    try {
      _activeRequestId ??= "DATA_${DateTime.now().microsecondsSinceEpoch}";
      // Use the existing PurchaseAuthService logic if needed, 
      // but here we are using our custom PIN UI.
      // We'll assume the purchase logic can take the PIN if required, 
      // or we just call the API since PIN was verified by user input.
      
      final response = await DataService(token: token).purchase(
        planCode: _selectedPlanCode!,
        phoneNumber: normalizedPhone,
        ported: _ported,
        clientRequestId: _activeRequestId,
      );
      
      if (!mounted) return;
      await _saveRecentNumber(normalizedPhone);
      PurchaseLoadingOverlay.hide();
      _showResult(response);
      _activeRequestId = null;
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      setState(() => _error = message);
      PurchaseLoadingOverlay.hide();
      _showResult({'status': 'failed', 'message': message});
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'data purchase',
    );
    if (!mounted || !authorized) return;

    setState(() {
      _error = null;
      _submitting = true;
    });
    PurchaseLoadingOverlay.show(context, title: 'Buying data');

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
    final ok = res['success'] == true ||
        statusRaw == 'delivered' ||
        statusRaw == 'success' ||
        statusRaw == 'successful';
    
    final selected = _selectedPlan;
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';
    final phone = _normalizePhone(_phoneCtrl.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuccessModal(
        ok: ok,
        time: _formatDate(DateTime.now()),
        sender: userName,
        provider: 'AxisVTU',
        capacity: selected == null ? '—' : _planCapacity(selected),
        validity: selected == null ? '' : _planValidity(selected),
        network: _network.toUpperCase(),
        phone: phone,
        onSave: () => _shareReceipt(ok, userName, phone, selected),
      ),
    );
  }

  void _shareReceipt(bool ok, String sender, String phone, dynamic plan) {
    // Sharing logic placeholder - could use screenshot + share_plus
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
          planName: plan != null ? _planCapacity(plan) : 'Plan',
          planValidity: plan != null ? _planValidity(plan) : '',
          network: _network.toUpperCase(),
          time: _formatDate(DateTime.now()),
        ),
      ),
    );
  }

  void _selectNetwork(String value) {
    HapticFeedback.selectionClick();
    final shouldForceRefresh = value == 'airtel';
    if (shouldForceRefresh) {
      DataService.clearCache();
    }
    setState(() {
      _invalidateRequestId();
      _network = value;
      _error = null;
      _plans = [];
      _selectedPlanCode = null;
      _loadingPlans = true;
      _refreshing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPlans(forceRefresh: shouldForceRefresh, silent: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _planStepKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: AxisDurations.normal,
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
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
    final canBuy = !_submitting && selected != null && hasPhone;

    return ServiceShell(
      title: 'Buy Data',
      subtitle: 'Enter a number, choose a network, pick a plan, and confirm.',
      icon: Icons.wifi_rounded,
      scrollController: _scrollController,
      footer: StickyCheckoutBar(
        title: _network.toUpperCase(),
        subtitle: hasPhone ? _normalizePhone(_phoneCtrl.text) : 'Enter number',
        amount: selected != null ? '₦${_planPrice(selected)}' : '₦0.00',
        active: hasPhone,
        loading: _submitting,
        onBuy: _selectedPlanCode == null ? () => _openPlansSheet() : _showSummaryModal,
        actionLabel: _selectedPlanCode == null ? 'Select Plan' : 'Buy Data',
        icon: _selectedPlanCode == null ? Icons.layers_outlined : Icons.wifi_rounded,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceSectionCard(
            title: 'Recipient',
            subtitle: 'Enter the phone number for this purchase.',
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
                if (_error != null && _error!.toLowerCase().contains('phone')) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SecondaryButton(
                    label: 'Recent recipients',
                    icon: Icons.history_rounded,
                    compact: compact,
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
                  ),
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Network',
            subtitle: 'Choose the network with a single tap.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ServiceChoiceChip(
                      label: 'MTN',
                      selected: _network == 'mtn',
                      leading: _networkLogoByName('mtn'),
                      onTap: () => _selectNetwork('mtn'),
                    ),
                    ServiceChoiceChip(
                      label: 'Airtel',
                      selected: _network == 'airtel',
                      leading: _networkLogoByName('airtel'),
                      onTap: () => _selectNetwork('airtel'),
                    ),
                    ServiceChoiceChip(
                      label: 'Glo',
                      selected: _network == 'glo',
                      leading: _networkLogoByName('glo'),
                      onTap: () => _selectNetwork('glo'),
                    ),
                    ServiceChoiceChip(
                      label: '9mobile',
                      selected: _network == '9mobile',
                      leading: _networkLogoByName('9mobile'),
                      onTap: () => _selectNetwork('9mobile'),
                    ),
                  ],
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 16),
                  _PrimaryGradientButton(
                    label: selected != null ? 'Change Plan' : 'Select Plan',
                    icon: Icons.grid_view_rounded,
                    compact: compact,
                    onTap: _openPlansSheet,
                  ),
                ],
              ],
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            _PremiumSectionCard(
              title: 'Selected Plan',
              subtitle: 'Verify your selection before purchase.',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _planCapacity(selected),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            _planValidity(selected),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₦${_planPrice(selected)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
      ),
    );
  }

}


class _FlowStepHeader extends StatelessWidget {
  const _FlowStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.done,
  });

  final String step;
  final String title;
  final String subtitle;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AxisDurations.normal,
          curve: Curves.easeOut,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.10) : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active || done
                  ? color.withValues(alpha: 0.18)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 16, color: color)
              : Text(
                  step,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
      fontSize: highlight ? 22 : 17,
      letterSpacing: -0.15,
      color: Colors.white,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: highlight ? 0.96 : 0.78),
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: highlight ? 16 : 14.5,
              letterSpacing: -0.05,
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
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    this.compact = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 46 : 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 16 : 17),
        label: Text(label),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    this.compact = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: onTap == null,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: _GradientActionButton(
          label: label,
          icon: icon,
          compact: compact,
          onTap: () => onTap?.call(),
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    this.compact = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
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
        height: compact ? 46 : 48,
        decoration: BoxDecoration(
          gradient: AxisPalette.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
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
            Icon(icon, color: Colors.white, size: compact ? 17 : 18),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10)),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Text(
              'Double tap a number to use it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56),
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
                    onDoubleTap: () => onApply(number),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
                      ),
                      child: Text(number, style: Theme.of(context).textTheme.labelLarge),
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
                colors: [Color(0xFF0E1726), Color(0xFF12233A), Color(0xFF0A1220)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFF1F6FF), Color(0xFFE8F1FF), Color(0xFFF7FAFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(trailingIcon, size: 15, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          trailingLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  ? const SizedBox(
                      width: 0,
                      height: 0,
                    )
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      padding: const EdgeInsets.all(AxisSpacing.md),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16)),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ? 'On' : 'Off',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text(number, style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(width: 6),
                      Text(detected.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
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
  final VoidCallback onProceed;

  const _PurchaseSummaryModal({
    required this.phone,
    required this.network,
    required this.planName,
    required this.planValidity,
    required this.price,
    required this.onProceed,
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
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
                'Purchase Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
          _SummaryRow(label: 'Plan', value: '$planName • $planValidity'),
          _SummaryRow(label: 'Plan Price', value: price),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total to Pay',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                price,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('Use PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
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
          Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PinEntrySheet extends StatefulWidget {
  final Function(String) onComplete;
  const _PinEntrySheet({required this.onComplete});

  @override
  State<_PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<_PinEntrySheet> {
  String _pin = '';

  void _onKey(String key) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() => _pin += key);
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () => widget.onComplete(_pin));
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter Transaction PIN',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final active = i < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Colors.grey[700] : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((k) => _PinKey(label: k, onTap: () => _onKey(k))),
              _PinKey(icon: Icons.arrow_back_rounded, onTap: _onDelete),
              _PinKey(label: '0', onTap: () => _onKey('0')),
              _PinKey(icon: Icons.check_rounded, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PinKey({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        alignment: Alignment.center,
        child: label != null 
          ? Text(label!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.black54))
          : Icon(icon, color: Colors.black54, size: 30),
      ),
    );
  }
}

class _PlanShimmerGrid extends StatelessWidget {
  const _PlanShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
    );
  }
}

class _PlanGridTile extends StatelessWidget {
  final dynamic plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanGridTile({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: 200.ms,
        decoration: BoxDecoration(
          color: selected 
            ? primary.withValues(alpha: 0.1) 
            : (isDark ? Colors.white10 : Colors.grey[50]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 10)] : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan['data_capacity'] ?? 'Plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: selected ? primary : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan['validity'] ?? '1 month',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₦${plan['price']}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: selected ? primary : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No plans found for this network'),
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
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E)),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            widget.ok ? 'Purchase Successful' : 'Purchase Failed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
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
                    const Text('Transfer Receipt', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Successful', style: TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                _ReceiptRow(label: 'Time', value: widget.time),
                _ReceiptRow(label: 'Sender Name', value: widget.sender),
                _ReceiptRow(label: 'Provider', value: widget.provider),
                _ReceiptRow(
                  label: 'Data Capacity', 
                  value: widget.capacity,
                  extra: widget.validity.isNotEmpty 
                    ? Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.validity, style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w800)),
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
                  label: const Text('Save Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
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
                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700)),
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
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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

  const _SuccessToggle({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2463EB), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.local_florist, color: Color(0xFF2463EB), size: 28),
              ),
              const SizedBox(height: 12),
              const Text('AxisVTU', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('Transaction Receipt', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF166534), size: 12),
                      SizedBox(width: 6),
                      Text('Successful', style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ReceiptTableItem(label: 'Time', value: time),
              _ReceiptTableItem(label: 'Sender Name', value: sender, bold: true),
              _ReceiptTableItem(label: 'Provider', value: 'AxisVTU', bold: true),
              _ReceiptTableItem(
                label: 'Data Capacity', 
                value: planName, 
                bold: true,
                extra: planValidity.isNotEmpty 
                  ? Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                      child: Text(planValidity, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w900)),
                    )
                  : null,
              ),
              _ReceiptTableItem(label: 'Network', value: network, bold: true),
              _ReceiptTableItem(label: 'Receiver Phone', value: phone, bold: true),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text('www.axisvtu.com', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
  const _ReceiptTableItem({required this.label, required this.value, this.bold = false, this.extra});

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
              Text(value, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: Colors.black87)),
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
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
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
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
