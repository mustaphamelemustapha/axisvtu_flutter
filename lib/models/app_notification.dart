import 'package:flutter/material.dart';

enum AppNotificationKind {
  transaction,
  wallet,
  security,
  broadcast,
  info,
}

enum AppNotificationAction {
  none,
  history,
  wallet,
  profile,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.action,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.accent,
    this.reference,
    this.read = false,
    this.statusLabel,
    this.payload,
  });

  final String id;
  final AppNotificationKind kind;
  final AppNotificationAction action;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color accent;
  final String? reference;
  final bool read;
  final String? statusLabel;
  final Map<String, dynamic>? payload;

  bool get unread => !read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      kind: kind,
      action: action,
      title: title,
      description: description,
      timestamp: timestamp,
      icon: icon,
      accent: accent,
      reference: reference,
      read: read ?? this.read,
      statusLabel: statusLabel,
      payload: payload,
    );
  }

  static DateTime _parseTimestamp(Map<String, dynamic> raw) {
    final candidates = [
      raw['created_at'],
      raw['updated_at'],
      raw['sent_at'],
      raw['published_at'],
      raw['date'],
      raw['timestamp'],
    ];
    for (final candidate in candidates) {
      if (candidate is DateTime) return candidate;
      final parsed = DateTime.tryParse(candidate?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static String _firstNonEmpty(Iterable<Object?> values, {String fallback = '—'}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String _formatMoney(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  static AppNotification fromTransaction(
    Map<String, dynamic> tx, {
    bool read = false,
  }) {
    final type = (tx['tx_type'] ?? 'transaction').toString().trim().toLowerCase();
    final status = (tx['status'] ?? 'pending').toString().trim().toLowerCase();
    final amount = _formatMoney(tx['amount']);
    final network = _firstNonEmpty([
      tx['network'],
      tx['service_network'],
      tx['provider'],
    ]).toUpperCase();
    final meta = tx['meta'];
    final metaMap = meta is Map ? meta.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final ledgerDescription = _firstNonEmpty([
      metaMap['ledger_description'],
      tx['description'],
    ]);
    final recipient = _firstNonEmpty([
      metaMap['recipient_phone'],
      metaMap['phone_number'],
      metaMap['meter_number'],
      metaMap['reference'],
      tx['recipient'],
    ]);
    final plan = _firstNonEmpty([
      metaMap['plan_name'],
      metaMap['package_name'],
      metaMap['package_code'],
      metaMap['bundle_name'],
      tx['plan'],
      tx['product_name'],
    ]);
    final reference = _firstNonEmpty([
      tx['reference'],
      tx['tx_ref'],
      tx['transaction_reference'],
    ]);
    final timestamp = _parseTimestamp(tx);
    final baseTitle = switch (type) {
      'wallet_fund' when ledgerDescription.toLowerCase().contains('referral') => 'Referral reward',
      'data' => 'Data purchase',
      'airtime' => 'Airtime top-up',
      'cable' => 'Cable payment',
      'electricity' => 'Electricity payment',
      'exam' => 'Exam pin purchase',
      'wallet_fund' => 'Wallet funding',
      _ => 'Transaction',
    };
    final title = switch (status) {
      'success' => '$baseTitle successful',
      'failed' => '$baseTitle failed',
      'pending' => '$baseTitle pending',
      _ => baseTitle,
    };
    final detailBits = <String>[
      if (recipient != '—') recipient,
      if (network != '—') network,
      if (plan != '—') plan,
    ];
    final description = switch (type) {
      'wallet_fund' when ledgerDescription.toLowerCase().contains('referral') =>
        ledgerDescription.isNotEmpty ? ledgerDescription : 'Referral reward credited.',
      'wallet_fund' => 'Wallet credited with ₦$amount.',
      'data' => detailBits.isEmpty ? 'Data purchase update' : detailBits.join(' • '),
      'airtime' => detailBits.isEmpty ? 'Airtime purchase update' : detailBits.join(' • '),
      'cable' => detailBits.isEmpty ? 'Cable subscription update' : detailBits.join(' • '),
      'electricity' => detailBits.isEmpty ? 'Electricity payment update' : detailBits.join(' • '),
      'exam' => detailBits.isEmpty ? 'Exam pin update' : detailBits.join(' • '),
      _ => detailBits.isEmpty ? 'Transaction activity' : detailBits.join(' • '),
    };
    final kind = type == 'wallet_fund'
        ? AppNotificationKind.wallet
        : AppNotificationKind.transaction;
    final action = type == 'wallet_fund'
        ? AppNotificationAction.wallet
        : AppNotificationAction.history;
    final icon = switch (type) {
      'wallet_fund' => Icons.account_balance_wallet_rounded,
      'airtime' => Icons.phone_iphone_rounded,
      'cable' => Icons.live_tv_rounded,
      'electricity' => Icons.bolt_rounded,
      'exam' => Icons.school_rounded,
      _ => Icons.receipt_long_rounded,
    };
    final accent = switch (status) {
      'failed' => const Color(0xFFEF4444),
      'pending' => const Color(0xFFF59E0B),
      _ => const Color(0xFF2457F5),
    };

    return AppNotification(
      id: 'tx:${reference.isNotEmpty ? reference : timestamp.millisecondsSinceEpoch}',
      kind: kind,
      action: action,
      title: title,
      description: description,
      timestamp: timestamp,
      icon: icon,
      accent: accent,
      reference: reference == '—' ? null : reference,
      read: read,
      statusLabel: status,
      payload: tx,
    );
  }

  static AppNotification fromBroadcast(
    Map<String, dynamic> row, {
    bool read = false,
  }) {
    final title = _firstNonEmpty([
      row['title'],
      row['heading'],
      row['subject'],
      'AxisVTU update',
    ], fallback: 'AxisVTU update');
    final message = _firstNonEmpty([
      row['message'],
      row['body'],
      row['description'],
      'Important account update',
    ], fallback: 'Important account update');
    final timestamp = _parseTimestamp(row);
    final haystack = '$title $message'.toLowerCase();
    final kind = (haystack.contains('password') ||
            haystack.contains('pin') ||
            haystack.contains('login') ||
            haystack.contains('security') ||
            haystack.contains('verify'))
        ? AppNotificationKind.security
        : AppNotificationKind.broadcast;
    final action = kind == AppNotificationKind.security
        ? AppNotificationAction.profile
        : AppNotificationAction.none;
    final accent = kind == AppNotificationKind.security
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF2457F5);
    final icon = kind == AppNotificationKind.security
        ? Icons.security_rounded
        : Icons.campaign_rounded;

    return AppNotification(
      id: 'bc:${timestamp.millisecondsSinceEpoch}:${title.hashCode}:${message.hashCode}',
      kind: kind,
      action: action,
      title: title,
      description: message,
      timestamp: timestamp,
      icon: icon,
      accent: accent,
      reference: _firstNonEmpty([row['reference']]),
      read: read,
      statusLabel: null,
      payload: row,
    );
  }
}
