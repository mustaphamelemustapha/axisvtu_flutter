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
  final _scrollController = ScrollController();
  final bool _ported = false;
  final GlobalKey _planStepKey = GlobalKey();

  String _network = 'mtn';
  String _planBucket = 'all';
  String? _selectedPlanCode;
  List<dynamic> _plans = [];

  bool _loadingPlans = true;
  bool _autoAdvancedToPlans = false;
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
    _scrollController.dispose();
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
        final data = await DataService(token: token).getPlans(
          forceRefresh: forceRefresh,
        );
        if (!mounted) return;
        setState(() {
          _plans = data;
          final plans = _sortedNetworkPlans;
          final current = _selectedPlanCode;
          _selectedPlanCode = plans.isEmpty
              ? null
              : (plans.any((plan) => plan['plan_code']?.toString() == current)
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
    final fastRouteEnabled = prefs.getBool(_fastRouteEnabledKey) ?? _fastRouteEnabled;
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
        final plans = _sortedNetworkPlans;
        _selectedPlanCode = plans.isNotEmpty
            ? plans.first['plan_code']?.toString()
            : null;
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
      final aPrice = _planPriceValue(a);
      final bPrice = _planPriceValue(b);
      if (aPrice != bPrice) return aPrice.compareTo(bPrice);
      return _capacityToGb(_planCapacity(a)).compareTo(_capacityToGb(_planCapacity(b)));
    });
    return plans;
  }

  List<dynamic> _plansForBucket(List<dynamic> plans) {
    switch (_planBucket) {
      case 'daily':
        return plans.where(_isDailyPlan).toList();
      case 'weekly':
        return plans.where(_isWeeklyPlan).toList();
      case 'monthly':
        return plans.where(_isMonthlyPlan).toList();
      case 'value':
        return plans.where(_isValuePlan).toList();
      default:
        return plans;
    }
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

  bool _isDailyPlan(dynamic plan) {
    final text = '${_planValidity(plan)} ${_planCapacity(plan)} ${plan['name'] ?? ''} ${plan['plan_name'] ?? ''}'
        .toLowerCase();
    return text.contains('day');
  }

  bool _isWeeklyPlan(dynamic plan) {
    final text = '${_planValidity(plan)} ${_planCapacity(plan)} ${plan['name'] ?? ''} ${plan['plan_name'] ?? ''}'
        .toLowerCase();
    return text.contains('week');
  }

  bool _isMonthlyPlan(dynamic plan) {
    final text = '${_planValidity(plan)} ${_planCapacity(plan)} ${plan['name'] ?? ''} ${plan['plan_name'] ?? ''}'
        .toLowerCase();
    return text.contains('month') || text.contains('30 day');
  }

  bool _isValuePlan(dynamic plan) {
    final price = _planPriceValue(plan);
    final capacityGb = _capacityToGb(_planCapacity(plan));
    return price <= 1000 || capacityGb <= 1.5;
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

    final allPlans = _sortedNetworkPlans;
    if (allPlans.isEmpty) {
      setState(() {
        _error = 'No plans available for ${_network.toUpperCase()} right now.';
      });
      return;
    }

    String? selectedCode = _selectedPlanCode ?? allPlans.first['plan_code']?.toString();
    final bestValueCode = allPlans.first['plan_code']?.toString();
    var selectedBucket = _planBucket;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredPlans = allPlans.where((plan) {
              if (selectedBucket == 'all') return true;
              if (selectedBucket == 'daily') return _isDailyPlan(plan);
              if (selectedBucket == 'weekly') return _isWeeklyPlan(plan);
              if (selectedBucket == 'monthly') return _isMonthlyPlan(plan);
              if (selectedBucket == 'value') return _isValuePlan(plan);
              return true;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.82,
              minChildSize: 0.58,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  child: Container(
                    color: isDark ? const Color(0xFF0E1624) : Colors.white,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.view_carousel_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available Plans',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_network.toUpperCase()} • ${filteredPlans.length} plan${filteredPlans.length == 1 ? '' : 's'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ServiceChoiceChip(
                                label: 'All',
                                selected: selectedBucket == 'all',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedBucket = 'all');
                                  setState(() => _planBucket = 'all');
                                },
                              ),
                              const SizedBox(width: 8),
                              ServiceChoiceChip(
                                label: 'Daily',
                                selected: selectedBucket == 'daily',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedBucket = 'daily');
                                  setState(() => _planBucket = 'daily');
                                },
                              ),
                              const SizedBox(width: 8),
                              ServiceChoiceChip(
                                label: 'Weekly',
                                selected: selectedBucket == 'weekly',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedBucket = 'weekly');
                                  setState(() => _planBucket = 'weekly');
                                },
                              ),
                              const SizedBox(width: 8),
                              ServiceChoiceChip(
                                label: 'Monthly',
                                selected: selectedBucket == 'monthly',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedBucket = 'monthly');
                                  setState(() => _planBucket = 'monthly');
                                },
                              ),
                              const SizedBox(width: 8),
                              ServiceChoiceChip(
                                label: 'Value',
                                selected: selectedBucket == 'value',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() => selectedBucket = 'value');
                                  setState(() => _planBucket = 'value');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filteredPlans.isEmpty
                              ? _EmptyStateCard(
                                  icon: Icons.search_off_rounded,
                                  title: 'No matching plans',
                                  subtitle: 'Try another category or switch the network.',
                                )
                              : GridView.builder(
                                  controller: scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredPlans.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 7,
                                        mainAxisSpacing: 7,
                                        childAspectRatio: 0.92,
                                      ),
                                  itemBuilder: (context, index) {
                                    final plan = filteredPlans[index];
                                    final code = plan['plan_code']?.toString();
                                    final selected = selectedCode == code;
                                    final bestValue = code == bestValueCode;
                                    return _PlanTile(
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
                        const SizedBox(height: 10),
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
                                        setState(() => _selectedPlanCode = selectedCode);
                                        Navigator.of(context).pop();
                                        if (_normalizePhone(_phoneCtrl.text).isNotEmpty) {
                                          Future.microtask(_openPurchaseSummary);
                                        }
                                      },
                                icon: const Icon(Icons.check_circle_outline_rounded),
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
        var usingPin = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1424), Color(0xFF0E1B34), Color(0xFF112645)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
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
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Purchase Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
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
                              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          _SummaryLine(label: 'Recipient', value: normalizedPhone),
                          const SizedBox(height: 8),
                          _SummaryLine(label: 'Network', value: _planNetwork(selected)),
                          const SizedBox(height: 8),
                          _SummaryLine(
                            label: 'Plan',
                            value: '${_planCapacity(selected)} • ${_planValidity(selected)}',
                          ),
                          const SizedBox(height: 8),
                          _SummaryLine(
                            label: 'Amount',
                            value: '₦${totalAmount.toStringAsFixed(2)}',
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.lock_outline_rounded),
                            label: const Text('Use PIN'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
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
                                        content: Text('Biometric verification coming soon. Use PIN for now.'),
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
    final ok = res['success'] == true ||
        statusRaw == 'delivered' ||
        statusRaw == 'success' ||
        statusRaw == 'successful';
    final pending = !ok &&
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
            ? 'Data sent successfully'
            : (pending ? 'Purchase pending' : 'Purchase failed'),
        subtitle: res['message']?.toString() ??
            (ok ? 'Your data bundle has been processed.' : 'Purchase was not completed.'),
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ReceiptField(
            label: 'Sender Name',
            value: (context.read<SessionController>().user?['full_name'] ?? 'AxisVTU User').toString(),
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
            value: selected == null ? _network.toUpperCase() : _planNetwork(selected),
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
      final plans = _sortedNetworkPlans;
      _selectedPlanCode = plans.isNotEmpty ? plans.first['plan_code']?.toString() : null;
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
    final selected = _selectedPlan;
    final hasPhone = _normalizePhone(_phoneCtrl.text).isNotEmpty;
    final canBuy = !_submitting && selected != null && hasPhone;
    final planCount = _sortedNetworkPlans.length;
    final activeStep = !hasPhone
        ? 1
        : selected == null
            ? 3
            : 4;

    return ServiceShell(
      title: 'Buy Data',
      subtitle: 'Guided checkout, clean plan selection, and instant receipts.',
      icon: Icons.wifi_rounded,
      scrollController: _scrollController,
      footer: _StickyCheckoutBar(
        recipient: hasPhone ? _normalizePhone(_phoneCtrl.text) : 'No recipient',
        network: _network.toUpperCase(),
        plan: selected == null ? 'Select a plan' : _planCapacity(selected),
        amount: selected == null ? '₦0' : '₦${_planPrice(selected)}',
        active: canBuy,
        loading: _submitting,
        onBuy: canBuy ? _openPurchaseSummary : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TransactionHeroCard(
            title: 'Buy Data',
            subtitle:
                'Move through the purchase in four simple steps, with plans and summary kept clear at every stage.',
            primaryLabel: _refreshing ? 'Refreshing...' : 'Browse plans',
            secondaryLabel: 'Refresh plans',
            onPrimary: _openPlansSheet,
            onSecondary: _loadingPlans ? null : () => _loadPlans(forceRefresh: true),
            trailingLabel: '${_network.toUpperCase()} • $planCount plans',
            trailingIcon: Icons.network_cell_rounded,
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FlowStepHeader(
                  step: '1',
                  title: 'Recipient',
                  subtitle: 'Enter the phone number to start the flow.',
                  active: activeStep == 1,
                  done: hasPhone,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '080...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Recent recipients',
                        icon: Icons.history_rounded,
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
                if (_error != null && _error!.toLowerCase().contains('phone')) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FlowStepHeader(
                  step: '2',
                  title: 'Network',
                  subtitle: 'Pick the network with a single tap.',
                  active: activeStep >= 2,
                  done: true,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ServiceChoiceChip(
                        label: 'MTN',
                        selected: _network == 'mtn',
                        leading: _networkLogoByName('mtn'),
                        onTap: () => _selectNetwork('mtn'),
                      ),
                      const SizedBox(width: 8),
                      ServiceChoiceChip(
                        label: 'Airtel',
                        selected: _network == 'airtel',
                        leading: _networkLogoByName('airtel'),
                        onTap: () => _selectNetwork('airtel'),
                      ),
                      const SizedBox(width: 8),
                      ServiceChoiceChip(
                        label: 'Glo',
                        selected: _network == 'glo',
                        leading: _networkLogoByName('glo'),
                        onTap: () => _selectNetwork('glo'),
                      ),
                      const SizedBox(width: 8),
                      ServiceChoiceChip(
                        label: '9mobile',
                        selected: _network == '9mobile',
                        leading: _networkLogoByName('9mobile'),
                        onTap: () => _selectNetwork('9mobile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FlowStepHeader(
                  step: '3',
                  title: 'Plan',
                  subtitle: 'Choose a plan and keep the summary compact.',
                  active: activeStep >= 3,
                  done: selected != null,
                ),
                const SizedBox(height: 10),
                if (selected == null)
                  _EmptyStateCard(
                    title: 'No plan selected',
                    subtitle: 'Open the plan picker to choose a bundle.',
                    icon: Icons.grid_view_rounded,
                  )
                else
                  _SelectedPlanCard(
                    network: _planNetwork(selected),
                    capacity: _planCapacity(selected),
                    price: _planPrice(selected),
                    validity: _planValidity(selected),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: _loadingPlans ? 'Loading...' : 'Refresh plans',
                        icon: _refreshing ? Icons.sync : Icons.refresh_rounded,
                        onTap: _refreshing ? null : () => _loadPlans(forceRefresh: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryGradientButton(
                        label: 'Choose plan',
                        icon: Icons.grid_view_rounded,
                        onTap: _openPlansSheet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

class _StickyCheckoutBar extends StatelessWidget {
  const _StickyCheckoutBar({
    required this.recipient,
    required this.network,
    required this.plan,
    required this.amount,
    required this.active,
    required this.loading,
    required this.onBuy,
  });

  final String recipient;
  final String network;
  final String plan;
  final String amount;
  final bool active;
  final bool loading;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1522) : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${network.isEmpty ? 'NETWORK' : network} • ${plan.isEmpty ? 'Select plan' : plan}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.08,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: loading ? 'Buying...' : 'Buy Data',
                onPressed: active ? onBuy : null,
                loading: loading,
                icon: loading ? Icons.hourglass_top_rounded : Icons.send_rounded,
              ),
            ),
          ],
        ),
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
        height: 48,
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
            Icon(icon, color: Colors.white),
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
              const _EmptyStateCard(
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

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle, required this.icon, super.key});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSkeletonGrid extends StatelessWidget {
  const _PlanSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}

class _SelectedPlanCard extends StatelessWidget {
  const _SelectedPlanCard({
    super.key,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: AxisDurations.normal,
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111B2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.data_usage_rounded, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      network,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      validity,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.10 : 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Selected',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '₦$price',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    super.key,
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
      duration: AxisDurations.normal,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? (isDark ? 0.14 : 0.04) : (isDark ? 0.10 : 0.03)),
            blurRadius: selected ? 18 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.22) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
                width: 1,
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
                          letterSpacing: -0.18,
                        ),
                      ),
                    ),
                    if (bestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.26)),
                        ),
                        child: const Text(
                          'Best',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₦$price',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Spacer(),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.0,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    super.key,
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
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
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
