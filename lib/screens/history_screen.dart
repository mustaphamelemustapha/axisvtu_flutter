import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/transactions_service.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_toggle_button.dart';

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

  void _openTxDetails(Map<String, dynamic> tx) {
    final status = _statusOf(tx);
    final color = _statusColor(context, status);
    final isCredit = _isCredit(tx);
    final failure = (tx['failure_reason'] ?? '').toString().trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.42,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            _iconFor(tx),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _titleFor(tx),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(label: 'Time', value: _formatDate(tx)),
                    _DetailRow(label: 'Type', value: _typeOf(tx).toUpperCase()),
                    _DetailRow(
                      label: 'Amount',
                      value: _amountLabel(tx),
                      valueColor: isCredit
                          ? const Color(0xFF16A34A)
                          : Theme.of(context).colorScheme.error,
                    ),
                    _DetailRow(
                      label: 'Network / Provider',
                      value: _subtitleFor(tx),
                    ),
                    _DetailRow(
                      label: 'Reference',
                      value: (tx['reference'] ?? '').toString(),
                      trailing: IconButton(
                        onPressed: () =>
                            _copyRef((tx['reference'] ?? '').toString()),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ),
                    if ((tx['external_reference'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _DetailRow(
                        label: 'Provider Ref',
                        value: (tx['external_reference'] ?? '').toString(),
                      ),
                    if (failure.isNotEmpty)
                      _DetailRow(
                        label: 'Failure Reason',
                        value: failure,
                        valueColor: Theme.of(context).colorScheme.error,
                      ),
                    if (tx['has_open_report'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.36),
                            ),
                          ),
                          child: const Text(
                            'You have an open report on this transaction.',
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AxisPalette.gradient,
                    borderRadius: BorderRadius.circular(14),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Credits and debits at a glance',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const ThemeToggleButton(size: 44),
                const SizedBox(width: 8),
                _HeaderActionBtn(icon: Icons.refresh_rounded, onTap: _reload),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? const LinearGradient(
                        colors: [Color(0xFF0E1B2C), Color(0xFF172A46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEAF2FF), Color(0xFFD9E8FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Track every transaction, filter fast, and open details with one tap.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.insights_rounded, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search by reference, number or service',
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
            FutureBuilder<List<dynamic>>(
              future: _txFuture,
              builder: (context, snapshot) {
                if (_txFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Failed to load history',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(snapshot.error.toString()),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
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
                                style: Theme.of(context).textTheme.bodySmall,
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
                      const GlassCard(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No transactions yet.')),
                        ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
          color: selected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.26),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.26)),
              ),
              child: Icon(icon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: amountColor),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
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
