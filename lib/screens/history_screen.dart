import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/transactions_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/purchase_result_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  Future<List<dynamic>>? _txFuture;
  String _activeToken = '';

  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _dateFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = (context.watch<SessionController>().token ?? '').trim();
    if (token.isNotEmpty && token != _activeToken) {
      _activeToken = token;
      _reload();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    setState(() {
      _txFuture = TransactionsService(token: token).getTransactions();
    });
    await _txFuture;
  }

  List<Map<String, dynamic>> _normalize(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return items.where((tx) {
      final status = _statusOf(tx);
      final type = _typeOf(tx);

      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (_typeFilter != 'all' && type != _typeFilter) return false;
      if (!_matchesDateFilter(tx)) return false;

      if (query.isEmpty) return true;
      final ref = (tx['reference'] ?? '').toString().toLowerCase();
      final subtitle = _subtitleFor(tx).toLowerCase();
      final title = _titleFor(tx).toLowerCase();
      return ref.contains(query) ||
          subtitle.contains(query) ||
          title.contains(query);
    }).toList();
  }

  bool _matchesDateFilter(Map<String, dynamic> tx) {
    if (_dateFilter == 'all') return true;
    final created = _createdAt(tx)?.toLocal();
    if (created == null) return false;

    final now = DateTime.now();
    if (_dateFilter == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      return !created.isBefore(start);
    }
    if (_dateFilter == '7d') {
      final start = now.subtract(const Duration(days: 7));
      return !created.isBefore(start);
    }
    if (_dateFilter == '30d') {
      final start = now.subtract(const Duration(days: 30));
      return !created.isBefore(start);
    }
    return true;
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

  int get _activeFilterCount {
    var count = 0;
    if (_statusFilter != 'all') count++;
    if (_typeFilter != 'all') count++;
    if (_dateFilter != 'all') count++;
    return count;
  }

  String _dateFilterLabel(String value) {
    return switch (value) {
      'today' => 'Today',
      '7d' => 'Last 7 Days',
      '30d' => 'Last 30 Days',
      _ => 'All Time',
    };
  }

  String get _activeFilterSummary {
    final parts = <String>[];
    if (_statusFilter != 'all') parts.add(_statusFilter.toUpperCase());
    if (_typeFilter != 'all') {
      parts.add(
        _typeFilter == 'wallet_fund' ? 'TOP-UP' : _typeFilter.toUpperCase(),
      );
    }
    if (_dateFilter != 'all') parts.add(_dateFilterLabel(_dateFilter));
    return parts.join(' • ');
  }

  Map<String, List<Map<String, dynamic>>> _groupTransactions(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    for (final tx in items) {
      final created = _createdAt(tx)?.toLocal();
      if (created == null) {
        (groups['Older'] ??= []).add(tx);
        continue;
      }

      final date = DateTime(created.year, created.month, created.day);
      String key;
      if (date == today) {
        key = 'Today';
      } else if (date == yesterday) {
        key = 'Yesterday';
      } else if (date.isAfter(lastWeek)) {
        key = 'Last 7 Days';
      } else {
        key = 'Older';
      }

      (groups[key] ??= []).add(tx);
    }
    return groups;
  }

  Future<void> _openFilterSheet() async {
    String selectedStatus = _statusFilter;
    String selectedType = _typeFilter;
    String selectedDate = _dateFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.45,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                    child: ListView(
                      controller: controller,
                      children: [
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Filter Orders',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                    'all',
                                    'success',
                                    'pending',
                                    'failed',
                                    'refunded',
                                  ]
                                  .map<Widget>(
                                    (status) => _MiniFilterChip(
                                      label: status.toUpperCase(),
                                      selected: selectedStatus == status,
                                      onTap: () => setSheetState(
                                        () => selectedStatus = status,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Type',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                    'all',
                                    'data',
                                    'airtime',
                                    'cable',
                                    'electricity',
                                    'exam',
                                    'wallet_fund',
                                  ]
                                  .map<Widget>(
                                    (type) => _MiniFilterChip(
                                      label: type.replaceAll('_', ' ').toUpperCase(),
                                      selected: selectedType == type,
                                      onTap: () => setSheetState(
                                        () => selectedType = type,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Date Range',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['all', 'today', '7d', '30d']
                              .map<Widget>(
                                (value) => _MiniFilterChip(
                                  label: _dateFilterLabel(value).toUpperCase(),
                                  selected: selectedDate == value,
                                  onTap: () =>
                                      setSheetState(() => selectedDate = value),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setSheetState(() {
                                  selectedStatus = 'all';
                                  selectedType = 'all';
                                  selectedDate = 'all';
                                }),
                                child: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _statusFilter = selectedStatus;
                                    _typeFilter = selectedType;
                                    _dateFilter = selectedDate;
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Apply'),
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
    final token = (meta['token'] ?? tx['token'] ?? '').toString().trim();
    final units = (meta['units'] ?? tx['units'] ?? '').toString().trim();
    final address = (meta['address'] ?? tx['address'] ?? '').toString().trim();
    final customerName = (meta['customer_name'] ?? meta['customername'] ?? tx['customer_name'] ?? tx['customername'] ?? '').toString().trim();

    final txType = (tx['tx_type'] ?? '').toString().trim().toLowerCase();

    final fields = <ReceiptField>[
      ReceiptField(label: 'Time', value: _formatDate(tx)),
      ReceiptField(label: 'Sender Name', value: sender),
      if (recipient != '—') ReceiptField(label: 'Recipient', value: recipient),
      if (network != '—')
        ReceiptField(label: 'Network', value: network.toUpperCase()),
      if (customerName.isNotEmpty) ReceiptField(label: 'Customer Name', value: customerName),
      if (token.isNotEmpty) ReceiptField(label: 'Token', value: token),
      if (units.isNotEmpty) ReceiptField(label: 'Units', value: '$units kWh'),
      if (address.isNotEmpty) ReceiptField(label: 'Address', value: address),
      ReceiptField(label: 'Plan', value: plan),
      if (txType != 'data') ReceiptField(label: 'Amount', value: _amountLabel(tx)),
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
                          if (tx['has_open_report'] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Support ticket open for this transaction.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.35),
                                    ),
                              ),
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
                    if (status == 'failed') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return ConcentricCirclesBg(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            16,
            compact ? 16 : 20,
            24,
          ),
          children: [
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AxisPalette.gradient,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      _HeaderActionBtn(
                        icon: Icons.refresh_rounded,
                        onTap: _reload,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Transactions and receipts at a glance',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _txFuture == null
                          ? '0 records'
                          : '${_activeFilterCount} filters',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AxisPalette.gradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                        Text(
                          'Transactions and receipts at a glance',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _txFuture == null
                          ? '0 records'
                          : '${_activeFilterCount} filters',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderActionBtn(icon: Icons.refresh_rounded, onTap: _reload),
                ],
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() {}),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _openFilterSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                          if (_activeFilterCount > 0)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  _MiniFilterChip(
                    label: 'All',
                    selected: _statusFilter == 'all' && _typeFilter == 'all',
                    onTap: () => setState(() {
                      _statusFilter = 'all';
                      _typeFilter = 'all';
                    }),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Successful',
                    selected: _statusFilter == 'success',
                    onTap: () => setState(() => _statusFilter = 'success'),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Pending',
                    selected: _statusFilter == 'pending',
                    onTap: () => setState(() => _statusFilter = 'pending'),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Failed',
                    selected: _statusFilter == 'failed',
                    onTap: () => setState(() => _statusFilter = 'failed'),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Data',
                    selected: _typeFilter == 'data',
                    onTap: () => setState(() => _typeFilter = 'data'),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Airtime',
                    selected: _typeFilter == 'airtime',
                    onTap: () => setState(() => _typeFilter = 'airtime'),
                  ),
                  const SizedBox(width: 10),
                  _MiniFilterChip(
                    label: 'Funding',
                    selected: _typeFilter == 'wallet_fund',
                    onTap: () => setState(() => _typeFilter = 'wallet_fund'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _txFuture,
              builder: (context, snapshot) {
                if (_txFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const _HistoryLoadingState();
                }

                if (snapshot.hasError) {
                  return _HistoryNoticeCard(
                    icon: Icons.refresh_rounded,
                    title: 'Failed to load history',
                    subtitle: snapshot.error.toString(),
                    actionLabel: 'Retry',
                    onAction: _reload,
                  );
                }

                final all = _normalize(snapshot.data ?? const []);
                final filtered = _filter(all);
                final creditTotal = filtered
                    .where(_isCredit)
                    .fold<double>(0, (sum, tx) => sum + _amountOf(tx));
                final debitTotal = filtered
                    .where((tx) => !_isCredit(tx))
                    .fold<double>(0, (sum, tx) => sum + _amountOf(tx));
                final successCount = filtered
                    .where((tx) => _statusOf(tx) == 'success')
                    .length;

                return Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTIVITY INSIGHTS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${filtered.length} Transactions',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$successCount Success',
                                      style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1, thickness: 1, color: Color(0x10000000)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL INFLOW',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+₦${creditTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 30, color: const Color(0x10000000)),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL OUTFLOW',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '-₦${debitTotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_activeFilterCount > 0) ...[
                      GlassCard(
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _activeFilterSummary,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: muted),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _statusFilter = 'all';
                                _typeFilter = 'all';
                                _dateFilter = 'all';
                              }),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (filtered.isEmpty)
                      _HistoryEmptyState(
                        onBrowseServices: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/app', (route) => false),
                      )
                    else ...[
                      ..._groupTransactions(filtered).entries.map<Widget>((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 0, 12),
                                child: Text(
                                  group.key.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: muted.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.05),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (int i = 0; i < group.value.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          indent: 72,
                                          endIndent: 16,
                                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.05),
                                        ),
                                      _HistoryTxTile(
                                        icon: _iconFor(group.value[i]),
                                        title: _titleFor(group.value[i]),
                                        subtitle: _subtitleFor(group.value[i]),
                                        date: DateFormat('HH:mm').format(_createdAt(group.value[i])?.toLocal() ?? DateTime.now()),
                                        amount: _amountLabel(group.value[i]),
                                        status: _statusOf(group.value[i]),
                                        amountColor: _isCredit(group.value[i])
                                            ? const Color(0xFF16A34A)
                                            : Theme.of(context).colorScheme.onSurface,
                                        statusColor: _statusColor(context, _statusOf(group.value[i])),
                                        onTap: () => _openTxDetails(group.value[i]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionBtn extends StatelessWidget {
  const _HeaderActionBtn({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(icon, size: 22),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniFilterChip extends StatelessWidget {
  const _MiniFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected 
            ? color 
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.onBrowseServices});

  final VoidCallback onBrowseServices;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              size: 40,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore our services to see your transactions and activity logs right here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onBrowseServices,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text(
                'Explore Services',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 84,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      )),
    );
  }
}

class _HistoryNoticeCard extends StatelessWidget {
  const _HistoryNoticeCard({
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
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTxTile extends StatelessWidget {
  const _HistoryTxTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.status,
    required this.amountColor,
    required this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
  final String amount;
  final String status;
  final Color amountColor;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: statusColor, size: 20),
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
                      color: amountColor,
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

Widget _activeFilterChip(BuildContext context, String label, VoidCallback onRemove) {
  return Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
