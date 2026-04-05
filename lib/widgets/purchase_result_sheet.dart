import 'package:flutter/material.dart';

import 'glass_card.dart';

class ReceiptField {
  const ReceiptField({required this.label, required this.value});

  final String label;
  final String value;
}

class PurchaseResultSheet extends StatelessWidget {
  const PurchaseResultSheet({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.fields,
    this.footer,
  });

  final String status;
  final String title;
  final String subtitle;
  final List<ReceiptField> fields;
  final Widget? footer;

  bool get _isSuccess => status.toLowerCase() == 'success';
  bool get _isPending => status.toLowerCase() == 'pending';

  @override
  Widget build(BuildContext context) {
    final iconBg = _isSuccess
        ? const Color(0xFFD1FADF)
        : (_isPending ? const Color(0xFFFFF4CC) : const Color(0xFFFEE2E2));
    final iconColor = _isSuccess
        ? const Color(0xFF16A34A)
        : (_isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    final pillBg = _isSuccess
        ? const Color(0xFFD1FADF)
        : (_isPending ? const Color(0xFFFFF4CC) : const Color(0xFFFEE2E2));

    final statusLabel = _isSuccess
        ? 'Successful'
        : (_isPending ? 'Pending' : 'Failed');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(
              _isSuccess
                  ? Icons.check_rounded
                  : (_isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.close_rounded),
              color: iconColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long),
                    const SizedBox(width: 8),
                    Text(
                      'Transfer Receipt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(statusLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...fields.map(
                  (f) => _ReceiptRow(label: f.label, value: f.value),
                ),
              ],
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Flexible(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
