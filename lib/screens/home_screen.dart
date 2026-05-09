import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'referral_screen.dart';
import '../services/purchase_auth_service.dart';
import '../services/transaction_pin_service.dart';

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
    Future.delayed(Duration.zero, () {
      if (mounted) _initialSecurityCheck();
    });
  }

  Future<void> _initialSecurityCheck() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;

    final service = TransactionPinService(token: token);
    try {
      final status = await service.statusOrNull();
      if (!mounted) return;

      if (status != null && !status.isSet) {
        // Show the setup flow proactively for new/web users
        await PurchaseAuthService.authorizePin(
          context: context,
          reason: 'account security',
          preferredMethod: PurchaseAuthService.methodPin,
        );
      }
    } catch (_) {
      // Silently fail to avoid blocking the home screen
    }
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

  Future<void> _launchSupport() async {
    final phone = '+2348141114647';
    final url = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
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
      setState(() {
        _cachedWalletData = _asMap(data);
      });
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
    return NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(parsed);
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
      'data' => 'Data Bundle',
      'wallet_fund' => 'Credit Added',
      'airtime' => 'Mobile Airtime',
      'cable' => 'TV Subscription',
      'electricity' => 'Power Token',
      'exam' => 'Educational Pin',
      _ => 'Utility Service',
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

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
    final referralCode = (user['referral_code'] ?? '').toString().trim();
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withOpacity(0.66);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark
        ? Colors.white.withOpacity(0.84)
        : const Color(0xFF5B6B82);
    final balance = _extractBalance(_cachedWalletData);

    final services = <_HomeService>[
      _HomeService(
        label: 'Buy Data',
        subtitle: 'Internet bundles',
        icon: Icons.wifi_rounded,
        accent: const Color(0xFF3B82F6),
        onTap: () => _openScreen(const DataScreen()),
      ),
      _HomeService(
        label: 'Airtime',
        subtitle: 'Mobile top-up',
        icon: Icons.phone_iphone_rounded,
        accent: const Color(0xFF10B981),
        onTap: () => _openScreen(const AirtimeScreen()),
      ),
      _HomeService(
        label: 'Electricity',
        subtitle: 'Meter tokens',
        icon: Icons.bolt_rounded,
        accent: const Color(0xFFF59E0B),
        onTap: () => _openScreen(const ElectricityScreen()),
      ),
      _HomeService(
        label: 'Cable TV',
        subtitle: 'TV Subscriptions',
        icon: Icons.live_tv_rounded,
        accent: const Color(0xFF8B5CF6),
        onTap: () => _openScreen(const CableScreen()),
      ),
      _HomeService(
        label: 'Exam Pins',
        subtitle: 'Educational pins',
        icon: Icons.school_rounded,
        accent: const Color(0xFFEF4444),
        onTap: () => _openScreen(const ExamScreen()),
      ),
      _HomeService(
        label: 'Referrals',
        subtitle: 'Invite rewards',
        icon: Icons.card_giftcard_rounded,
        accent: const Color(0xFFEC4899),
        onTap: () => _openScreen(const ReferralScreen()),
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
            // Compact Senior-Level Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _greetingText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: heroSoftText.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: heroText,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _openNotificationsCenter,
                      icon: const Icon(Icons.notifications_outlined, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ThemeToggleButton(size: 42),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // THE MASTERPIECE: Classically Premium Balance Section
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Subtle premium texture/gradient
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL BALANCE',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '₦',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _hideBalance
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '••••••••',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 4,
                                          ),
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              _formatNaira(balance).split('.').first,
                                              style: const TextStyle(
                                                fontSize: 38,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: -1,
                                                fontFeatures: [FontFeature.tabularFigures()],
                                              ),
                                            ),
                                            Text(
                                              '.${_formatNaira(balance).split('.').last}',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withOpacity(0.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _toggleBalanceVisibility,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          // Ultra-Polished Account Bar
                          FutureBuilder<Map<String, dynamic>>(
                            future: _accountsFuture,
                            initialData: _cachedAccountsData,
                            builder: (context, snapshot) {
                              final data = snapshot.data;
                              final accounts = (data?['accounts'] as List?) ?? [];
                              if (accounts.isEmpty) return const SizedBox.shrink();
                              
                              final first = accounts.first as Map;
                              final bank = (first['bank_name'] ?? 'Bank').toString().toUpperCase();
                              final number = first['account_number'] ?? '';
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'BANK NAME:',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.3),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  bank,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            name.toUpperCase(),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.blue.withOpacity(0.8),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          number.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _copyAccountNumber(number.toString()),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.copy_rounded,
                                                size: 16,
                                                color: Colors.white.withOpacity(0.4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Services',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Tap to start a new transaction',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: heroSoftText.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
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
            const SizedBox(height: 24),

            // Purchase History
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Purchase History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(2),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(
              future: _transactionsFuture,
              initialData: _cachedTransactionsData,
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final raw = snapshot.data ?? const <dynamic>[];
                final items = _normalizeTransactions(raw);
                final recent = items.take(4).toList();
                
                if (recent.isEmpty && !isLoading) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: recent.map((tx) => _RecentActivityTile(
                    tx: tx,
                    title: _txTitleFor(tx),
                    subtitle: _txSubtitleFor(tx),
                    amount: _txAmountLabel(tx),
                    date: _txDateLabel(tx).split(' • ').first,
                  )).toList(),
                );
              },
            ),

            // Support/Help Section - Human Warmth
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9).withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need any help?',
                          style: TextStyle(
                            color: heroText,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'We are here for you 24/7',
                          style: TextStyle(
                            color: heroSoftText.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _launchSupport,
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Chat now', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'AXISVTU v1.0.4 • SECURE & TRUSTED',
                style: TextStyle(
                  color: muted.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.62);
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
              color: accent.withOpacity(0.14),
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
                color: base.withOpacity(0.12),
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.62);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.62);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.10),
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
            ).colorScheme.outline.withOpacity(0.22),
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.12),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
        ? Colors.white.withOpacity(0.76)
        : const Color(0xFF5B6B82);
    final subtleLine = isDark
        ? Colors.white.withOpacity(0.08)
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
          color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.08 : 0.06,),
        ),
        boxShadow: AxisShadows.softGlow,
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
                        ? Colors.white.withOpacity(0.10)
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
                  color: softText.withOpacity(isDark ? 0.78 : 0.72),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 360;
    
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.item.onTap();
          },
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F2C) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.08 : 0.05),
              ),
              boxShadow: _pressed ? [] : AxisShadows.softGlow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    color: widget.item.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: compact ? 20 : 22,
                    color: widget.item.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: compact ? 12 : 13,
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

