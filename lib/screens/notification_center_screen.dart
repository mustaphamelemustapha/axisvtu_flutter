import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../services/notifications_service.dart';
import '../services/transactions_service.dart';
import '../state/session.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/notification_row.dart';
import '../widgets/purchase_result_sheet.dart';

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

  String _statusOf(Map<String, dynamic> tx) {
    return (tx['status'] ?? 'pending').toString().trim().toLowerCase();
  }

  String _typeOf(Map<String, dynamic> tx) {
    return (tx['tx_type'] ?? 'transaction').toString().trim().toLowerCase();
  }

  bool _isCredit(Map<String, dynamic> tx) => _typeOf(tx) == 'wallet_fund' || _typeOf(tx) == 'admin_credit' || _typeOf(tx) == 'agent_reward';

  double _amountOf(Map<String, dynamic> tx) {
    final value = tx['amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _titleFor(Map<String, dynamic> tx) {
    return switch (_typeOf(tx)) {
      'data' => 'Data Bundle',
      'wallet_fund' => 'Account Top-up',
      'admin_credit' => 'Admin Credit',
      'admin_debit' => 'Admin Debit',
      'agent_reward' => 'Agent Reward',
      'airtime' => 'Airtime Recharge',
      'cable' => 'Cable TV',
      'electricity' => 'Electricity Token',
      'exam' => 'Exam PIN',
      _ => 'Service',
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
      final ledger = meta['ledger_description'];
      if ((ledger ?? '').toString().trim().isNotEmpty) {
        return ledger.toString();
      }
    }
    final network = (tx['network'] ?? '').toString().trim();
    if (network.isNotEmpty) return network.toUpperCase();
    
    final failureReason = (tx['failure_reason'] ?? '').toString().trim();
    final type = _typeOf(tx);
    if ((type == 'admin_credit' || type == 'admin_debit') && failureReason.isNotEmpty) {
      return failureReason;
    }
    
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
    return DateFormat('d MMM, yyyy • HH:mm').format(date.toLocal());
  }

  String _amountLabel(Map<String, dynamic> tx) {
    final amount = _amountOf(tx);
    final sign = _isCredit(tx) ? '+' : '-';
    return '$sign₦${amount.toStringAsFixed(2)}';
  }

  IconData _iconFor(Map<String, dynamic> tx) {
    return switch (_typeOf(tx)) {
      'data' => Icons.wifi_rounded,
      'wallet_fund' => Icons.account_balance_wallet_rounded,
      'admin_credit' => Icons.account_balance_wallet_rounded,
      'admin_debit' => Icons.money_off_rounded,
      'agent_reward' => Icons.workspace_premium_rounded,
      'airtime' => Icons.phone_iphone_rounded,
      'cable' => Icons.tv_rounded,
      'electricity' => Icons.flash_on_rounded,
      'exam' => Icons.school_rounded,
      _ => Icons.receipt_long_rounded,
    };
  }

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s == 'success') return const Color(0xFF16A34A);
    if (s == 'pending' || s == 'processing' || s == 'queued') {
      return const Color(0xFFF59E0B);
    }
    if (s == 'refunded') return const Color(0xFF0EA5E9);
    return Theme.of(context).colorScheme.error;
  }

  Future<void> _copyRef(String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reference copied')));
  }

  Map<String, dynamic> _metaOf(Map<String, dynamic> tx) {
    final raw = tx['meta'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _firstText(Iterable<dynamic?> values, {String fallback = '—'}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _receiptRecipientFor(Map<String, dynamic> tx) {
    final meta = _metaOf(tx);
    return _firstText([
      meta['recipient_phone'],
      meta['phone_number'],
      meta['meter_number'],
      meta['smartcard_number'],
      tx['recipient_phone'],
      tx['phone_number'],
      tx['meter_number'],
      tx['smartcard_number'],
    ]);
  }

  String _receiptNetworkFor(Map<String, dynamic> tx) {
    final meta = _metaOf(tx);
    return _firstText([
      tx['network'],
      meta['network'],
      meta['provider'],
      tx['provider'],
    ]);
  }

  String _receiptPlanFor(Map<String, dynamic> tx) {
    final meta = _metaOf(tx);
    return _firstText([
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
      _titleFor(tx),
    ]);
  }

  String _receiptSenderFor() {
    final user = context.read<SessionController>().user;
    final name = user?['full_name'];
    return _firstText([name, 'MELE DATA User'], fallback: 'MELE DATA User');
  }

  String _receiptReferenceFor(Map<String, dynamic> tx) {
    final meta = _metaOf(tx);
    return _firstText([
      tx['reference'],
      tx['external_reference'],
      meta['reference'],
      meta['external_reference'],
      tx['id'],
    ]);
  }

  String _receiptSubtitleFor(Map<String, dynamic> tx) {
    final parts = <String>[];
    final recipient = _receiptRecipientFor(tx);
    final network = _receiptNetworkFor(tx);
    if (recipient != '—') parts.add(recipient);
    if (network != '—') parts.add(network.toUpperCase());
    if (parts.isEmpty) {
      final ref = _receiptReferenceFor(tx);
      if (ref != '—') parts.add(ref);
    }
    return parts.isEmpty ? 'Transaction receipt' : parts.join(' • ');
  }

  List<ReceiptField> _receiptFieldsFor(Map<String, dynamic> tx) {
    final meta = _metaOf(tx);
    final sender = _receiptSenderFor();
    final recipient = _receiptRecipientFor(tx);
    final network = _receiptNetworkFor(tx);
    final plan = _receiptPlanFor(tx);
    final reference = _receiptReferenceFor(tx);
    final providerRef = _firstText([
      tx['external_reference'],
      meta['external_reference'],
      meta['provider_reference'],
    ], fallback: '');
    final ledger = meta['ledger_description']?.toString() ?? '';

    final fields = <ReceiptField>[
      ReceiptField(label: 'Time', value: _formatDate(tx)),
      ReceiptField(label: 'Sender Name', value: sender),
      if (recipient != '—') ReceiptField(label: 'Recipient', value: recipient),
      if (network != '—')
        ReceiptField(label: 'Network', value: network.toUpperCase()),
      ReceiptField(label: 'Plan', value: plan),
      if (_typeOf(tx) != 'data')
        ReceiptField(label: 'Amount', value: _amountLabel(tx)),
      ReceiptField(label: 'Reference', value: reference),
      if (ledger.isNotEmpty) ReceiptField(label: 'Description', value: ledger),
    ];

    if (providerRef.isNotEmpty) {
      fields.add(ReceiptField(label: 'Provider Ref', value: providerRef));
    }

    return fields;
  }

  Future<void> _openTransactionReceipt(
    Map<String, dynamic> tx, {
    required bool autoShareOnOpen,
  }) async {
    final status = _statusOf(tx);
    final title = _titleFor(tx);
    final subtitle = _receiptSubtitleFor(tx);
    final fields = _receiptFieldsFor(tx);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: title,
        subtitle: subtitle,
        fields: fields,
        autoShareOnOpen: autoShareOnOpen,
      ),
    );
  }

  Future<void> _closeDetailAndOpenReceipt(
    BuildContext sheetContext,
    Map<String, dynamic> tx, {
    required bool autoShareOnOpen,
  }) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    try {
      await _openTransactionReceipt(tx, autoShareOnOpen: autoShareOnOpen);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open receipt right now.')),
      );
    }
  }

  void _openTxDetails(Map<String, dynamic> tx) {
    final status = _statusOf(tx);
    final color = _statusColor(context, status);
    final isCredit = _isCredit(tx);
    final failure = (tx['failure_reason'] ?? '').toString().trim();
    final receiptRef = (tx['reference'] ?? '').toString().trim();
    final created = _formatDate(tx);
    final typeLabel = _titleFor(tx);
    final summaryLine = _subtitleFor(tx);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.44,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.08),
                        ),
                        boxShadow: AxisShadows.softGlow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Image.asset(
                                      'assets/brand/meledata-icon-clean.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => Icon(
                                        _iconFor(tx),
                                        color: color,
                                        size: 20,
                                      ),
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
                                      status == 'success'
                                          ? 'Purchase successful'
                                          : (status == 'pending'
                                                ? 'Processing order'
                                                : 'Order failed'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      typeLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.60),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.16),
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ReceiptDetailLine(
                            label: 'Recipient / Service',
                            value: summaryLine,
                          ),
                          _ReceiptDetailLine(
                            label: 'Amount',
                            value: _amountLabel(tx),
                            valueColor: isCredit
                                ? const Color(0xFF16A34A)
                                : Theme.of(context).colorScheme.error,
                            strong: true,
                          ),
                          _ReceiptDetailLine(
                            label: 'Date / Time',
                            value: created,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Details',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Reference',
                            value: receiptRef,
                            trailing: IconButton(
                              onPressed: () => _copyRef(receiptRef),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                          ),
                          if ((tx['external_reference'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            _DetailRow(
                              label: 'Provider Ref',
                              value: (tx['external_reference'] ?? '')
                                  .toString(),
                            ),
                          _DetailRow(
                            label: 'Type',
                            value: _typeOf(tx).toUpperCase(),
                          ),
                          if (failure.isNotEmpty)
                            _DetailRow(
                              label: 'Status note',
                              value: failure,
                              valueColor: Theme.of(context).colorScheme.error,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useVertical = constraints.maxWidth < 330;
                        if (useVertical) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _closeDetailAndOpenReceipt(
                                    context,
                                    tx,
                                    autoShareOnOpen: false,
                                  ),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: const Text('View Receipt'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _closeDetailAndOpenReceipt(
                                    context,
                                    tx,
                                    autoShareOnOpen: true,
                                  ),
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share Receipt'),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _closeDetailAndOpenReceipt(
                                    context,
                                    tx,
                                    autoShareOnOpen: false,
                                  ),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: const Text('View Receipt'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _closeDetailAndOpenReceipt(
                                    context,
                                    tx,
                                    autoShareOnOpen: true,
                                  ),
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share Receipt'),
                                ),
                              ),
                            ],
                          );
                        }
                      },
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

  Future<void> _handleTap(AppNotification item) async {
    HapticFeedback.selectionClick();
    await _markRead(item);
    if (item.payload != null &&
        (item.kind == AppNotificationKind.transaction ||
            item.kind == AppNotificationKind.wallet) &&
        item.payload!.containsKey('tx_type')) {
      _openTxDetails(item.payload!);
    } else {
      _openRoute(item);
    }
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
        final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: isDark ? 0.68 : 0.64,);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.16 : 0.18,),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
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
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28,),
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
                            color: item.accent.withValues(alpha: isDark ? 0.18 : 0.12,),
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
    final name = (user['full_name'] ?? user['name'] ?? 'MELE DATA User')
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
                              .withValues(alpha: 0.62),
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
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: Theme.of(context).brightness == Brightness.dark
                                  ? 0.18
                                  : 0.20,
                            ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.26)
                              : const Color(0xFF2457F5).withValues(alpha: 0.10),
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
                                    ? Colors.white.withValues(alpha: 0.82)
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
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ReceiptDetailLine extends StatelessWidget {
  const _ReceiptDetailLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

