import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/transactions_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../theme/axis_tokens.dart';
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

  bool _isCredit(Map<String, dynamic> tx) => _typeOf(tx) == 'wallet_fund';

  double _amountOf(Map<String, dynamic> tx) {
    final value = tx['amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
        _typeFilter == 'wallet_fund' ? 'WALLET' : _typeFilter.toUpperCase(),
      );
    }
    if (_dateFilter != 'all') parts.add(_dateFilterLabel(_dateFilter));
    return parts.join(' • ');
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
                          'Filter Transactions',
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
                                  .map(
                                    (status) => _FilterChipBtn(
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
                                  .map(
                                    (type) => _FilterChipBtn(
                                      label: type == 'wallet_fund'
                                          ? 'WALLET'
                                          : type.toUpperCase(),
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
                              .map(
                                (value) => _FilterChipBtn(
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
    return _firstText([name, 'AxisVTU User'], fallback: 'AxisVTU User');
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

    final fields = <ReceiptField>[
      ReceiptField(label: 'Time', value: _formatDate(tx)),
      ReceiptField(label: 'Sender Name', value: sender),
      if (recipient != '—') ReceiptField(label: 'Recipient', value: recipient),
      if (network != '—') ReceiptField(label: 'Network', value: network.toUpperCase()),
      ReceiptField(label: 'Plan', value: plan),
      ReceiptField(label: 'Amount', value: _amountLabel(tx)),
      ReceiptField(label: 'Reference', value: reference),
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
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
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
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _iconFor(tx),
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status == 'success'
                                          ? 'Transaction successful'
                                          : (status == 'pending'
                                              ? 'Transaction pending'
                                              : 'Transaction failed'),
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      typeLabel,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  border: Border.all(color: color.withValues(alpha: 0.16)),
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
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Details',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
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
                          if ((tx['external_reference'] ?? '').toString().trim().isNotEmpty)
                            _DetailRow(
                              label: 'Provider Ref',
                              value: (tx['external_reference'] ?? '').toString(),
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
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
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return SafeArea(
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
                      _HeaderActionBtn(icon: Icons.refresh_rounded, onTap: _reload),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _txFuture == null ? '0 records' : '${_activeFilterCount} filters',
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Transactions and receipts at a glance',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _txFuture == null ? '0 records' : '${_activeFilterCount} filters',
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
            if (compact)
              Column(
                children: [
                  GlassCard(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search transactions',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _HeaderActionBtn(
                      icon: Icons.tune_rounded,
                      badgeCount: _activeFilterCount,
                      onTap: _openFilterSheet,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search transactions',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderActionBtn(
                    icon: Icons.tune_rounded,
                    badgeCount: _activeFilterCount,
                    onTap: _openFilterSheet,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Successful',
                    selected: _statusFilter == 'success',
                    onTap: () => setState(() => _statusFilter = 'success'),
                  ),
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Pending',
                    selected: _statusFilter == 'pending',
                    onTap: () => setState(() => _statusFilter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Failed',
                    selected: _statusFilter == 'failed',
                    onTap: () => setState(() => _statusFilter = 'failed'),
                  ),
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Data',
                    selected: _typeFilter == 'data',
                    onTap: () => setState(() => _typeFilter = 'data'),
                  ),
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Airtime',
                    selected: _typeFilter == 'airtime',
                    onTap: () => setState(() => _typeFilter = 'airtime'),
                  ),
                  const SizedBox(width: 8),
                  _MiniFilterChip(
                    label: 'Bills',
                    selected: _typeFilter == 'cable' || _typeFilter == 'electricity',
                    onTap: () => setState(() => _typeFilter = 'cable'),
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Transactions',
                                  value: '${filtered.length}',
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Success',
                                  value: '$successCount',
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Credit',
                                  value: '+₦${creditTotal.toStringAsFixed(2)}',
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Debit',
                                  value: '-₦${debitTotal.toStringAsFixed(2)}',
                                  color: Theme.of(context).colorScheme.error,
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
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
                        onBrowseServices: () => Navigator.of(context)
                            .pushNamedAndRemoveUntil('/app', (route) => false),
                      )
                    else
                      ...filtered.map(
                        (tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryTxCard(
                            icon: _iconFor(tx),
                            title: _titleFor(tx),
                            subtitle: _subtitleFor(tx),
                            date: _formatDate(tx),
                            amount: _amountLabel(tx),
                            status: _statusOf(tx),
                            amountColor: _isCredit(tx)
                                ? const Color(0xFF16A34A)
                                : Theme.of(context).colorScheme.error,
                            statusColor: _statusColor(context, _statusOf(tx)),
                            onTap: () => _openTxDetails(tx),
                          ),
                        ),
                      ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.10)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.20)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.onBrowseServices});

  final VoidCallback onBrowseServices;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 4),
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
              'No transactions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your successful purchases will appear here once you start using services.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 180,
              child: FilledButton(
                onPressed: onBrowseServices,
                child: const Text('Browse services'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: _HistorySkeletonRow(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySkeletonRow extends StatelessWidget {
  const _HistorySkeletonRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A2433) : const Color(0xFFEAF0F7);
    final shimmer = isDark ? const Color(0xFF243244) : const Color(0xFFF4F7FB);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: 128,
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
                width: 92,
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
              width: 70,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 20,
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 132,
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  const _FilterChipBtn({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _HistoryTxCard extends StatelessWidget {
  const _HistoryTxCard({
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
    final compact = MediaQuery.sizeOf(context).width < 380;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
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
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
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
                      Text(
                        date,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        amount,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        border: Border.all(color: statusColor.withValues(alpha: 0.14)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          border: Border.all(color: statusColor.withValues(alpha: 0.14)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing case final Widget item) item,
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: strong ? -0.05 : 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
