import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../services/receipt_export_service.dart';
import 'interactive_notification_banner.dart';

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
  bool get _isSuccess {
    final s = widget.status.toLowerCase();
    return s == 'success' || s == 'successful' || s == 'delivered' || s == 'completed' || s == 'order_completed';
  }
  bool get _isPending => widget.status.toLowerCase() == 'pending';

  @override
  void initState() {
    super.initState();
    if (_isSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        InteractiveNotificationBanner.show(
          context,
          title: 'MELE DATA',
          message: widget.subtitle.isNotEmpty ? widget.subtitle : '${widget.title} transaction was successful.',
        );
      });
    }
    if (widget.autoShareOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoShareTriggered) return;
        _autoShareTriggered = true;
        _shareReceipt();
      });
    }
  }

  Future<Uint8List?> _captureReceiptImage() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final renderObject = _receiptCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final image = await renderObject.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _downloadReceipt() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
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
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
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
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              RepaintBoundary(
                key: _receiptCaptureKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSuccess 
                            ? [const Color(0xFF2463EB), const Color(0xFF3B82F6)] 
                            : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Image.asset(
                              'assets/brand/meledata-logo.png',
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => Icon(
                                _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, 
                                color: _isSuccess ? const Color(0xFF2463EB) : const Color(0xFF64748B), 
                                size: 32
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Transaction Receipt',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isSuccess 
                                  ? const Color(0xFFDCFCE7) 
                                  : (_isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSuccess ? Icons.check_circle : (_isPending ? Icons.access_time_filled : Icons.cancel),
                                    color: _isSuccess ? const Color(0xFF166534) : (_isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSuccess ? 'Successful' : (_isPending ? 'Pending' : 'Failed'),
                                    style: TextStyle(
                                      color: _isSuccess ? const Color(0xFF166534) : (_isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...widget.fields.map((f) => _ReceiptTableItem(label: f.label, value: f.value, bold: f.label == 'Amount')),
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 24),
                          const Text(
                            'meledata.ng',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size(double.infinity, 20),
                      painter: _ZigZagPainter(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _downloadReceipt,
                      icon: _downloading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _shareReceipt,
                      icon: _sharing 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2463EB),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptTableItem extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ReceiptTableItem({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.withValues(alpha: 0.1)),
        ],
      ),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    double x = 0;
    const dashWidth = 12.0;
    const dashHeight = 10.0;
    while (x < size.width) {
      path.lineTo(x + dashWidth / 2, dashHeight);
      path.lineTo(x + dashWidth, 0);
      x += dashWidth;
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
