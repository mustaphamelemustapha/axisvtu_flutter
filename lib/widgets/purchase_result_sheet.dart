import 'package:flutter/material.dart';

import '../services/receipt_export_service.dart';
import 'glass_card.dart';

class ReceiptField {
  const ReceiptField({required this.label, required this.value});

  final String label;
  final String value;
}

class PurchaseResultSheet extends StatefulWidget {
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

  @override
  State<PurchaseResultSheet> createState() => _PurchaseResultSheetState();
}

class _PurchaseResultSheetState extends State<PurchaseResultSheet> {
  bool _downloading = false;
  bool _sharing = false;

  bool get _busy => _downloading || _sharing;

  bool get _isSuccess => widget.status.toLowerCase() == 'success';
  bool get _isPending => widget.status.toLowerCase() == 'pending';

  Future<void> _downloadReceipt() async {
    if (_busy) return;
    setState(() => _downloading = true);
    try {
      await ReceiptExportService.downloadReceiptAsFile(
        context: context,
        title: widget.title,
        subtitle: widget.subtitle,
        status: widget.status,
        fields: widget.fields,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_busy) return;
    setState(() => _sharing = true);
    try {
      await ReceiptExportService.shareReceiptText(
        context: context,
        title: widget.title,
        subtitle: widget.subtitle,
        status: widget.status,
        fields: widget.fields,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

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
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
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
                ...widget.fields.map(
                  (f) => _ReceiptRow(label: f.label, value: f.value),
                ),
              ],
            ),
          ),
          if (widget.footer != null) ...[
            const SizedBox(height: 14),
            widget.footer!,
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadReceipt,
                  icon: _downloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Download Receipt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _shareReceipt,
                  icon: _sharing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded),
                  label: const Text('Share Receipt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
