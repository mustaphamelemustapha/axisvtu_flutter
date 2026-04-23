import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/dashboard_snapshot_cache.dart';
import '../services/notifications_service.dart';
import '../services/transactions_service.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import 'notification_center_screen.dart';
import '../widgets/theme_toggle_button.dart';
import 'airtime_screen.dart';
import 'cable_screen.dart';
import 'data_screen.dart';
import 'electricity_screen.dart';
import 'exam_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _hideBalanceKey = 'wallet_hide_balance';
  static const _homeServiceAspectRatio = 1.12;
  Future<Map<String, dynamic>>? _walletFuture;
  Future<Map<String, dynamic>>? _accountsFuture;
  Future<List<dynamic>>? _transactionsFuture;
  Future<List<Map<String, dynamic>>>? _notificationsFuture;
  Map<String, dynamic>? _cachedWalletData;
  Map<String, dynamic>? _cachedAccountsData;
  List<dynamic>? _cachedTransactionsData;
  String _activeToken = '';
  String _activeDashboardKey = '';
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    _loadBalancePreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = (context.watch<SessionController>().token ?? '').trim();
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(
          context.read<SessionController>().user,
        ) ??
        token;
    if (token.isNotEmpty &&
        dashboardKey.isNotEmpty &&
        (token != _activeToken ||
            _walletFuture == null ||
            _accountsFuture == null ||
            _transactionsFuture == null ||
            dashboardKey != _activeDashboardKey)) {
      if (dashboardKey != _activeDashboardKey) {
        _cachedWalletData = null;
        _cachedAccountsData = null;
        _cachedTransactionsData = null;
      }
      _activeDashboardKey = dashboardKey;
      _reloadDashboard(token, dashboardKey);
      _loadCachedDashboard(dashboardKey);
      _activeToken = token;
    }
  }

  Future<void> _loadBalancePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideBalance = prefs.getBool(_hideBalanceKey) ?? false;
    });
  }

  Future<void> _toggleBalanceVisibility() async {
    final next = !_hideBalance;
    setState(() => _hideBalance = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideBalanceKey, next);
  }

  Future<void> _loadCachedDashboard(String dashboardKey) async {
    final cached = await DashboardSnapshotCache.load(dashboardKey);
    if (!mounted || dashboardKey != _activeDashboardKey) return;
      setState(() {
        _cachedWalletData = _asMap(cached?['wallet']);
        _cachedAccountsData = _asMap(cached?['accounts']);
        final cachedTransactions = cached?['transactions'];
        if (cachedTransactions is List) {
          _cachedTransactionsData = cachedTransactions
              .whereType<Map>()
              .map(
                (item) => item.map(
                  (k, v) => MapEntry(k.toString(), v),
                ),
            )
            .toList();
      }
    });
  }

  void _reloadDashboard(String token, String dashboardKey) {
    final service = WalletService(token: token);
    final txService = TransactionsService(token: token);
    _walletFuture = service.getWallet();
    _accountsFuture = service.getBankAccounts();
    _transactionsFuture = txService.getTransactions();
    _notificationsFuture = _loadNotifications(token);
    _walletFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, wallet: data));
    }).catchError((_) {});
    _accountsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, accounts: data));
    }).catchError((_) {});
    _transactionsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      final normalized = data
          .whereType<Map>()
          .map(
            (item) => item.map((k, v) => MapEntry(k.toString(), v)),
          )
          .toList();
      _cachedTransactionsData = normalized;
      unawaited(
        DashboardSnapshotCache.save(
          dashboardKey,
          transactions: normalized,
        ),
      );
    }).catchError((_) {});
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return null;
  }

  Future<void> _refresh() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(
          context.read<SessionController>().user,
        ) ??
        token;
    setState(() {
      _reloadDashboard(token, dashboardKey);
    });
    await Future.wait([
      _walletFuture!,
      _accountsFuture!,
      _transactionsFuture ?? Future.value(<dynamic>[]),
      _notificationsFuture ?? Future.value(<Map<String, dynamic>>[]),
    ]);
  }

  Future<List<Map<String, dynamic>>> _loadNotifications(String token) async {
    try {
      final rows = await NotificationsService(token: token).getBroadcasts();
      return rows
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _copyAccountNumber(String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account number copied')));
  }

  String _formatAccountNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatNaira(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  List<Map<String, dynamic>> _normalizeTransactions(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  String _txStatusOf(Map<String, dynamic> tx) {
    return (tx['status'] ?? 'pending').toString().trim().toLowerCase();
  }

  String _txTypeOf(Map<String, dynamic> tx) {
    return (tx['tx_type'] ?? 'transaction').toString().trim().toLowerCase();
  }

  bool _txIsCredit(Map<String, dynamic> tx) => _txTypeOf(tx) == 'wallet_fund';

  Color _txStatusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s == 'success') return const Color(0xFF16A34A);
    if (s == 'pending' || s == 'processing' || s == 'queued') {
      return const Color(0xFFF59E0B);
    }
    if (s == 'refunded') return const Color(0xFF0EA5E9);
    return Theme.of(context).colorScheme.error;
  }

  String _txAmountLabel(Map<String, dynamic> tx) {
    final amount = double.tryParse(tx['amount']?.toString() ?? '') ?? 0;
    final sign = _txIsCredit(tx) ? '+' : '-';
    return '$sign₦${amount.toStringAsFixed(2)}';
  }

  String _txTitleFor(Map<String, dynamic> tx) {
    return switch (_txTypeOf(tx)) {
      'data' => 'Data Purchase',
      'wallet_fund' => 'Wallet Funding',
      'airtime' => 'Airtime Purchase',
      'cable' => 'Cable Subscription',
      'electricity' => 'Electricity Payment',
      'exam' => 'Exam Pin Purchase',
      _ => 'Transaction',
    };
  }

  String _txSubtitleFor(Map<String, dynamic> tx) {
    final meta = tx['meta'];
    if (meta is Map) {
      final recipient =
          meta['recipient_phone'] ??
          meta['phone_number'] ??
          meta['meter_number'];
      if ((recipient ?? '').toString().trim().isNotEmpty) {
        return recipient.toString();
      }
      final package = meta['package_code'];
      if ((package ?? '').toString().trim().isNotEmpty) {
        return package.toString();
      }
    }
    final network = (tx['network'] ?? '').toString().trim();
    if (network.isNotEmpty) return network.toUpperCase();
    return (tx['reference'] ?? '').toString();
  }

  DateTime? _txCreatedAt(Map<String, dynamic> tx) {
    final raw = tx['created_at'];
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  String _txDateLabel(Map<String, dynamic> tx) {
    final date = _txCreatedAt(tx);
    if (date == null) return '—';
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(date.year, date.month, date.day);
    final time = TimeOfDay.fromDateTime(date.toLocal()).format(context);
    if (txDay == day) return 'Today • $time';
    return '${date.day} ${_monthShort(date.month)} • $time';
  }

  String _monthShort(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      default:
        return 'Dec';
    }
  }

  double _extractBalance(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final direct = data['balance'];
    if (direct != null) {
      return double.tryParse(direct.toString()) ?? 0;
    }
    final nested = data['wallet'];
    if (nested is Map) {
      return double.tryParse((nested['balance'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _openScreen(Widget screen) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openNotificationsCenter() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  double _homeServiceAspectRatioForWidth(double width) {
    if (width < 340) return 0.98;
    if (width < 380) return 1.04;
    if (width < 430) return 1.08;
    return _homeServiceAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final user = context.watch<SessionController>().user ?? {};
    final name = (user['full_name'] ?? user['name'] ?? 'AxisVTU User')
        .toString()
        .trim();
    final role = (user['role'] ?? 'Member').toString().trim();
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.66);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark
        ? Colors.white.withValues(alpha: 0.84)
        : const Color(0xFF5B6B82);

    final services = <_HomeService>[
      _HomeService(
        label: 'Buy Data',
        subtitle: 'MTN • Glo • Airtel • 9mobile',
        icon: Icons.wifi_rounded,
        accent: const Color(0xFF3B82F6),
        onTap: () => _openScreen(const DataScreen()),
      ),
      _HomeService(
        label: 'Airtime',
        subtitle: 'Top up in seconds',
        icon: Icons.phone_iphone_rounded,
        accent: const Color(0xFF10B981),
        onTap: () => _openScreen(const AirtimeScreen()),
      ),
      _HomeService(
        label: 'Electricity',
        subtitle: 'Instant meter token',
        icon: Icons.bolt_rounded,
        accent: const Color(0xFFF59E0B),
        onTap: () => _openScreen(const ElectricityScreen()),
      ),
      _HomeService(
        label: 'Cable TV',
        subtitle: 'DSTV • GOTV • Startimes',
        icon: Icons.live_tv_rounded,
        accent: const Color(0xFF8B5CF6),
        onTap: () => _openScreen(const CableScreen()),
      ),
      _HomeService(
        label: 'Exam Pins',
        subtitle: 'WAEC • NECO • JAMB',
        icon: Icons.school_rounded,
        accent: const Color(0xFFEF4444),
        onTap: () => _openScreen(const ExamScreen()),
      ),
      _HomeService(
        label: 'Wallet',
        subtitle: 'Generate account',
        icon: Icons.account_balance_wallet_rounded,
        accent: const Color(0xFF0EA5E9),
        onTap: () => widget.onNavigateTab?.call(1),
      ),
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        displacement: 18,
        edgeOffset: 10,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    gradient: AxisPalette.gradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials.isEmpty ? 'AX' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          fontSize: compact ? 18 : 19,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'AxisVTU ${role.isEmpty ? 'Member' : role}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _HeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  size: 40,
                  onTap: _openNotificationsCenter,
                ),
                const SizedBox(width: 6),
                const ThemeToggleButton(size: 40),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(compact ? 14 : 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1724) : const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(compact ? 24 : 28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(
                    alpha: isDark ? 0.14 : 0.10,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.16)
                        : const Color(0xFF2457F5).withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF2457F5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet balance',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: heroSoftText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Available for data, airtime, bills, and exam pins.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: heroSoftText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _toggleBalanceVisibility,
                          icon: AnimatedSwitcher(
                            duration: AxisDurations.normal,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              _hideBalance
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              key: ValueKey(_hideBalance),
                              color: heroText,
                            ),
                          ),
                          tooltip: _hideBalance ? 'Show balance' : 'Hide balance',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(9),
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _walletFuture,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final walletData = snapshot.data ??
                          ((isLoading || snapshot.hasError) &&
                                  _cachedWalletData != null
                              ? _cachedWalletData
                              : null);
                      if (walletData == null) {
                        if (snapshot.hasError) {
                          return _DashboardBalanceError(
                            onRefresh: _refresh,
                          );
                        }
                        return const _DashboardBalanceSkeleton();
                      }
                      final balance = _extractBalance(walletData);
                      return AnimatedSwitcher(
                        duration: AxisDurations.normal,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: _hideBalance
                            ? Text(
                                '₦ ••••••',
                                key: const ValueKey('hidden_home_balance'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: heroText,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  fontSize: compact ? 28 : 32,
                                ),
                              )
                            : Text(
                                '₦${_formatNaira(balance)}',
                                key: const ValueKey('visible_home_balance'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: heroText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 28 : 32,
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _accountsFuture,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final accountsData = snapshot.data ??
                          ((isLoading || snapshot.hasError) &&
                                  _cachedAccountsData != null
                              ? _cachedAccountsData
                              : null);
                      if (accountsData == null) {
                        if (snapshot.hasError) {
                          return _FundingAccountUnavailable(
                            message: 'Wallet details are temporarily unavailable.',
                            actionLabel: 'Open Wallet',
                            onAction: () => widget.onNavigateTab?.call(1),
                          );
                        }
                        return const _FundingAccountSkeleton();
                      }

                      final accounts =
                          (accountsData['accounts'] as List?) ?? const [];
                      if (accounts.isEmpty) {
                        return _FundingAccountUnavailable(
                          message: 'Wallet details will appear shortly.',
                          actionLabel: 'Open Wallet',
                          onAction: () => widget.onNavigateTab?.call(1),
                        );
                      }
                      final item = accounts.first is Map
                          ? Map<String, dynamic>.from(accounts.first as Map)
                          : <String, dynamic>{};
                      final rawName = (item['bank_name'] ?? 'Paystack-Titan')
                          .toString()
                          .trim();
                      final rawAccountName = (item['account_name'] ?? name)
                          .toString()
                          .trim();
                      final rawNumber = (item['account_number'] ?? '')
                          .toString()
                          .trim();
                      if (rawNumber.isEmpty) {
                        return _FundingAccountUnavailable(
                          message: 'Wallet details will appear shortly.',
                          actionLabel: 'Open Wallet',
                          onAction: () => widget.onNavigateTab?.call(1),
                        );
                      }

                      final formattedNumber = _formatAccountNumber(rawNumber);

                      return _FundingAccountBlock(
                        bankName: rawName.isEmpty ? 'Paystack-Titan' : rawName,
                        accountNumber: formattedNumber,
                        accountName:
                            rawAccountName.isEmpty ? name : rawAccountName,
                        onCopyAccount: () => _copyAccountNumber(rawNumber),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Services',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 430 ? 3 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: services.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: compact ? 98 : 104,
                    ),
                    itemBuilder: (context, index) {
                      final item = services[index];
                      return _ServiceCard(item: item);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(3),
                  child: const Text('History'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(
              future: _transactionsFuture,
              initialData: _cachedTransactionsData,
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final hasError = snapshot.hasError;
                final raw = snapshot.data ?? const <dynamic>[];
                final items = _normalizeTransactions(raw);
                final recent = items.take(10).toList();
                if (recent.isEmpty && isLoading && _cachedTransactionsData == null) {
                  return const _RecentActivityLoadingState();
                }
                if (recent.isEmpty && hasError && _cachedTransactionsData == null) {
                  return _RecentActivityErrorState(
                    onRetry: _refresh,
                  );
                }
                if (recent.isEmpty) {
                  return const _RecentActivityEmptyState();
                }
                return GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        _RealActivityRow(
                          title: _txTitleFor(recent[i]),
                          subtitle: _txSubtitleFor(recent[i]),
                          meta:
                              '${_txStatusOf(recent[i]).toUpperCase()} • ${_txDateLabel(recent[i])}',
                          amount: _txAmountLabel(recent[i]),
                          accent: _txStatusColor(
                            context,
                            _txStatusOf(recent[i]),
                          ),
                        ),
                        if (i != recent.length - 1) const Divider(height: 22),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RealActivityRow extends StatelessWidget {
  const _RealActivityRow({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    final amountColor = amount.startsWith('-')
        ? Theme.of(context).colorScheme.onSurface
        : accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityLoadingState extends StatelessWidget {
  const _RecentActivityLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _RecentActivitySkeleton(),
        ),
      ),
    );
  }
}

class _RecentActivitySkeleton extends StatelessWidget {
  const _RecentActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A2433) : const Color(0xFFEAF0F7);
    final shimmer = isDark ? const Color(0xFF243244) : const Color(0xFFF4F7FB);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: 120,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: 160,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: 94,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              height: 12,
              width: 72,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 18,
              width: 54,
              decoration: BoxDecoration(
                color: base.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentActivityEmptyState extends StatelessWidget {
  const _RecentActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent transactions yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your recent purchases and wallet activity will appear here as soon as you start using AxisVTU.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityErrorState extends StatelessWidget {
  const _RecentActivityErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.sync_problem_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Recent activity is unavailable',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We could not load the latest wallet activity just now. You can try again in a moment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onTap, this.size = 44});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.22),
          ),
        ),
        child: Icon(icon, size: size <= 40 ? 19 : 21),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _HomeService {
  const _HomeService({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}

class _FundingAccountBlock extends StatelessWidget {
  const _FundingAccountBlock({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.onCopyAccount,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;
  final VoidCallback? onCopyAccount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final softText = isDark
        ? Colors.white.withValues(alpha: 0.76)
        : const Color(0xFF5B6B82);
    final subtleLine = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final formattedNumber = accountNumber.trim().isEmpty ? '—' : accountNumber;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 15),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF101A2A), Color(0xFF162338)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: isDark ? 0.10 : 0.10,
              ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.14 : 0.03,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AxisPalette.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: heroText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCopyAccount,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formattedNumber,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: heroText,
                              fontWeight: FontWeight.w800,
                              letterSpacing: compact ? 2.6 : 3.2,
                              height: 1.1,
                              fontSize: compact ? 27 : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: subtleLine),
                  ),
                  child: IconButton(
                    onPressed: onCopyAccount,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy account number',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: compact ? 30 : 32,
                      height: compact ? 30 : 32,
                    ),
                    color: heroText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            accountName,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: heroText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.05,
                ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Transfer to this account to fund your wallet.',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: softText.withValues(alpha: isDark ? 0.78 : 0.72),
                  height: 1.25,
                ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.item});

  final _HomeService item;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 130),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.item.onTap();
          },
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 8 : 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: compact ? 34 : 38,
                      height: compact ? 34 : 38,
                      decoration: BoxDecoration(
                        color: widget.item.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.item.icon,
                        size: compact ? 18 : 20,
                        color: widget.item.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                            height: 1.05,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBalanceSkeleton extends StatelessWidget {
  const _DashboardBalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE8EEF9);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 110,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 180,
          height: 34,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 220,
          height: 11,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _DashboardBalanceError extends StatelessWidget {
  const _DashboardBalanceError({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wallet details are temporarily unavailable.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We’ll refresh them as soon as the connection is ready.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => onRefresh(),
          child: const Text('Refresh now'),
        ),
      ],
    );
  }
}

class _FundingAccountSkeleton extends StatelessWidget {
  const _FundingAccountSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE8EEF9);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1624) : const Color(0xFFFEFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: isDark ? 0.12 : 0.14,
              ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 160,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundingAccountUnavailable extends StatelessWidget {
  const _FundingAccountUnavailable({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your dedicated account details will appear here once they are ready.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: actionLabel,
              icon: Icons.account_balance_wallet_rounded,
              onPressed: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}
