import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/dashboard_snapshot_cache.dart';
import '../services/notifications_service.dart';
import '../services/transactions_service.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../utils/fast_route.dart';
import '../widgets/glass_card.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/fund_wallet_sheet.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/primary_button.dart';
import '../widgets/startup_popup_dialog.dart';
import 'notification_center_screen.dart';
import 'promo_screen.dart';
import 'airtime_screen.dart';
import 'cable_screen.dart';
import 'data_screen.dart';
import 'electricity_screen.dart';
import 'exam_screen.dart';
import 'history_screen.dart';
import 'transfer_screen.dart';
import 'referral_screen.dart';
import '../services/purchase_auth_service.dart';
import '../services/transaction_pin_service.dart';
import 'wallet_screen.dart';
import '../widgets/concentric_circles_bg.dart';
import '../services/agent_service.dart';
import '../models/agent_models.dart';
import '../widgets/mele_data_loader.dart';


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
  List<Map<String, dynamic>>? _announcements;

  static bool _hasShownStartupPopup = false;

  Set<String> _dismissedAnnouncementIds = {};
  int _activeAccountIndex = 0;
  String _activeToken = '';
  String _activeDashboardKey = '';
  bool _hideBalance = false;
  bool _showingUpgradeDialog = false;
  int? _activeBalanceTick;
  Timer? _refreshTimer;
  List<RewardCampaign> _activeCampaigns = [];
  bool _dismissedUpdateBanner = false;
  String _dismissedVersionStr = '';
  
  double? _previousBalance;
  double _balanceDiff = 0.0;
  bool _showBalanceDiff = false;
  Timer? _balanceDiffTimer;
  bool _readyForLiveUpdates = false;

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final session = context.read<SessionController>();
      final token = (session.token ?? '').trim();
      final dashboardKey =
          DashboardSnapshotCache.identityFromUser(session.user) ?? token;
      if (token.isNotEmpty && dashboardKey.isNotEmpty) {
        _reloadDashboard(token, dashboardKey);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _readyForLiveUpdates = true);
    });
    _loadBalancePreference();
    _loadDismissedAnnouncements();
    _startRefreshTimer();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _initialSecurityCheck();
        final session = context.read<SessionController>();
        if (session.isAuthenticated && session.user == null) {
          session.syncProfileIfNeeded();
        }
      }
    });
  }

  Future<void> _loadDismissedAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dismissed_announcements') ?? [];
    final dismissedVer = prefs.getString('dismissed_app_version') ?? '';
    if (mounted) {
      setState(() {
        _dismissedAnnouncementIds = list.toSet();
        _dismissedVersionStr = dismissedVer;
      });
    }
  }

  Future<void> _dismissAnnouncement(String id) async {
    setState(() {
      _dismissedAnnouncementIds.add(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_announcements', _dismissedAnnouncementIds.toList());
  }

  void _checkStartupPopup() {
    if (_hasShownStartupPopup || _announcements == null || _announcements!.isEmpty) return;
    try {
      final popup = _announcements!.firstWhere(
        (a) => a['is_popup'] == true && !_dismissedAnnouncementIds.contains(a['id']?.toString()),
        orElse: () => {},
      );
      if (popup.isNotEmpty) {
        _hasShownStartupPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            StartupPopupDialog.show(context, popup).then((_) {
              // Optionally mark as dismissed if we want 'once ever' behavior
              // But user asked for option 1 (once per session), so we don't save to prefs.
            });
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissUpdateBanner(String version) async {
    setState(() {
      _dismissedUpdateBanner = true;
      _dismissedVersionStr = version;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dismissed_app_version', version);
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
        await PurchaseAuthService.setupPin(
          context: context,
          reason: 'account security',
          pinLength: status.pinLength,
        );
      }
    } catch (_) {
      // Silently fail to avoid blocking the home screen
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final token = (session.token ?? '').trim();
    final balanceTick = session.balanceRefreshTick;
    final dashboardKey =
        DashboardSnapshotCache.identityFromUser(session.user) ?? token;

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
            _transactionsFuture == null ||
            dashboardKey != _activeDashboardKey ||
            tickChanged)) {
      if (_activeDashboardKey.isNotEmpty && dashboardKey != _activeDashboardKey) {
        _cachedWalletData = null;
        _cachedAccountsData = null;
        _cachedTransactionsData = null;
      }
      _activeDashboardKey = dashboardKey;
      _reloadDashboard(token, dashboardKey);
      
      // Load from high-speed in-memory static cache synchronously on the very first frame to prevent UI flickering!
      final memCached = DashboardSnapshotCache.loadSync(dashboardKey);
      if (memCached != null) {
        _cachedWalletData = _asMap(memCached['wallet']);
        _cachedAccountsData = _asMap(memCached['accounts']);
        final memTransactions = memCached['transactions'];
        if (memTransactions is List) {
          _cachedTransactionsData = memTransactions
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
        }
        final memAnnouncements = memCached['announcements'];
        if (memAnnouncements is List) {
          _announcements = memAnnouncements
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
          _checkStartupPopup();
        }
      } else {
        _loadCachedDashboard(dashboardKey);
      }
      
      _activeToken = token;
    }

    final user = session.user ?? {};
    final role = (user['role'] ?? 'Member').toString().trim().toLowerCase();
    final upgradeSeen = user['agent_upgrade_seen'] ?? true;

    if (role == 'reseller' && !upgradeSeen && !_showingUpgradeDialog) {
      _showingUpgradeDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAgentUpgradeDialog(user);
      });
    }
  }

  Future<void> _loadBalancePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideBalance = prefs.getBool(_hideBalanceKey) ?? false;
    });
  }

  Future<void> _acknowledgeUpgrade() async {
    try {
      await context.read<SessionController>().acknowledgeAgentUpgrade();
    } catch (_) {}
  }

  void _showAgentUpgradeDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        
        return PopScope(
          canPop: false, // Hard lock dismissal
          child: Dialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 24,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Congratulations! 🎉',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'On hitting 50GB+ sales, your account has been upgraded to an Agent account.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Agent Benefits in MELE DATA:',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _benefitItem(
                    icon: Icons.sell_rounded,
                    title: 'Cheaper Pricing Rates',
                    description: 'Enjoy cheaper pricing rates than normal users (e.g. if a normal user gets data bundle for ₦450, you get it at the rate of ₦400). That’s a ₦50 difference!',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _benefitItem(
                    icon: Icons.group_add_rounded,
                    title: 'Register an Agent',
                    description: 'Onboard POS agents who sell mobile data. Once an agent becomes active (sells 50GB+), you earn ₦2,000 per agent. There’s no limit, earn as much as you want.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _benefitItem(
                    icon: Icons.share_rounded,
                    title: 'Referrals',
                    description: 'Invite someone to join MELE DATA using your referral code. Every time they buy data, you earn a commission automatically.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _benefitItem(
                    icon: Icons.local_offer_rounded,
                    title: 'Offers',
                    description: 'Hit milestones and unlock special rewards. Once you claim an offer, the reward reflects instantly in your earnings balance.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: PrimaryButton(
                      label: "Let's Go!",
                      onPressed: () async {
                        Navigator.pop(context);
                        await _acknowledgeUpgrade();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _benefitItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      final cachedAnnouncements = cached?['announcements'];
      if (cachedAnnouncements is List) {
        _announcements = cachedAnnouncements
            .whereType<Map>()
            .map(
              (item) => item.map(
                (k, v) => MapEntry(k.toString(), v),
              ),
            )
            .toList();
        _checkStartupPopup();
      }
    });
  }

  void _showAccountActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _MELEDATAAccountActivationDialog(
          onActivated: () {
            if (!mounted) return;
            final token = (context.read<SessionController>().token ?? '').trim();
            if (token.isEmpty) return;
            final dashboardKey = DashboardSnapshotCache.identityFromUser(context.read<SessionController>().user) ?? token;
            _reloadDashboard(token, dashboardKey);
          },
        );
      },
    );
  }

  void _reloadDashboard(String token, String dashboardKey) {
    final service = WalletService(token: token);
    final txService = TransactionsService(token: token);
    _walletFuture = service.getWallet(forceRefresh: true);
    _accountsFuture = service.getBankAccounts();
    _transactionsFuture = txService.getTransactions();
    _notificationsFuture = _loadNotifications(token);
    _walletFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      setState(() {
        _cachedWalletData = _asMap(data);
      });
      unawaited(DashboardSnapshotCache.save(dashboardKey, wallet: data));
    }).catchError((e) {
      if (mounted) _handleAuthError(e);
    });
    _accountsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      setState(() {
        _cachedAccountsData = _asMap(data);
      });
      unawaited(DashboardSnapshotCache.save(dashboardKey, accounts: data));
    }).catchError((e) {
      if (mounted) _handleAuthError(e);
    });
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
    }).catchError((e) {
      if (mounted) _handleAuthError(e);
    });
    _notificationsFuture!.then((data) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      setState(() {
        _announcements = data;
      });
      _checkStartupPopup();
      unawaited(
        DashboardSnapshotCache.save(
          dashboardKey,
          announcements: data,
        ),
      );
    }).catchError((_) {});

    final agentService = AgentService(token: token);
    agentService.getActiveCampaigns().then((camps) {
      if (!mounted || dashboardKey != _activeDashboardKey) return;
      setState(() {
        _activeCampaigns = camps;
      });
    }).catchError((_) {});
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
    try {
      await Future.wait([
        _walletFuture!,
        _accountsFuture!,
        _transactionsFuture ?? Future.value(<dynamic>[]),
        _notificationsFuture ?? Future.value(<Map<String, dynamic>>[]),
      ]);
    } catch (e) {
      if (mounted) {
        _handleAuthError(e);
      }
    }
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

  void _openReceipt(Map<String, dynamic> tx) {
    final status = _txStatusOf(tx);
    final title = _txTitleFor(tx);
    final isCredit = _txIsCredit(tx);
    
    // Build receipt fields nicely
    final meta = tx['meta'] is Map ? (tx['meta'] as Map).map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    
    String getFirst(Iterable<dynamic?> values, {String fallback = '—'}) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }
    
    final recipient = getFirst([
      meta['recipient_phone'],
      meta['phone_number'],
      meta['meter_number'],
      meta['smartcard_number'],
      tx['recipient_phone'],
      tx['phone_number'],
      tx['meter_number'],
      tx['smartcard_number'],
    ]);
    
    final network = getFirst([
      tx['network'],
      meta['network'],
      meta['provider'],
      tx['provider'],
    ]);
    
    final plan = getFirst([
      meta['plan'],
      meta['plan_name'],
      meta['bundle'],
      meta['package_name'],
      meta['package_code'],
      tx['plan'],
      tx['plan_name'],
      tx['bundle'],
      tx['package_code'],
      tx['service'],
    ], fallback: title);
    
    final reference = getFirst([
      tx['reference'],
      tx['external_reference'],
      meta['reference'],
      meta['external_reference'],
      tx['id']?.toString(),
    ]);
    
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';
    
    final fields = <ReceiptField>[
      ReceiptField(label: 'Time', value: _txDateLabel(tx)),
      ReceiptField(label: 'Sender Name', value: userName),
      if (recipient != '—') ReceiptField(label: 'Recipient', value: recipient),
      if (network != '—') ReceiptField(label: 'Network', value: network.toUpperCase()),
      if (plan != title && plan != '—') ReceiptField(label: 'Plan', value: plan),
      if (_txTypeOf(tx) != 'data')
        ReceiptField(label: 'Amount', value: _txAmountLabel(tx).replaceAll('+', '').replaceAll('-', '')),
      ReceiptField(label: 'Reference', value: reference),
    ];
    
    final subtitleParts = <String>[];
    if (recipient != '—') subtitleParts.add(recipient);
    if (network != '—') subtitleParts.add(network.toUpperCase());
    final subtitle = subtitleParts.isEmpty ? 'Transaction Receipt' : subtitleParts.join(' • ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: isCredit ? 'Credit Added' : title,
        subtitle: subtitle,
        fields: fields,
      ),
    );
  }

  Future<void> _openScreen(Widget screen) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(FastRoute(page: screen));
  }

  Future<void> _openNotificationsCenter() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      FastRoute(
        page: NotificationCenterScreen(
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  Widget _buildAnnouncementBanner(Map<String, dynamic> announcement) {
    final id = announcement['id']?.toString() ?? announcement['message']?.toString() ?? '';
    final title = announcement['title']?.toString() ?? 'Announcement';
    final message = (announcement['message'] ?? announcement['text'] ?? '').toString();
    
    if (message.isEmpty || _dismissedAnnouncementIds.contains(id)) {
      return const SizedBox.shrink();
    }

    final buttonLabel = announcement['button_label']?.toString() ?? '';
    final buttonLink = announcement['button_link']?.toString() ?? '';
    final hasButton = buttonLabel.isNotEmpty && buttonLink.isNotEmpty;

    final level = (announcement['level'] ?? 'info').toString().toLowerCase();

    // Default color maps for 'info'
    List<Color> gradientColors = const [
      Color(0xFF60A5FA), // Blue 400
      Color(0xFF3B82F6), // Blue 500
    ];
    Color textPrimaryColor = const Color(0xFF1E3A8A); // Blue 900
    Color textSecondaryColor = const Color(0xFF1E40AF); // Blue 800
    IconData iconData = Icons.info_outline_rounded;
    Color iconColor = const Color(0xFF1E3A8A);
    Color closeBtnBg = const Color(0xFF1E3A8A).withOpacity(0.08);
    Color shadowColor = const Color(0xFF3B82F6).withOpacity(0.18);

    if (level == 'success') {
      gradientColors = const [
        Color(0xFF34D399), // Emerald 400
        Color(0xFF10B981), // Emerald 500
      ];
      textPrimaryColor = const Color(0xFF064E3B); // Emerald 950
      textSecondaryColor = const Color(0xFF065F46); // Emerald 900
      iconData = Icons.check_circle_outline_rounded;
      iconColor = const Color(0xFF064E3B);
      closeBtnBg = const Color(0xFF064E3B).withOpacity(0.08);
      shadowColor = const Color(0xFF10B981).withOpacity(0.18);
    } else if (level == 'warning') {
      gradientColors = const [
        Color(0xFFFBBF24), // Amber 400
        Color(0xFFF59E0B), // Amber 500
      ];
      textPrimaryColor = const Color(0xFF451A03); // Amber 950
      textSecondaryColor = const Color(0xFF78350F); // Amber 900
      iconData = Icons.warning_amber_rounded;
      iconColor = const Color(0xFF451A03);
      closeBtnBg = const Color(0xFF451A03).withOpacity(0.08);
      shadowColor = const Color(0xFFF59E0B).withOpacity(0.18);
    } else if (level == 'critical') {
      gradientColors = const [
        Color(0xFFF87171), // Red 400
        Color(0xFFEF4444), // Red 500
      ];
      textPrimaryColor = const Color(0xFF7F1D1D); // Red 950
      textSecondaryColor = const Color(0xFF991B1B); // Red 900
      iconData = Icons.gpp_bad_outlined;
      iconColor = const Color(0xFF7F1D1D);
      closeBtnBg = const Color(0xFF7F1D1D).withOpacity(0.08);
      shadowColor = const Color(0xFFEF4444).withOpacity(0.18);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!hasButton) ...[
              Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty && title != 'Announcement')
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  if (title.isNotEmpty && title != 'Announcement') const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (hasButton) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final uri = Uri.tryParse(buttonLink);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: textPrimaryColor.withOpacity(0.15),
                  foregroundColor: textPrimaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _dismissAnnouncement(id),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: closeBtnBg,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: iconColor,
                  size: 16,
                ),
              ),
            ),
          ],
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

  Widget _buildActionPill(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required bool primary, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary 
              ? Theme.of(context).colorScheme.primary 
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          boxShadow: primary ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: primary ? Colors.white : (isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: primary ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override

  Widget _buildTopServiceItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x08000000),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

    Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final user = context.watch<SessionController>().user ?? {};
    final name = (user['full_name'] ?? user['name'] ?? 'MELE DATA User')
        .toString()
        .trim();
    final role = (user['role'] ?? 'Member').toString().trim();
    final referralCode = (user['referral_code'] ?? '').toString().trim();
    final profileImageUrl = user['profile_image_url'] as String?;
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
    final currentBalance = _cachedWalletData != null
        ? _extractBalance(_cachedWalletData)
        : _extractBalance(user);

    if (_readyForLiveUpdates && _previousBalance != null && _previousBalance != currentBalance) {
      final diff = currentBalance - _previousBalance!;
      if (diff.abs() > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _balanceDiff = diff;
            _showBalanceDiff = true;
          });
          _balanceDiffTimer?.cancel();
          _balanceDiffTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showBalanceDiff = false);
          });
        });
      }
    }
    _previousBalance = currentBalance;
    final balance = currentBalance;

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

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _refresh,
              displacement: 18,
              edgeOffset: 10,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  // Minimalist Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: profileImageUrl != null && profileImageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(profileImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: profileImageUrl != null && profileImageUrl.isNotEmpty ? null : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${name.split(" ").first}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'MELE DATA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.notifications_outlined, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              onPressed: _openNotificationsCenter,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _openScreen(const PromoScreen()),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF1F2),
                                border: isDark ? null : Border.all(color: const Color(0xFFFFE4E6)),
                              ),
                              child: Icon(Icons.card_giftcard_rounded, color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48), size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hero Balance Card (Amigo Lite Polish)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x06000000),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Account Balance',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleBalanceVisibility,
                              child: Icon(
                                _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: balance),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            final rawBalance = NumberFormat('0.00').format(value);
                            final parts = rawBalance.split('.');
                            final whole = parts[0];
                            final decimal = parts.length > 1 ? '.${parts[1]}' : '.00';
                            
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₦',
                                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 4),
                                if (_hideBalance)
                                  Text(
                                    '••••••',
                                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0A0F1D), letterSpacing: -1.5),
                                  )
                                else ...[
                                  Text(
                                    NumberFormat('#,##0').format(int.tryParse(whole) ?? 0),
                                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0A0F1D), letterSpacing: -1.5),
                                  ),
                                  Text(
                                    decimal,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                                  ),
                                  if (_showBalanceDiff) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _balanceDiff > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _balanceDiff > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                            size: 12,
                                            color: _balanceDiff > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${_balanceDiff > 0 ? '+' : '-'}₦${NumberFormat('#,##0').format(_balanceDiff.abs())}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: _balanceDiff > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Virtual Account Chip
                        FutureBuilder<Map<String, dynamic>>(
                          future: _accountsFuture,
                          initialData: _cachedAccountsData,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                height: 44,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              );
                            }
                            final rawAccounts = (snapshot.data?['accounts'] as List?) ?? [];
                            if (rawAccounts.isEmpty) {
                              return GestureDetector(
                                onTap: _showAccountActivationDialog,
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F4F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      const Text('Tap to link BVN/NIN', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            final accounts = List<Map<String, dynamic>>.from(rawAccounts.map((i) => Map<String, dynamic>.from(i as Map)));
                            accounts.sort((a, b) {
                              final aName = (a['bank_name'] ?? '').toString().toLowerCase();
                              final bName = (b['bank_name'] ?? '').toString().toLowerCase();
                              if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
                              if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
                              return 0;
                            });

                            final activeAccount = accounts.first;
                            final bankName = (activeAccount['bank_name'] ?? 'Bank').toString().trim();
                            final accountNumber = activeAccount['account_number'] ?? '';

                            return GestureDetector(
                              onTap: () => FundWalletSheet.show(context),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      bankName == 'Moniepoint' ? 'Moniepoint MFB' : bankName,
                                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      accountNumber,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _copyAccountNumber(accountNumber),
                                      child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        // Quick Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => FundWalletSheet.show(context),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E64F8),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, color: Colors.white, size: 18),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Balance',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E64F8).withValues(alpha: 0.15) : const Color(0xFFEEF4FF),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 16, color: Color(0xFF1E64F8)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Transfer',
                                        style: TextStyle(color: Color(0xFF1E64F8), fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Feature placeholder
                                },
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F5F9),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payment_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pay',
                                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_activeCampaigns.any((c) => !c.isClaimed)) ...[
                    ..._activeCampaigns.where((c) => !c.isClaimed).map((c) => _buildCampaignProgressCard(c)).toList(),
                    const SizedBox(height: 12),
                  ],

                  // Top Services Row Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x04000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTopServiceItem(
                          context,
                          label: 'Data',
                          icon: Icons.wifi,
                          iconColor: const Color(0xFF1D61F2),
                          bgColor: const Color(0xFFEFF6FF),
                          onTap: () => _openScreen(const DataScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Airtime',
                          icon: Icons.sim_card_rounded,
                          iconColor: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          onTap: () => _openScreen(const AirtimeScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Electricity',
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFEA580C),
                          bgColor: const Color(0xFFFFF7ED),
                          onTap: () => _openScreen(const ElectricityScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Cable TV',
                          icon: Icons.tv_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF5F3FF),
                          onTap: () => _openScreen(const CableScreen()),
                        ),
                      ],
                    ),
                  ),

            if (referralCode.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0x06000000), blurRadius: 15, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invite friends & earn bonus',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final referralLink = "https://meledata.ng/register?ref=$referralCode";
                        final shareMessage = "Hey! Buy cheap data, airtime, and utility top-ups instantly on MELE DATA. Register using my link: $referralLink";
                        
                        try {
                          await Share.share(
                            shareMessage,
                            subject: "Join MELE DATA",
                          );
                        } catch (e) {
                          await Clipboard.setData(ClipboardData(text: referralLink));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Referral link copied to clipboard!"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Share Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
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
                  return GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }
                
                return GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < recent.length; i++) ...[
                        _RecentActivityTile(
                          tx: recent[i],
                          title: _txTitleFor(recent[i]),
                          subtitle: _txSubtitleFor(recent[i]),
                          amount: _txAmountLabel(recent[i]),
                          date: _txDateLabel(recent[i]).split(' • ').first,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openReceipt(recent[i]);
                          },
                        ),
                        if (i < recent.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.08 : 0.05),
                          ),
                      ]
                    ],
                  ),
                );
              },
            ),

            // Support/Help Section - Human Warmth
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
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
                            color: heroSoftText.withValues(alpha: 0.6),
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                'MELE DATA v1.2.0 • SECURE & TRUSTED',
                style: TextStyle(
                  color: muted.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionalUpdateBanner(SessionController session) {
    if (!session.optionalUpdateAvailable || _dismissedUpdateBanner || _dismissedVersionStr == session.latestAppVersion) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0.12),
            const Color(0xFF1D4ED8).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'New Update Available',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version ${session.latestAppVersion} has new features and performance boosts.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(Theme.of(context).platform == TargetPlatform.iOS
                  ? session.appStoreUrl
                  : session.playStoreUrl);
              // Avoid canLaunchUrl check, directly launch to avoid issues with standard OS intents
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Update',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            onPressed: () => _dismissUpdateBanner(session.latestAppVersion),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignProgressCard(RewardCampaign campaign) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade600;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final progressPercent = (campaign.progressValue / campaign.targetValue).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${campaign.targetValue.toStringAsFixed(0)} ${campaign.targetMetric.toLowerCase().contains('gb') ? 'GB' : ''}',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'REWARD',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₦${campaign.rewardAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                campaign.isClaimed 
                    ? 'Claimed' 
                    : '${campaign.progressValue.toStringAsFixed(1)} / ${campaign.targetValue.toStringAsFixed(0)} ${campaign.targetMetric.toLowerCase().contains('gb') ? 'GB' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: campaign.isClaimed ? Colors.green : textPrimary,
                ),
              ),
              Text(
                campaign.isClaimed ? 'Claimed' : '${(progressPercent * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: campaign.isClaimed ? Colors.green : textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: campaign.isClaimed ? 1.0 : progressPercent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                campaign.isClaimed 
                    ? Colors.green 
                    : (campaign.isQualified ? Colors.green : primaryColor),
              ),
            ),
          ),
          if (campaign.isQualified && !campaign.isClaimed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: () => _claimReward(campaign),
                icon: const Icon(Icons.stars_rounded, size: 18),
                label: const Text('Claim Reward', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimReward(RewardCampaign campaign) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claiming reward...')),
      );
      
      final token = (context.read<SessionController>().token ?? '').trim();
      if (token.isEmpty) return;
      final agentService = AgentService(token: token);
      final result = await agentService.claimReward(campaign.id);
      
      if (mounted) {
        // Refresh dashboard
        final dashboardKey = DashboardSnapshotCache.identityFromUser(context.read<SessionController>().user) ?? token;
        _reloadDashboard(token, dashboardKey);
        
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You have successfully claimed your reward for "${campaign.title}".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${campaign.rewardAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'It has been credited to your wallet.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming reward: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
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
            'Your recent purchases and wallet activity will appear here as soon as you start using MELE DATA.',
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
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final softText = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF64748B);
    final subtleLine = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final formattedNumber = accountNumber.trim().isEmpty ? '—' : accountNumber;

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bank Name (Top)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_rounded, size: 14, color: softText),
              const SizedBox(width: 8),
              Text(
                bankName.toUpperCase(),
                style: TextStyle(
                  color: softText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Account Number (Bold Hero)
          GestureDetector(
            onTap: onCopyAccount,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formattedNumber,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: heroText,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          fontSize: compact ? 28 : 34,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                // Account Name (Under Account Number)
                Text(
                  accountName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: heroText.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Professional CTA Area
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: subtleLine,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'AUTOMATIC FUNDING',
                  style: TextStyle(
                    color: softText.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: subtleLine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyAccount,
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copy Number'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: subtleLine),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // Logic for "How to Fund" or similar if needed, 
                    // for now just show a tip
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transfers to this account fund your wallet instantly.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Help'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
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
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6),
                    width: 1.5,
                  ),
                  boxShadow: _pressed ? [] : [
                    BoxShadow(
                      color: widget.item.accent.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.item.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.item.accent.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ]
                      ),
                      child: Icon(
                        widget.item.icon,
                        size: compact ? 22 : 26,
                        color: widget.item.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              fontSize: compact ? 11 : 12,
                            ),
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.14,),
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

class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner({required this.referralCode});

  final String referralCode;

  @override
  Widget build(BuildContext context) {
    if (referralCode.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2A) : const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.06 : 0.04,),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.15,
                        fontSize: 20,
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12,),
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

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
              color: Colors.grey.withValues(alpha: 0.3),
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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
            'Need help? Contact support at meledata.ng',
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
    required this.onTap,
  });
  final Map<String, dynamic> tx;
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = tx['tx_type']?.toString() ?? '';
    final isCredit = type == 'wallet_fund';
    final status = (tx['status'] ?? 'success').toString().toLowerCase();

    final icon = switch (type) {
      'data' => Icons.wifi_rounded,
      'airtime' => Icons.phone_iphone_rounded,
      'electricity' => Icons.bolt_rounded,
      'cable' => Icons.live_tv_rounded,
      'exam' => Icons.school_rounded,
      'wallet_fund' => Icons.add_rounded,
      _ => Icons.receipt_long_rounded,
    };

    final statusColor = status == 'success'
        ? const Color(0xFF10B981)
        : (status == 'pending' || status == 'processing' || status == 'queued'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        color: isCredit ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'failed') ...[
                          Icon(Icons.error_rounded, size: 12, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          date,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

class _MELEDATAAccountActivationDialog extends StatefulWidget {
  final VoidCallback onActivated;

  const _MELEDATAAccountActivationDialog({required this.onActivated});

  @override
  State<_MELEDATAAccountActivationDialog> createState() => _MELEDATAAccountActivationDialogState();
}

class _MELEDATAAccountActivationDialogState extends State<_MELEDATAAccountActivationDialog> {
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

      if (!mounted) return;
      widget.onActivated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accounts generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Generate MELE DATA Account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Switcher between BVN and NIN
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.4),
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
                                    : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter ${_option.toUpperCase()} number',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inputCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                enabled: !_loading,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '11-digit ${_option.toUpperCase()}',
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'MELE DATA will not store your ${_option.toUpperCase()} in our system for your safety.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brightness == Brightness.dark ? Colors.white60 : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'End-to-end secured protocol',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Generate'),
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
