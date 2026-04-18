import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/receipt_export_service.dart';

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
    this.autoShareOnOpen = false,
  });

  final String status;
  final String title;
  final String subtitle;
  final List<ReceiptField> fields;
  final Widget? footer;
  final bool autoShareOnOpen;

  @override
  State<PurchaseResultSheet> createState() => _PurchaseResultSheetState();
}

class _PurchaseResultSheetState extends State<PurchaseResultSheet> {
  final GlobalKey _receiptCaptureKey = GlobalKey();

  bool _downloading = false;
  bool _sharing = false;
  bool _autoShareTriggered = false;

  bool get _busy => _downloading || _sharing;
  bool get _isSuccess => widget.status.toLowerCase() == 'success';
  bool get _isPending => widget.status.toLowerCase() == 'pending';

  @override
  void initState() {
    super.initState();
    if (widget.autoShareOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoShareTriggered) return;
        _autoShareTriggered = true;
        _shareReceipt();
      });
    }
  }

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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0D1522) : Colors.white;
    final receiptSurface = isDark ? const Color(0xFF101827) : const Color(0xFFF9FBFF);
    final border = scheme.outline.withValues(alpha: isDark ? 0.10 : 0.06);
    final softText = scheme.onSurface.withValues(alpha: isDark ? 0.66 : 0.58);
    final deepText = scheme.onSurface;

    final iconBg = _isSuccess
        ? const Color(0xFF1F8A4C).withValues(alpha: isDark ? 0.22 : 0.14)
        : (_isPending
              ? const Color(0xFFD97706).withValues(alpha: isDark ? 0.18 : 0.12)
              : const Color(0xFFDC2626).withValues(alpha: isDark ? 0.18 : 0.12));
    final iconColor = _isSuccess
        ? const Color(0xFF34D399)
        : (_isPending ? const Color(0xFFF59E0B) : const Color(0xFFF87171));
    final statusLabel = _isSuccess ? 'Successful' : (_isPending ? 'Pending' : 'Failed');
    final statusPillColor = _isSuccess
        ? const Color(0xFF1F8A4C).withValues(alpha: isDark ? 0.20 : 0.12)
        : (_isPending
              ? const Color(0xFFD97706).withValues(alpha: isDark ? 0.18 : 0.12)
              : const Color(0xFFDC2626).withValues(alpha: isDark ? 0.18 : 0.12));

    final receiptTime = _fieldValue('Time');
    final receiptRef = _fieldValue('Reference');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                    color: receiptSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Opacity(
                          opacity: isDark ? 0.04 : 0.06,
                          child: Image.asset(
                            'assets/brand/axisvtu-icon.png',
                            width: 54,
                            height: 54,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
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
                                Expanded(
                                  child: Text(
                                    'AxisVTU Receipt',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.05,
                                      color: deepText,
                                    ),
                                  ),
                                ),
                                if (receiptTime.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      receiptTime,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: softText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.96, end: 1),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                            child: Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
                              child: Icon(
                                _isSuccess
                                    ? Icons.check_rounded
                                    : (_isPending ? Icons.hourglass_top_rounded : Icons.close_rounded),
                                color: iconColor,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: deepText,
                              letterSpacing: -0.18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: softText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long, size: 16),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Transaction summary',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: deepText,
                                ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusPillColor,
                                          border: Border.all(
                                            color: iconColor.withValues(alpha: 0.18),
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: iconColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(color: border, height: 1),
                                Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                          if (receiptRef.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              receiptRef,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: softText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 12),
                widget.footer!,
              ],
              const SizedBox(height: 10),
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
                      label: const Text('Download'),
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
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Done'),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
