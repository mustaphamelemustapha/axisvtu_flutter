import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final GlobalKey _receiptCaptureKey = GlobalKey();

  bool _downloading = false;
  bool _sharing = false;
  bool _beneficiaries = false;
  bool _axisBolt = false;

  bool get _busy => _downloading || _sharing;
  bool get _isSuccess => widget.status.toLowerCase() == 'success';
  bool get _isPending => widget.status.toLowerCase() == 'pending';

  String _fieldValue(String label) {
    for (final field in widget.fields) {
      if (field.label.trim().toLowerCase() == label.toLowerCase()) {
        return field.value.trim();
      }
    }
    return '';
  }

  Future<Uint8List?> _captureReceiptImage() async {
    await Future.delayed(const Duration(milliseconds: 18));
    final renderObject = _receiptCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final image = await renderObject.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _downloadReceipt() async {
    if (_busy) return;
    setState(() => _downloading = true);
    try {
      final imageBytes = await _captureReceiptImage();
      if (!mounted) return;
      if (imageBytes != null) {
        await ReceiptExportService.downloadReceiptImage(
          context: context,
          imageBytes: imageBytes,
          fields: widget.fields,
        );
      } else {
        await ReceiptExportService.downloadReceiptAsFile(
          context: context,
          title: widget.title,
          subtitle: widget.subtitle,
          status: widget.status,
          fields: widget.fields,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_busy) return;
    setState(() => _sharing = true);
    try {
      final imageBytes = await _captureReceiptImage();
      if (!mounted) return;
      if (imageBytes != null) {
        await ReceiptExportService.shareReceiptImage(
          context: context,
          imageBytes: imageBytes,
          fields: widget.fields,
        );
      } else {
        await ReceiptExportService.shareReceiptText(
          context: context,
          title: widget.title,
          subtitle: widget.subtitle,
          status: widget.status,
          fields: widget.fields,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconBg = _isSuccess
        ? const Color(0xFFACE7BE)
        : (_isPending ? const Color(0xFFFFE8B3) : const Color(0xFFFECACA));
    final iconColor = _isSuccess
        ? const Color(0xFF16A34A)
        : (_isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626));
    final statusLabel = _isSuccess
        ? 'Successful'
        : (_isPending ? 'Pending' : 'Failed');
    final statusPillColor = _isSuccess
        ? const Color(0xFFD1FADF)
        : (_isPending ? const Color(0xFFFFF4CC) : const Color(0xFFFEE2E2));

    const border = Color(0xFFE8EBF4);
    const softText = Color(0xFF6B7280);
    const deepText = Color(0xFF0F172A);

    final receiptTime = _fieldValue('Time');
    final receiptRef = _fieldValue('Reference');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _receiptCaptureKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Opacity(
                          opacity: 0.08,
                          child: Image.asset(
                            'assets/brand/axisvtu-icon.png',
                            width: 60,
                            height: 60,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/brand/axisvtu-icon.png',
                                  width: 20,
                                  height: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'AxisVTU Transfer Receipt',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: deepText,
                                  ),
                                ),
                                const Spacer(),
                                if (receiptTime.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      receiptTime,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: softText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isSuccess
                                  ? Icons.check_rounded
                                  : (_isPending
                                        ? Icons.hourglass_top_rounded
                                        : Icons.close_rounded),
                              color: iconColor,
                              size: 46,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: deepText,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: softText),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 22,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Transfer Receipt',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: deepText,
                                            ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusPillColor,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: iconColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: border, height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    10,
                                  ),
                                  child: Column(
                                    children: widget.fields
                                        .map(
                                          (field) => _ReceiptRow(
                                            label: field.label,
                                            value: field.value,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Fast • Secure • Smart',
                                style: TextStyle(
                                  color: softText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              if (receiptRef.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '•',
                                  style: TextStyle(color: softText),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    receiptRef,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: softText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 14),
                widget.footer!,
              ] else ...[
                const SizedBox(height: 12),
                _ResultToggleRow(
                  icon: Icons.group_outlined,
                  title: 'Beneficiaries',
                  value: _beneficiaries,
                  onChanged: (value) => setState(() => _beneficiaries = value),
                ),
                const SizedBox(height: 10),
                _ResultToggleRow(
                  icon: Icons.bolt_rounded,
                  title: 'Axis Bolt',
                  value: _axisBolt,
                  onChanged: (value) => setState(() => _axisBolt = value),
                ),
              ],
              const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EBF4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultToggleRow extends StatelessWidget {
  const _ResultToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch.adaptive(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
