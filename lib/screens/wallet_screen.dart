import 'dart:async';
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
import 'airtime_screen.dart';
import 'data_screen.dart';
import 'electricity_screen.dart';
import 'profile_screen.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

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
            dashboardKey != _activeDashboardKey)) {
      if (dashboardKey != _activeDashboardKey) {
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

  void _reloadWallet(String token, String dashboardKey) {
    final service = WalletService(token: token);
    _walletFuture = service.getWallet();
    _accountsFuture = service.getBankAccounts();
    _transactionsFuture = _loadRecentTransactions(token);
    _walletFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, wallet: data));
    }).catchError((_) {});
    _accountsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      unawaited(DashboardSnapshotCache.save(dashboardKey, accounts: data));
    }).catchError((_) {});
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
    setState(() => _reloadWallet(token, dashboardKey));
    await Future.wait([
      _walletFuture!,
      _accountsFuture!,
      _transactionsFuture ?? Future.value(const <Map<String, dynamic>>[]),
    ]);
  }

  Future<void> _openScreen(Widget screen) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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

  bool _isCredit(Map<String, dynamic> tx) => _typeOf(tx) == 'wallet_fund';

  String _typeOf(Map<String, dynamic> tx) {
    return (tx['tx_type'] ?? 'transaction').toString().trim().toLowerCase();
  }

  String _statusOf(Map<String, dynamic> tx) {
    return (tx['status'] ?? 'pending').toString().trim().toLowerCase();
  }

  String _titleFor(Map<String, dynamic> tx) {
    return switch (_typeOf(tx)) {
      'data' => 'Data Purchase',
      'wallet_fund' => 'Wallet Funding',
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
          subject: 'AxisVTU funding account details',
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
      'Fund my AxisVTU wallet:',
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
      'Fund my AxisVTU wallet',
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
    final name = (user['full_name'] ?? user['name'] ?? 'AxisVTU User')
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        displacement: 18,
        edgeOffset: 10,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            14,
            compact ? 16 : 20,
            28,
          ),
          children: [
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.18),
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
                      final walletData = snapshot.data ??
                          ((isLoading || snapshot.hasError) &&
                                  _cachedWalletData != null
                              ? _cachedWalletData
                              : null);
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
                          AnimatedSwitcher(
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
                                    begin: const Offset(0, 0.08),
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
                                    key: const ValueKey('hidden_balance'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: heroText,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.4,
                                        ),
                                  )
                                : _AnimatedBalance(
                                    key: const ValueKey('visible_balance'),
                                    value: balance,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: heroText,
                                          fontWeight: FontWeight.w800,
                                        ),
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

                final accounts = (accountsData['accounts'] as List?) ?? const [];
                final requiresKyc = accountsData['requires_kyc'] == true;
                if (accounts.isEmpty) {
                  return _WalletAccountUnavailable(
                    message: requiresKyc
                        ? 'Finish verification to unlock your dedicated account.'
                        : 'Wallet details will appear shortly.',
                    actionLabel: requiresKyc ? 'View Profile' : 'Try again',
                    onAction: requiresKyc
                        ? () {
                            if (widget.onNavigateTab != null) {
                              widget.onNavigateTab!(3);
                            } else {
                              _openScreen(const ProfileScreen());
                            }
                          }
                        : () => _refresh(),
                  );
                }

                final account = accounts.first is Map
                    ? Map<String, dynamic>.from(accounts.first as Map)
                    : <String, dynamic>{};
                final bankName = (account['bank_name'] ?? 'Paystack-Titan')
                    .toString()
                    .trim();
                final accountNumber = (account['account_number'] ?? '')
                    .toString()
                    .trim();
                final accountName = (account['account_name'] ?? name)
                    .toString()
                    .trim();
                if (accountNumber.isEmpty) {
                  return _WalletAccountUnavailable(
                    message: 'Wallet details will appear shortly.',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 380;
                        final actions = [
                          _WalletActionPill(
                            icon: Icons.copy_rounded,
                            label: 'Copy Account',
                            accent: const Color(0xFF3B82F6),
                            onTap: () => _copyText(
                              accountNumber,
                              'Account number',
                            ),
                          ),
                          _WalletActionPill(
                            icon: Icons.wifi_rounded,
                            label: 'Buy Data',
                            accent: const Color(0xFF3B82F6),
                            onTap: () => _openScreen(const DataScreen()),
                          ),
                          _WalletActionPill(
                            icon: Icons.phone_iphone_rounded,
                            label: 'Airtime',
                            accent: const Color(0xFF10B981),
                            onTap: () => _openScreen(const AirtimeScreen()),
                          ),
                          _WalletActionPill(
                            icon: Icons.flash_on_rounded,
                            label: 'Bills',
                            accent: const Color(0xFFF59E0B),
                            onTap: () => _openScreen(const ElectricityScreen()),
                          ),
                        ];
                        if (narrow) {
                          return Column(
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                actions[i],
                              ],
                            ],
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(width: (constraints.maxWidth - 10) / 2, child: actions[0]),
                            SizedBox(width: (constraints.maxWidth - 10) / 2, child: actions[1]),
                            SizedBox(width: (constraints.maxWidth - 10) / 2, child: actions[2]),
                            SizedBox(width: (constraints.maxWidth - 10) / 2, child: actions[3]),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    _BankCard(
                      bankName: bankName.isEmpty ? 'Paystack-Titan' : bankName,
                      accountNumber: accountNumber,
                      accountName: accountName.isEmpty ? name : accountName,
                      onCopyAccount: () =>
                          _copyText(accountNumber, 'Account number'),
                      onShareAccount: () => _shareAccountDetails(
                        bankName: bankName.isEmpty ? 'Paystack-Titan' : bankName,
                        accountNumber: accountNumber,
                        accountName: accountName.isEmpty ? name : accountName,
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: compact ? 14 : 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Wallet insights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                  ),
                ),
                Text(
                  'Live overview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _WalletInsightsSkeleton();
                }
                final rows = _sortRecentTransactions(snapshot.data ?? const []);
                final totalSpentToday = _spentLabel(rows, days: 1);
                final totalSpentWeek = _spentLabel(rows, days: 7);
                final transactionCount = rows.length.toString();
                final mostUsed = _mostUsedService(rows);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final useList = width < 430;
                    if (useList) {
                      return Column(
                        children: [
                          _InsightCard(
                            label: 'Spent today',
                            value: totalSpentToday,
                            subtitle: 'Across purchases',
                            icon: Icons.today_rounded,
                            accent: const Color(0xFF3B82F6),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          _InsightCard(
                            label: 'Spent this week',
                            value: totalSpentWeek,
                            subtitle: 'Rolling 7 days',
                            icon: Icons.date_range_rounded,
                            accent: const Color(0xFF10B981),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          _InsightCard(
                            label: 'Transactions',
                            value: transactionCount,
                            subtitle: 'Recorded here',
                            icon: Icons.receipt_long_rounded,
                            accent: const Color(0xFFF59E0B),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          _InsightCard(
                            label: 'Most used',
                            value: mostUsed,
                            subtitle: 'Top service',
                            icon: Icons.auto_graph_rounded,
                            accent: const Color(0xFF8B5CF6),
                          ),
                        ],
                      );
                    }
                    final extent = _walletInsightExtentForWidth(width);
                    final columns = _walletInsightColumnsForWidth(width);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: extent,
                      ),
                      itemBuilder: (context, index) {
                        return switch (index) {
                          0 => _InsightCard(
                              label: 'Spent today',
                              value: totalSpentToday,
                              subtitle: 'Across purchases',
                              icon: Icons.today_rounded,
                              accent: const Color(0xFF3B82F6),
                            ),
                          1 => _InsightCard(
                              label: 'Spent this week',
                              value: totalSpentWeek,
                              subtitle: 'Rolling 7 days',
                              icon: Icons.date_range_rounded,
                              accent: const Color(0xFF10B981),
                            ),
                          2 => _InsightCard(
                              label: 'Transactions',
                              value: transactionCount,
                              subtitle: 'Recorded here',
                              icon: Icons.receipt_long_rounded,
                              accent: const Color(0xFFF59E0B),
                            ),
                          _ => _InsightCard(
                              label: 'Most used',
                              value: mostUsed,
                              subtitle: 'Top service',
                              icon: Icons.auto_graph_rounded,
                              accent: const Color(0xFF8B5CF6),
                            ),
                        };
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
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
                  onPressed: () => widget.onNavigateTab?.call(2),
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
    final surface = Theme.of(context).colorScheme.surface.withValues(
          alpha: isDark ? 0.95 : 0.88,
        );

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
                color: Theme.of(context).colorScheme.outline.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
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
        color: Theme.of(context).colorScheme.surface.withValues(
              alpha: isDark ? 0.94 : 0.9,
            ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: isDark ? 0.12 : 0.08,
              ),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.58,
                      ),
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
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: isDark ? 0.94 : 0.9,
                ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(
                    alpha: isDark ? 0.10 : 0.08,
                  ),
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
    required this.accountNumber,
    required this.accountName,
    required this.onCopyAccount,
    this.onShareAccount,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;
  final VoidCallback onCopyAccount;
  final VoidCallback? onShareAccount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).height < 760;
    final displayNumber = _formatAccountNumber(accountNumber);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF101A2A), Color(0xFF162338)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFF7FAFF), Color(0xFFEEF4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: isDark ? 0.10 : 0.08,
              ),
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
                  borderRadius: BorderRadius.circular(11),
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
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
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
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        displayNumber.isEmpty ? '—' : displayNumber,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                              letterSpacing: compact ? 2.8 : 4.4,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              height: 1.1,
                              fontSize: compact ? 28 : null,
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: isDark ? 0.14 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: isDark ? 0.12 : 0.08),
                    ),
                  ),
                  child: IconButton(
                    onPressed: onCopyAccount,
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    tooltip: 'Copy account number',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.all(compact ? 8 : 10),
                    constraints: BoxConstraints.tightFor(
                      width: compact ? 34 : 40,
                      height: compact ? 34 : 40,
                    ),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 6 : 12),
          Text(
            accountName,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.05,
                ),
          ),
          if (onShareAccount != null) ...[
            SizedBox(height: compact ? 6 : 8),
            Center(
              child: TextButton.icon(
                onPressed: onShareAccount,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text(compact ? 'Share' : 'Share details'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 14,
                    vertical: compact ? 6 : 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          SizedBox(height: compact ? 6 : 10),
          Text(
            'Transfer to this account to fund your wallet.',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.58),
                  height: 1.25,
                ),
          ),
        ],
      ),
    );
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

class _AnimatedBalance extends StatefulWidget {
  const _AnimatedBalance({
    super.key,
    required this.value,
    required this.style,
  });

  final double value;
  final TextStyle? style;

  @override
  State<_AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends State<_AnimatedBalance> {
  double _previous = 0;

  @override
  void didUpdateWidget(covariant _AnimatedBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previous, end: widget.value),
      duration: AxisDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text('₦${value.toStringAsFixed(2)}', style: widget.style);
      },
    );
  }
}