class _DashboardBalanceSkeleton extends StatelessWidget {
  const _DashboardBalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withOpacity(0.10)
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.64);
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
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFFE8EEF9);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1624) : const Color(0xFFFEFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.12 : 0.14,),
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
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.64);
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.16),
        ),
        boxShadow: AxisShadows.softGlow,
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
                  ).colorScheme.onSurface.withOpacity(0.65),
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
              ).colorScheme.onSurface.withOpacity(0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner({required this.referralCode});

  final String referralCode;

  @override
  Widget build(BuildContext context) {
    if (referralCode.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.65);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2A) : const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.06 : 0.04,),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite & Earn Rewards',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Share your referral code',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              await Clipboard.setData(ClipboardData(text: referralCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referral code copied')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.12,),
                ),
                boxShadow: AxisShadows.softGlow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    referralCode,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({
    required this.accountsFuture,
    required this.cachedAccounts,
    required this.onCopy,
    required this.formatNumber,
    required this.name,
  });

  final Future<Map<String, dynamic>>? accountsFuture;
  final Map<String, dynamic>? cachedAccounts;
  final Function(String) onCopy;
  final String Function(String) formatNumber;
  final String name;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add Credit',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow these simple steps to top up your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _StepTile(
            number: '1',
            title: 'Copy top-up details',
            subtitle: 'Tap to copy your dedicated top-up details.',
            icon: Icons.copy_rounded,
          ),
          _StepTile(
            number: '2',
            title: 'Make a transfer',
            subtitle: 'Send any amount to the account below.',
            icon: Icons.account_balance_rounded,
          ),
          _StepTile(
            number: '3',
            title: 'Automatic reflection',
            subtitle: 'Your account credit will reflect instantly.',
            icon: Icons.flash_on_rounded,
            isLast: true,
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: widget.accountsFuture,
            initialData: widget.cachedAccounts,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                );
              }
              final accounts = (data['accounts'] as List?) ?? [];
              if (accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Your dedicated top-up details are being prepared. Please check back in a moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                );
              }
              final item = accounts.first;
              final bank = item['bank_name'] ?? 'Bank';
              final number = item['account_number'] ?? '';
              final accName = item['account_name'] ?? widget.name;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2233) : const Color(0xFFF1F5FF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              bank.toString().toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => widget.onCopy(number.toString()),
                          child: Text(
                            widget.formatNumber(number.toString()),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          accName.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Copy Account Number',
                    icon: Icons.copy_all_rounded,
                    onPressed: () => widget.onCopy(number.toString()),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Need help? Contact support at axisvtu.com',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    ));
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Icon(icon, size: 14, color: muted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({
    required this.tx,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });
  final Map<String, dynamic> tx;
  final String title;
  final String subtitle;
  final String amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = tx['tx_type'] == 'wallet_fund';
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final status = (tx['status'] ?? 'success').toString().toLowerCase();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.08 : 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isCredit ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: status == 'success' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isCredit ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              Text(
                date,
                style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _txTitleFor(Map<String, dynamic> tx) {
    final type = tx['tx_type']?.toString() ?? '';
    return switch (type) {
      'data' => 'Data Bundle',
      'airtime' => 'Airtime',
      'wallet_fund' => 'Top-up',
      'cable' => 'Cable TV',
      'electricity' => 'Electricity',
      'exam' => 'Exam PIN',
      _ => 'Service',
    };
  }

  String _txSubtitleFor(Map<String, dynamic> tx) {
    final network = tx['network']?.toString() ?? '';
    if (network.isNotEmpty) return network.toUpperCase();
    return tx['reference']?.toString() ?? '';
  }

  String _txAmountLabel(Map<String, dynamic> tx) {
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final isCredit = tx['tx_type'] == 'wallet_fund';
    return '${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(0)}';
  }
}
