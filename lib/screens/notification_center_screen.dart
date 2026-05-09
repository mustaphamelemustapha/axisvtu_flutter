import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../services/notifications_service.dart';
import '../services/transactions_service.dart';
import '../state/session.dart';
import '../widgets/glass_card.dart';
import '../widgets/notification_row.dart';

enum _NotificationFilter { all, unread, transactions, wallet, security }

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  static const _readIdsKey = 'notification_read_ids';

  Future<List<AppNotification>>? _future;
  Set<String> _readIds = <String>{};
  String _activeToken = '';
  bool _prefsLoaded = false;
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _loadReadIds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = (context.watch<SessionController>().token ?? '').trim();
    if (token.isNotEmpty &&
        (token != _activeToken || _future == null || !_prefsLoaded)) {
      _activeToken = token;
      _future = _loadInbox(token);
    }
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readIds = (prefs.getStringList(_readIdsKey) ?? <String>[]).toSet();
      _prefsLoaded = true;
    });
  }

  Future<List<AppNotification>> _loadInbox(String token) async {
    final txFuture = TransactionsService(token: token).getTransactions();
    final broadcastsFuture = NotificationsService(token: token).getBroadcasts();
    final rows = await Future.wait([txFuture, broadcastsFuture]);

    final notifications = <AppNotification>[
      ...((rows[0] as List)
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map((item) => AppNotification.fromTransaction(item))),
      ...((rows[1] as List)
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map((item) => AppNotification.fromBroadcast(item))),
    ];

    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final unique = <String, AppNotification>{};
    for (final item in notifications) {
      unique[item.id] = item;
    }
    return unique.values.toList();
  }

  List<AppNotification> _applyReadState(List<AppNotification> items) {
    return items
        .map((item) => item.copyWith(read: _readIds.contains(item.id)))
        .toList();
  }

  List<AppNotification> _filteredItems(List<AppNotification> items) {
    return switch (_filter) {
      _NotificationFilter.all => items,
      _NotificationFilter.unread => items.where((item) => item.unread).toList(),
      _NotificationFilter.transactions =>
        items.where((item) => item.kind == AppNotificationKind.transaction).toList(),
      _NotificationFilter.wallet =>
        items.where((item) => item.kind == AppNotificationKind.wallet).toList(),
      _NotificationFilter.security =>
        items.where((item) => item.kind == AppNotificationKind.security).toList(),
    };
  }

  Future<void> _markRead(AppNotification item) async {
    if (_readIds.contains(item.id)) return;
    final next = {..._readIds, item.id};
    setState(() => _readIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, next.toList());
  }

  Future<void> _markAllRead(List<AppNotification> items) async {
    final next = {
      ..._readIds,
      ...items.map((item) => item.id),
    };
    setState(() => _readIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, next.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _openRoute(AppNotification item) {
    final tab = switch (item.action) {
      AppNotificationAction.history => 2,
      AppNotificationAction.wallet => 1,
      AppNotificationAction.profile => 3,
      AppNotificationAction.none => null,
    };

    if (tab != null && widget.onNavigateTab != null) {
      widget.onNavigateTab!(tab);
      Navigator.of(context).pop();
      return;
    }

    _showDetailSheet(item);
  }

  Future<void> _handleTap(AppNotification item) async {
    HapticFeedback.selectionClick();
    await _markRead(item);
    _openRoute(item);
  }

  Future<void> _showDetailSheet(AppNotification item) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = Theme.of(context).colorScheme.surface;
        final titleColor = Theme.of(context).colorScheme.onSurface;
        final muted = Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.68 : 0.64,);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.16 : 0.18,),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.28,),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.accent.withOpacity(isDark ? 0.18 : 0.12,),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: muted,
                            height: 1.45,
                          ),
                    ),
                    if (item.reference != null && item.reference!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Reference',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.reference!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ),
                        if (item.action != AppNotificationAction.none) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _openRoute(item);
                              },
                              child: Text(
                                switch (item.action) {
                                  AppNotificationAction.history => 'Open History',
                                  AppNotificationAction.wallet => 'Open Wallet',
                                  AppNotificationAction.profile => 'Open Profile',
                                  AppNotificationAction.none => 'Open',
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final user = context.watch<SessionController>().user ?? {};
    final name = (user['full_name'] ?? user['name'] ?? 'AxisVTU User')
        .toString()
        .trim();

    final future = _future;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final token = (context.read<SessionController>().token ?? '').trim();
            if (token.isEmpty) return;
            setState(() {
              _future = _loadInbox(token);
            });
            await _future;
          },
          displacement: 18,
          edgeOffset: 10,
          child: FutureBuilder<List<AppNotification>>(
            future: future,
            builder: (context, snapshot) {
              final isLoading =
                  future == null || snapshot.connectionState == ConnectionState.waiting;
              final allItems = _applyReadState(snapshot.data ?? <AppNotification>[]);
              final unreadCount = allItems.where((item) => item.unread).length;
              final filtered = _filteredItems(allItems);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  14,
                  compact ? 16 : 20,
                  28,
                ),
                children: [
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.all(4),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Back',
                              ),
                            ),
                            const Spacer(),
                            GlassCard(
                              padding: const EdgeInsets.all(4),
                              child: IconButton(
                                onPressed: snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? null
                                    : () => setState(() {
                                          final token =
                                              (context.read<SessionController>().token ?? '').trim();
                                          if (token.isNotEmpty) {
                                            _future = _loadInbox(token);
                                          }
                                        }),
                                icon: const Icon(Icons.refresh_rounded),
                                tooltip: 'Refresh',
                              ),
                            ),
                          ],
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                '$unreadCount unread',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Row(
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                          ),
                        ),
                        const Spacer(),
                        if (unreadCount > 0)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              '$unreadCount unread',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        const SizedBox(width: 10),
                        GlassCard(
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                            onPressed: snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? null
                                : () => setState(() {
                                      final token =
                                          (context.read<SessionController>().token ?? '').trim();
                                      if (token.isNotEmpty) {
                                        _future = _loadInbox(token);
                                      }
                                    }),
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wallet funding, purchases, and security updates',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.62),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _markAllRead(allItems),
                        child: const Text('Mark all as read'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: Theme.of(context).brightness == Brightness.dark
                          ? const LinearGradient(
                              colors: [Color(0xFF0C1624), Color(0xFF13253B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF7FAFF), Color(0xFFEAF2FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(Theme.of(context).brightness == Brightness.dark
                                  ? 0.18
                                  : 0.20,
                            ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.26)
                              : const Color(0xFF2457F5).withOpacity(0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoading
                              ? 'Loading your latest activity.'
                              : unreadCount == 0
                                  ? 'Everything is up to date.'
                                  : 'You have $unreadCount unread update${unreadCount == 1 ? '' : 's'}.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.82)
                                    : const Color(0xFF5B6B82),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'All',
                          selected: _filter == _NotificationFilter.all,
                          onTap: () => setState(() => _filter = _NotificationFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Unread',
                          selected: _filter == _NotificationFilter.unread,
                          onTap: () => setState(() => _filter = _NotificationFilter.unread),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Transactions',
                          selected: _filter == _NotificationFilter.transactions,
                          onTap: () => setState(() => _filter = _NotificationFilter.transactions),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Wallet',
                          selected: _filter == _NotificationFilter.wallet,
                          onTap: () => setState(() => _filter = _NotificationFilter.wallet),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'Security',
                          selected: _filter == _NotificationFilter.security,
                          onTap: () => setState(() => _filter = _NotificationFilter.security),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    Column(
                      children: List.generate(
                        4,
                        (index) => Padding(
                          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
                          child: const _NotificationSkeleton(),
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    _EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load notifications',
                      subtitle:
                          'Check your connection and try again. Your account activity is still safe.',
                      actionLabel: 'Retry',
                      onAction: () {
                        final token =
                            (context.read<SessionController>().token ?? '').trim();
                        if (token.isNotEmpty) {
                          setState(() {
                            _future = _loadInbox(token);
                          });
                        }
                      },
                    )
                  else if (filtered.isEmpty)
                    _EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'You’re all caught up',
                      subtitle:
                          'Updates from wallet funding, purchases, and security events will appear here.',
                      actionLabel: 'View History',
                      onAction: () {
                        widget.onNavigateTab?.call(2);
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    Column(
                      children: [
                        ...filtered.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == filtered.length - 1 ? 0 : 12,
                            ),
                            child: NotificationRow(
                              item: item,
                              onTap: () => _handleTap(item),
                            ),
                          );
                        }),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
                ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.16),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
