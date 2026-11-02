import '../config.dart';

import 'dart:async';
import '../utils/fast_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/dashboard_snapshot_cache.dart';
import '../services/auth_service.dart';
import '../services/transactions_service.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/animated_balance_text.dart';
import 'transfer_screen.dart';


const double _walletInsightAspectRatio = 1.46;



double _walletInsightExtentForWidth(double width) {
  if (width < 340) return 110;
  if (width < 380) return 118;
  if (width < 430) return 128;
  return 138;
}

int _walletInsightColumnsForWidth(double width) {
  if (width < 360) return 1;
  return 2;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _hideBalanceKey = 'wallet_hide_balance';
  Future<Map<String, dynamic>>? _walletFuture;
  Future<Map<String, dynamic>>? _accountsFuture;
  Future<List<Map<String, dynamic>>>? _transactionsFuture;
  Map<String, dynamic>? _cachedWalletData;
  Map<String, dynamic>? _cachedAccountsData;
  bool _generating = false;
  bool _hideBalance = false;
  String _activeToken = '';
  String _activeDashboardKey = '';
  Timer? _pollTimer;
  int _activeAccountIndex = 0;
  int? _activeBalanceTick;

  @override
  void initState() {
    super.initState();
    _loadBalancePreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final token = (session.token ?? '').trim();
    final balanceTick = session.balanceRefreshTick;
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(
          session.user,
        ) ??
        token;

    bool tickChanged = false;
    if (_activeBalanceTick == null) {
      _activeBalanceTick = balanceTick;
    } else if (balanceTick != _activeBalanceTick) {
      _activeBalanceTick = balanceTick;
      tickChanged = true;
    }

    if (token.isNotEmpty &&
        dashboardKey.isNotEmpty &&
        (token != _activeToken ||
            _walletFuture == null ||
            _accountsFuture == null ||
            dashboardKey != _activeDashboardKey ||
            tickChanged)) {
      if (_activeDashboardKey.isNotEmpty && dashboardKey != _activeDashboardKey) {
        _cachedWalletData = null;
        _cachedAccountsData = null;
      }
      _activeDashboardKey = dashboardKey;
      _reloadWallet(token, dashboardKey);
      _loadCachedWallet(dashboardKey);
      _startAutoRefresh(token);
      _activeToken = token;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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

  Future<void> _loadCachedWallet(String dashboardKey) async {
    final cached = await DashboardSnapshotCache.load(dashboardKey);
    if (!mounted || dashboardKey != _activeDashboardKey) return;
    setState(() {
      _cachedWalletData = _asMap(cached?['wallet']);
      _cachedAccountsData = _asMap(cached?['accounts']);
    });
  }

  void _reloadWallet(String token, String dashboardKey, {bool forceRefresh = false}) {
    final service = WalletService(token: token);
    _walletFuture = service.getWallet(forceRefresh: forceRefresh);
    _accountsFuture = service.getBankAccounts(forceRefresh: forceRefresh);
    _transactionsFuture = _loadRecentTransactions(token);
    _walletFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, wallet: data));
    }).catchError((e) {
      if (mounted) _handleAuthError(e);
    });
    _accountsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, accounts: data));
    }).catchError((e) {
      if (mounted) _handleAuthError(e);
    });
  }

  void _handleAuthError(Object error) {
    if (error is ApiException && (error.statusCode == 401 || error.statusCode == 403)) {
      final session = context.read<SessionController>();
      if (session.isAuthenticated) {
        session.lockForcefully();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please enter PIN or tap Use Password.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startAutoRefresh(String token) {
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(
          context.read<SessionController>().user,
        ) ??
        token;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _generating) return;
      setState(() => _reloadWallet(token, dashboardKey));
    });
  }

  Future<void> _refresh() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(
          context.read<SessionController>().user,
        ) ??
        token;
    setState(() => _reloadWallet(token, dashboardKey, forceRefresh: true));
    try {
      await Future.wait([
        _walletFuture!,
        _accountsFuture!,
        _transactionsFuture ?? Future.value(const <Map<String, dynamic>>[]),
      ]);
    } catch (e) {
      if (mounted) {
        _handleAuthError(e);
      }
    }
  }

  Future<void> _openScreen(Widget screen) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(FastRoute(page: screen));
  }

  Future<List<Map<String, dynamic>>> _loadRecentTransactions(String token) async {
    try {
      final rows = await TransactionsService(token: token).getTransactions();
      return _normalizeTransactions(rows);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _normalizeTransactions(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
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

  String _getShortBankName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('palmpay')) return 'PalmPay';
    if (lower.contains('safehaven') || lower.contains('safe haven')) return 'Safe Haven';
    if (lower.contains('9psb') || lower.contains('9 payment')) return '9PSB';
    if (lower.contains('moniepoint') || lower.contains('monnify')) return 'Moniepoint';
    if (lower.contains('titan') || lower.contains('paystack')) return 'Paystack Titan';
    if (lower.contains('wema')) return 'Wema';
    if (lower.contains('sterling')) return 'Sterling';
    return raw.split(' ').first;
  }



  double _extractBalance(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final direct = data['balance'];
    if (direct != null) return double.tryParse(direct.toString()) ?? 0;
    final nested = data['wallet'];
    if (nested is Map) {
      return double.tryParse((nested['balance'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  bool _isCredit(Map<String, dynamic> tx) {
    final type = _typeOf(tx);
    final failure = (tx['failure_reason'] ?? '').toString().trim().toLowerCase();
    final ref = (tx['reference'] ?? '').toString().trim().toUpperCase();

    String ledger = '';
    final meta = tx['meta'];
    if (meta is Map) {
      ledger = (meta['ledger_description'] ?? '').toString().trim().toLowerCase();
    }

    if (failure.contains('debit') || ledger.contains('debit')) {
      return false;
    }

    const creditTypes = {
      'wallet_fund',
      'wallet_funding',
      'fund',
      'funding',
      'topup',
      'top_up',
      'admin_credit',
      'agent_reward',
      'deposit',
      'credit',
      'refund',
      'cashback',
      'bonus',
      'referral_bonus',
      'transfer_in',
      'receive',
    };
    if (creditTypes.contains(type)) {
      return true;
    }

    if (failure.contains('credit') ||
        failure.contains('fund') ||
        failure.contains('deposit') ||
        failure.contains('reward') ||
        failure.contains('refund') ||
        failure.contains('bonus') ||
        ledger.contains('credit') ||
        ledger.contains('fund') ||
        ledger.contains('deposit') ||
        ledger.contains('reward') ||
        ledger.contains('refund') ||
        ledger.contains('bonus')) {
      return true;
    }

    if (ref.startsWith('FUND_') ||
        ref.startsWith('DEP_') ||
        ref.startsWith('TOP_') ||
        ref.startsWith('CREDIT_') ||
        ref.startsWith('MONNIFY_') ||
        ref.startsWith('PAYSTACK_') ||
        ref.startsWith('FLW_')) {
      return true;
    }

    return false;
  }

  String _typeOf(Map<String, dynamic> tx) {
    return (tx['tx_type'] ?? 'transaction').toString().trim().toLowerCase();
  }

  String _statusOf(Map<String, dynamic> tx) {
    return (tx['status'] ?? 'pending').toString().trim().toLowerCase();
  }

  String _titleFor(Map<String, dynamic> tx) {
    if (_isCredit(tx)) {
      final type = _typeOf(tx);
      if (type == 'agent_reward') return 'Agent Reward';
      if (type == 'admin_credit') return 'Admin Credit';
      final failure = (tx['failure_reason'] ?? '').toString().trim().toLowerCase();
      if (failure.contains('admin credit')) return 'Admin Credit';
      if (failure.contains('reward')) return 'Agent Reward';
      if (failure.contains('refund')) return 'Refund Credit';
      if (failure.contains('bonus')) return 'Bonus Credit';
      return 'Wallet Funding';
    }
    return switch (_typeOf(tx)) {
      'data' => 'Data Purchase',
      'airtime' => 'Airtime Purchase',
      'cable' => 'Cable Subscription',
      'electricity' => 'Electricity Payment',
      'exam' => 'Exam Pin Purchase',
      _ => 'Transaction',
    };
  }

  String _subtitleFor(Map<String, dynamic> tx) {
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

  DateTime? _createdAt(Map<String, dynamic> tx) {
    final raw = tx['created_at'];
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  String _formatDate(Map<String, dynamic> tx) {
    final date = _createdAt(tx);
    if (date == null) return '—';
    return DateFormat('d MMM • HH:mm').format(date.toLocal());
  }

  double _amountOf(Map<String, dynamic> tx) {
    final value = tx['amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _amountLabel(Map<String, dynamic> tx) {
    final amount = _amountOf(tx);
    final sign = _isCredit(tx) ? '+' : '-';
    return '$sign₦${amount.toStringAsFixed(2)}';
  }



  List<Map<String, dynamic>> _sortRecentTransactions(List<Map<String, dynamic>> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final ad = _createdAt(a)?.millisecondsSinceEpoch ?? 0;
      final bd = _createdAt(b)?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });
    return sorted;
  }

  List<Map<String, dynamic>> _recentActivity(List<Map<String, dynamic>> rows) {
    final sorted = _sortRecentTransactions(rows);
    return sorted.take(5).toList();
  }

  String _mostUsedService(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final tx in rows) {
      final type = _typeOf(tx);
      if (type == 'wallet_fund') continue;
      final label = switch (type) {
        'data' => 'Data',
        'airtime' => 'Airtime',
        'cable' => 'Cable',
        'electricity' => 'Bills',
        'exam' => 'Exam',
        _ => 'Other',
      };
      counts[label] = (counts[label] ?? 0) + 1;
    }
    if (counts.isEmpty) return '—';
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _spentLabel(List<Map<String, dynamic>> rows, {required int days}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final total = rows
        .where((tx) {
          if (_isCredit(tx)) return false;
          final created = _createdAt(tx);
          return created != null && !created.isBefore(start);
        })
        .fold<double>(0, (sum, tx) => sum + _amountOf(tx));
    return '₦${total.toStringAsFixed(2)}';
  }

  Color _activityColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s == 'success') return const Color(0xFF10B981);
    if (s == 'pending' || s == 'processing' || s == 'queued') {
      return const Color(0xFFF59E0B);
    }
    if (s == 'failed') return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54);
  }



  Future<void> _promptPhoneNumber() async {
    final session = context.read<SessionController>();
    final controller = TextEditingController(
      text: session.user?['phone_number'] ?? '',
    );
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add phone number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'e.g. 08123456789'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (phone == null || phone.trim().isEmpty) return;
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (normalizedPhone.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number.')),
      );
      return;
    }
    final token = session.token;
    if (token == null || token.isEmpty) return;
    try {
      final walletService = WalletService(token: token);
      setState(() {
        _walletFuture = walletService.getWallet();
        _accountsFuture = walletService.createBankAccounts(
          phoneNumber: normalizedPhone,
        );
      });
      await _accountsFuture;
      final auth = AuthService(token: token);
      final me = await auth.me();
      session.updateUser(me);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save phone number: $e')),
      );
    }
  }

  Future<void> _copyText(String value, String label) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _shareAccountDetails({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final text = _buildAccountShareText(
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
    final shortText = _buildShortAccountShareText(
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '${AppConfig.appName} funding account details',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: shortText));
      messenger.showSnackBar(
        const SnackBar(content: Text('Account details copied to clipboard.')),
      );
    }
  }

  String _buildAccountShareText({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) {
    return [
      'Fund my ${AppConfig.appName} wallet:',
      '',
      'Bank: $bankName',
      'Account Number: $accountNumber',
      'Account Name: $accountName',
      '',
      'Send money to this account and it will reflect automatically.',
    ].join('\n');
  }

  String _buildShortAccountShareText({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) {
    return [
      'Fund my ${AppConfig.appName} wallet',
      'Bank: $bankName',
      'Account Number: $accountNumber',
      'Account Name: $accountName',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final user = context.watch<SessionController>().user ?? {};
    final name = (user['full_name'] ?? user['name'] ?? '${AppConfig.appName} User')
        .toString()
        .trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark
        ? Colors.white.withValues(alpha: 0.84)
        : const Color(0xFF5B6B82);
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    final canPop = Navigator.of(context).canPop();

    Widget body = SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        displacement: 18,
        edgeOffset: 10,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            canPop ? 6 : 14,
            compact ? 16 : 20,
            canPop ? 80 : 110,
          ),
          children: [
            if (!canPop) ...[
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AxisPalette.gradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AxisShadows.premiumGlow,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dedicated accounts, live balance, instant credit',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  GlassCard(
                    padding: const EdgeInsets.all(4),
                    child: IconButton(
                      onPressed: _refresh,
                      tooltip: 'Refresh wallet',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 18),
            ],
            Container(
              padding: EdgeInsets.all(compact ? 14 : 18),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF0F1A2B), Color(0xFF16273D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEAF2FF), Color(0xFFD8E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
                ),
                boxShadow: AxisShadows.premiumGlow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.24)
                              : Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF2457F5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: heroText,
                                    fontWeight: FontWeight.w800,
                                ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 4 : 8),
                      GlassCard(
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          onPressed: _toggleBalanceVisibility,
                          icon: AnimatedSwitcher(
                            duration: AxisDurations.normal,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.88, end: 1.0)
                                      .animate(
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
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFF3F7FE),
                            padding: const EdgeInsets.all(10),
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _walletFuture,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;
                      var walletData = snapshot.data ??
                          ((isLoading || snapshot.hasError) &&
                                  _cachedWalletData != null
                              ? _cachedWalletData
                              : null);
                      if (walletData == null) {
                        final sessionUser = context.read<SessionController>().user;
                        if (sessionUser != null && sessionUser['wallet'] != null) {
                          walletData = sessionUser;
                        }
                      }
                      if (walletData == null) {
                        if (snapshot.hasError) {
                          return _DashboardBalanceError(onRefresh: _refresh);
                        }
                        return const _DashboardBalanceSkeleton();
                      }
                      final balance = _extractBalance(walletData);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Available balance',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: heroSoftText,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                _hideBalance ? 'Hidden' : 'Visible',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: heroSoftText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedBalanceText(
                            value: balance,
                            hideBalance: _hideBalance,
                            currencySymbol: '₦',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: heroText,
                                  fontWeight: FontWeight.w800,
                                ),
                            decimalStyle: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: heroText.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                            symbolStyle: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: heroText.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  Text(
                    'Money lands here automatically once your dedicated account is funded.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: heroSoftText,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            FutureBuilder<Map<String, dynamic>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final accountsData = snapshot.data ??
                    ((isLoading || snapshot.hasError) && _cachedAccountsData != null
                        ? _cachedAccountsData
                        : null);
                if (accountsData == null) {
                  if (snapshot.hasError) {
                    return _WalletAccountUnavailable(
                      message: 'Wallet details are temporarily unavailable.',
                      actionLabel: 'Refresh',
                      onAction: () => _refresh(),
                    );
                  }
                  return const _WalletAccountSkeleton();
                }

                final rawAccounts = (accountsData['accounts'] as List?) ?? const [];
                final isMeleData = BrandConfig.current.brand == AppBrand.meleData;
                final accounts = List<Map<String, dynamic>>.from(
                  rawAccounts.map((item) => Map<String, dynamic>.from(item as Map))
                ).where((acc) {
                  if (isMeleData) {
                    final name = (acc['bank_name'] ?? '').toString().toLowerCase();
                    return !name.contains('paga') && !name.contains('aspfiy');
                  }
                  return true;
                }).toList();

                // Sort: 1. PalmPay, 2. Moniepoint, 3. Safehaven, 4. Paystack, 5. 9PSB
                accounts.sort((a, b) {
                  final aName = (a['bank_name'] ?? '').toString().toLowerCase();
                  final bName = (b['bank_name'] ?? '').toString().toLowerCase();
                  int bankScore(String n) {
                    if (n.contains('palmpay')) return 1;
                    if (n.contains('moniepoint') || n.contains('monnify')) return 2;
                    if (n.contains('safehaven') || n.contains('safe haven')) return 3;
                    if (n.contains('paystack') || n.contains('titan')) return 4;
                    if (n.contains('9psb') || n.contains('9 payment')) return 5;
                    return 6;
                  }
                  return bankScore(aName).compareTo(bankScore(bName));
                });

                if (accounts.isEmpty) {
                  return _WalletAccountActivationCard(
                    onActivated: () => _refresh(),
                  );
                }

                final activeIndex = _activeAccountIndex.clamp(0, accounts.length - 1);
                final account = accounts[activeIndex];
                final isPlaceholder = account['isPlaceholder'] == true;
                final rawBank = (account['bank_name'] ?? 'Bank')
                    .toString()
                    .trim();
                final rawLower = rawBank.toLowerCase();
                final bankName = (rawLower.contains('9psb') || rawLower.contains('9 payment'))
                    ? '9 Payment Service Bank (9PSB)'
                    : (rawLower.contains('safehaven') || rawLower.contains('safe haven'))
                        ? 'Safehaven Microfinance Bank'
                        : (rawLower.contains('moniepoint') || rawLower.contains('monnify'))
                            ? 'Moniepoint Microfinance Bank'
                            : rawLower.contains('palmpay')
                                ? 'PalmPay'
                                : (rawLower.contains('titan') || rawLower.contains('paystack'))
                                    ? 'Paystack Titan'
                                    : (rawLower.contains('paga') || rawLower.contains('aspfiy') || rawLower.contains('aspify'))
                                        ? 'Paga'
                                        : rawLower.contains('wema')
                                            ? 'Wema Bank'
                                            : rawLower.contains('sterling')
                                                ? 'Sterling Bank'
                                                : rawBank;
                final accountNumber = (account['account_number'] ?? '')
                    .toString()
                    .trim();

                // Format accountHolderName nicely
                String rawName = (account['account_name'] ?? name).toString().trim();
                final prefixPattern = RegExp(
                  r'^(?:MMTECHGLOBE|${AppConfig.appName})(?:\s*[-\/:]\s*|\s+)?',
                  caseSensitive: false,
                );
                String cleanName = rawName.replaceFirst(prefixPattern, '').trim();
                if (cleanName.isEmpty) {
                  cleanName = rawName;
                }
                final accountName = 'MMTECHGLOBE / $cleanName';

                if (accountNumber.isEmpty) {
                  return _WalletAccountUnavailable(
                    message: 'Wallet details will appear shortly.',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                  );
                }

                final hasMonie = accounts.any((acc) => (acc['bank_name'] ?? '').toString().toLowerCase().contains('moniepoint'));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (accounts.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(accounts.length, (i) {
                            final isSelected = i == activeIndex;
                            final acc = accounts[i];
                            final bName = _getShortBankName((acc['bank_name'] ?? '').toString());
                            return Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _activeAccountIndex = i);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.account_balance,
                                        size: 13,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    _BankCard(
                      bankName: bankName.isEmpty ? 'Paystack-Titan' : bankName,
                      rawBankName: rawBank,
                      accountNumber: accountNumber,
                      accountName: accountName.isEmpty ? name : accountName,
                      isPlaceholder: isPlaceholder,
                      onCopyAccount: isPlaceholder
                          ? () {}
                          : () => _copyText(accountNumber, 'Account number'),
                      onShareAccount: isPlaceholder
                          ? null
                          : () => _shareAccountDetails(
                                bankName: bankName.isEmpty ? 'Paystack-Titan' : bankName,
                                accountNumber: accountNumber,
                                accountName: accountName.isEmpty ? name : accountName,
                              ),
                    ),
                    if (!hasMonie) ...[
                      const SizedBox(height: 16),
                      _WalletAccountActivationCard(
                        onActivated: () => _refresh(),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (BrandConfig.current.brand == AppBrand.meleData)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openScreen(const TransferScreen()),
                      icon: const Icon(Icons.account_balance_rounded, size: 18),
                      label: const Text(
                        'Withdraw to Bank',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openScreen(const TransferScreen()),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Send to User',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: () => _openScreen(const TransferScreen()),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Send to User (P2P Transfer)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    widget.onNavigateTab?.call(2);
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _RecentActivitySkeleton();
                }
                final rows = _recentActivity(snapshot.data ?? const []);
                if (rows.isEmpty) {
                  return GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent activity yet.',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Transfer to your account and purchases will appear here automatically.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: muted,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: rows
                      .take(4)
                      .map(
                        (tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecentActivityRow(
                            icon: switch (_typeOf(tx)) {
                              'data' => Icons.wifi_rounded,
                              'airtime' => Icons.phone_iphone_rounded,
                              'cable' => Icons.live_tv_rounded,
                              'electricity' => Icons.flash_on_rounded,
                              'wallet_fund' => Icons.account_balance_wallet_rounded,
                              _ => Icons.receipt_long_rounded,
                            },
                            title: _titleFor(tx),
                            subtitle: _subtitleFor(tx),
                            amount: _amountLabel(tx),
                            date: _formatDate(tx),
                            status: _statusOf(tx),
                            statusColor: _activityColor(_statusOf(tx), context),
                            amountColor: _isCredit(tx)
                                ? const Color(0xFF10B981)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Wallet'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh wallet',
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: body,
      );
    }
    return body;
  }
}

class _WalletActionPill extends StatelessWidget {
  const _WalletActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final surface = Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.95 : 0.88,);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.58,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08,),
              ),
              boxShadow: AxisShadows.softGlow,
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 28 : 32,
                  height: compact ? 28 : 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: compact ? 16 : 18, color: accent),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.08,
                        ),
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    return Container(
      padding: EdgeInsets.all(compact ? 11 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.94 : 0.9,),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08,),
        ),
        boxShadow: AxisShadows.softGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54,),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58,),
                ),
          ),
        ],
      ),
    );
  }
}

class _WalletInsightsSkeleton extends StatelessWidget {
  const _WalletInsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    final tiles = List.generate(4, (index) => index);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final extent = _walletInsightExtentForWidth(width);
        final columns = _walletInsightColumnsForWidth(width);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _SkeletonBox(width: 30, height: 30, radius: 10),
                      Spacer(),
                      _SkeletonBox(width: 8, height: 8, radius: 999),
                    ],
                  ),
                  _SkeletonBox(width: 84, height: 10, radius: 999),
                  _SkeletonBox(width: 96, height: 18, radius: 999),
                  _SkeletonBox(width: 72, height: 10, radius: 999),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.amountColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final String status;
  final Color statusColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.94 : 0.9,),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.10 : 0.08,),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: statusColor, size: 20),
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
                            letterSpacing: -0.08,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.60),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.52),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          letterSpacing: -0.06,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.16 : 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivitySkeleton extends StatelessWidget {
  const _RecentActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _RecentActivitySkeletonRow(),
        ),
      ),
    );
  }
}

class _RecentActivitySkeletonRow extends StatelessWidget {
  const _RecentActivitySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
        ),
      ),
      child: const Row(
        children: [
          _SkeletonBox(width: 42, height: 42, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 120, height: 12, radius: 999),
                SizedBox(height: 8),
                _SkeletonBox(width: 92, height: 10, radius: 999),
                SizedBox(height: 8),
                _SkeletonBox(width: 70, height: 10, radius: 999),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SkeletonBox(width: 76, height: 12, radius: 999),
              SizedBox(height: 10),
              _SkeletonBox(width: 56, height: 18, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.bankName,
    required this.rawBankName,
    required this.accountNumber,
    required this.accountName,
    required this.onCopyAccount,
    this.onShareAccount,
    this.isPlaceholder = false,
  });

  final String bankName;
  final String rawBankName;
  final String accountNumber;
  final String accountName;
  final VoidCallback onCopyAccount;
  final VoidCallback? onShareAccount;
  final bool isPlaceholder;

  String _formatAccountNumberDisplay(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), '').trim();
    if (clean.length == 10) {
      return '${clean.substring(0, 3)}  ${clean.substring(3, 6)}  ${clean.substring(6)}';
    }
    return clean;
  }

  String _getBankAppSearchHint(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('safehaven') || lower.contains('safe haven')) {
      return 'In your bank app, select "Safe Haven MFB"';
    }
    if (lower.contains('9psb') || lower.contains('9 payment')) {
      return 'In your bank app, select "9PSB" or "9 Payment Service Bank"';
    }
    if (lower.contains('moniepoint') || lower.contains('monnify')) {
      return 'In your bank app, select "Moniepoint MFB"';
    }
    if (lower.contains('palmpay')) {
      return 'In your bank app, select "PalmPay"';
    }
    if (lower.contains('titan') || lower.contains('paystack')) {
      return 'In your bank app, select "Paystack-Titan" or "Titan Trust"';
    }
    return 'In your bank app, select "$raw"';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).height < 760;
    final displayNumber = _formatAccountNumberDisplay(accountNumber);
    final searchHint = _getBankAppSearchHint(rawBankName.isNotEmpty ? rawBankName : bankName);

    // Human-crafted, premium fintech theme (clean dark obsidian or crisp light card)
    final cardBgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header: Bank Icon + Full Bank Name + Active Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DEPOSIT BANK',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bankName,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontSize: compact ? 15 : 16.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isPlaceholder
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPlaceholder ? const Color(0xFFD97706) : const Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPlaceholder ? 'PENDING' : 'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isPlaceholder ? const Color(0xFFD97706) : const Color(0xFF059669),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Search Hint Pill for local bank apps
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    searchHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 16),

          if (isPlaceholder) ...[
            Center(
              child: Text(
                'PENDING ACTIVATION',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  fontSize: 14,
                ),
              ),
            ),
          ] else ...[
            // Account Number Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACCOUNT NUMBER',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Tap number to copy',
                  style: TextStyle(
                    color: const Color(0xFF2563EB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onCopyAccount,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayNumber.isEmpty ? '—' : displayNumber,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 22 : 24,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Account Name Section
            Text(
              'ACCOUNT NAME',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              accountName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                letterSpacing: 0.1,
              ),
            ),

            const SizedBox(height: 14),

            // Bottom Instant Credit Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Instant Automated Credit (0 - 30 seconds)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (onShareAccount != null) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: onShareAccount,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share account details'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WalletAccountSkeleton extends StatelessWidget {
  const _WalletAccountSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE8EEF9);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletAccountActivationCard extends StatefulWidget {
  final VoidCallback onActivated;

  const _WalletAccountActivationCard({required this.onActivated});

  @override
  State<_WalletAccountActivationCard> createState() => _WalletAccountActivationCardState();
}

class _WalletAccountActivationCardState extends State<_WalletAccountActivationCard> {
  String _option = 'bvn'; // 'bvn' or 'nin'
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _inputCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    if (value.length != 11) {
      setState(() {
        _error = 'Enter a valid 11-digit ${_option.toUpperCase()}.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null || token.isEmpty) {
        throw Exception('User is not authenticated.');
      }

      final walletService = WalletService(token: token);
      await walletService.createBankAccounts(
        bvn: _option == 'bvn' ? value : null,
        nin: _option == 'nin' ? value : null,
      );

      // Successfully generated
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dedicated funding accounts generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onActivated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Activate Dedicated Funding Accounts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Generate Wema, Sterling, or Moniepoint virtual accounts linked to your wallet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Segmented Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _loading
                        ? null
                        : () {
                            setState(() {
                              _option = 'bvn';
                              _inputCtrl.clear();
                              _error = null;
                            });
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _option == 'bvn'
                            ? theme.colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _option == 'bvn'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'BVN Option',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: _option == 'bvn'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _option == 'bvn'
                                ? theme.colorScheme.primary
                                : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _loading
                        ? null
                        : () {
                            setState(() {
                              _option = 'nin';
                              _inputCtrl.clear();
                              _error = null;
                            });
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _option == 'nin'
                            ? theme.colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _option == 'nin'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'NIN Option',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: _option == 'nin'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _option == 'nin'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Number input field
          TextField(
            controller: _inputCtrl,
            keyboardType: TextInputType.number,
            maxLength: 11,
            enabled: !_loading,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: _option == 'bvn'
                  ? 'Enter 11-digit BVN'
                  : 'Enter 11-digit NIN',
              labelText: _option == 'bvn' ? 'BVN' : 'NIN',
              counterText: '',
              prefixIcon: Icon(
                _option == 'bvn'
                    ? Icons.security_rounded
                    : Icons.badge_rounded,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
                disabledForegroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Activate Now',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppConfig.appName} does NOT store or keep your BVN or NIN. This identity verification is securely routed directly to our central CBN-licensed payment partner (Monnify) to automatically generate your personalized funding accounts.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletAccountUnavailable extends StatelessWidget {
  const _WalletAccountUnavailable({
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
            'Your dedicated account will show up here as soon as it is ready.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: actionLabel,
              icon: Icons.refresh_rounded,
              onPressed: onAction,
            ),
          ),
        ],
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wallet details are temporarily unavailable.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
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


