import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/receipt_export_service.dart';
import 'purchase_result_sheet.dart' show ReceiptField;

/// Bank-Grade Transfer Receipt Modal
/// Styled like top-tier global fintechs (OPay, Moniepoint, GTBank).
/// Includes Transaction Status, Beneficiary Details, Day/Date/Time,
/// 30-digit NIBSS/Paystack Session ID, Reference, and One-Tap Share/Save.
class BankStandardReceiptModal extends StatefulWidget {
  final bool isSuccess;
  final String amount;
  final String fee;
  final String totalDebited;
  final String beneficiaryName;
  final String destinationBank;
  final String accountNumber;
  final String? senderName;
  final String? narration;
  final String reference;
  final String? providerReference;
  final String? sessionId;
  final DateTime? timestamp;
  final String? message;
  final VoidCallback? onClose;

  const BankStandardReceiptModal({
    super.key,
    required this.isSuccess,
    required this.amount,
    required this.fee,
    required this.totalDebited,
    required this.beneficiaryName,
    required this.destinationBank,
    required this.accountNumber,
    this.senderName,
    this.narration,
    required this.reference,
    this.providerReference,
    this.sessionId,
    this.timestamp,
    this.message,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isSuccess,
    required String amount,
    required String fee,
    required String totalDebited,
    required String beneficiaryName,
    required String destinationBank,
    required String accountNumber,
    String? senderName,
    String? narration,
    required String reference,
    String? providerReference,
    String? sessionId,
    DateTime? timestamp,
    String? message,
    VoidCallback? onClose,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankStandardReceiptModal(
        isSuccess: isSuccess,
        amount: amount,
        fee: fee,
        totalDebited: totalDebited,
        beneficiaryName: beneficiaryName,
        destinationBank: destinationBank,
        accountNumber: accountNumber,
        senderName: senderName,
        narration: narration,
        reference: reference,
        providerReference: providerReference,
        sessionId: sessionId,
        timestamp: timestamp,
        message: message,
        onClose: onClose,
      ),
    );
  }

  @override
  State<BankStandardReceiptModal> createState() => _BankStandardReceiptModalState();
}

class _BankStandardReceiptModalState extends State<BankStandardReceiptModal> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isExporting = false;

  DateTime get _effectiveTime => widget.timestamp ?? DateTime.now();

  String get _formattedDayDateTime {
    // E.g. Tuesday, 03 Nov 2026 • 06:24:50 AM
    return DateFormat('EEEE, dd MMM yyyy • hh:mm:ss a').format(_effectiveTime);
  }

  String get _effectiveSessionId {
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      return widget.sessionId!;
    }
    // Standard 30-digit NIBSS format fallback if not passed:
    final timeStr = DateFormat('yyMMddHHmmss').format(_effectiveTime);
    final hashDigits = widget.reference.replaceAll(RegExp(r'\D'), '');
    final pad = hashDigits.padRight(12, '9').substring(0, 12);
    return '999992$timeStr$pad';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _shareReceipt() async {
    HapticFeedback.mediumImpact();
    final text = '''
*MELE DATA - TRANSACTION RECEIPT*
---------------------------------------
Status: ${widget.isSuccess ? 'SUCCESSFUL' : 'FAILED'}
Amount: ${widget.amount}
Beneficiary: ${widget.beneficiaryName}
Bank: ${widget.destinationBank}
Account: ${widget.accountNumber}
Fee: ${widget.fee}
Total Debited: ${widget.totalDebited}
Date & Time: $_formattedDayDateTime
Session ID: $_effectiveSessionId
Reference: ${widget.reference}
Provider Ref: ${widget.providerReference ?? 'N/A'}
Narration: ${widget.narration ?? 'Bank Withdrawal'}
---------------------------------------
Powered by MELE DATA • meledata.ng
''';
    await SharePlus.instance.share(
      ShareParams(
        text: text.trim(),
        subject: 'Transaction Receipt - ${widget.reference}',
      ),
    );
  }

  Future<void> _downloadReceiptImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.lightImpact();

    try {
      final boundary = _receiptBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Receipt capture boundary not ready.');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate image bytes.');
      final bytes = byteData.buffer.asUint8List();

      final fields = [
        ReceiptField(label: 'Amount', value: widget.amount),
        ReceiptField(label: 'Status', value: widget.isSuccess ? 'SUCCESSFUL' : 'FAILED'),
        ReceiptField(label: 'Beneficiary', value: widget.beneficiaryName),
        ReceiptField(label: 'Bank', value: widget.destinationBank),
        ReceiptField(label: 'Account Number', value: widget.accountNumber),
        ReceiptField(label: 'Session ID', value: _effectiveSessionId),
        ReceiptField(label: 'Reference', value: widget.reference),
        ReceiptField(label: 'Date & Time', value: _formattedDayDateTime),
      ];

      if (mounted) {
        await ReceiptExportService.downloadReceiptImage(
          context: context,
          imageBytes: bytes,
          fields: fields,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save image receipt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final successColor = const Color(0xFF10B981);
    final failureColor = const Color(0xFFEF4444);
    final statusColor = widget.isSuccess ? successColor : failureColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Scrollable Receipt Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: RepaintBoundary(
                key: _receiptBoundaryKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MELE DATA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'TRANSFER ADVICE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isSuccess ? 'SUCCESSFUL' : 'FAILED',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Prominent Amount Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TRANSACTION AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.amount,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: statusColor,
                              ),
                            ),
                            if (widget.fee.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Fee: ${widget.fee} • Total Debit: ${widget.totalDebited}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fade().scale(begin: const Offset(0.96, 0.96)),

                      const SizedBox(height: 20),

                      // Dotted Divider
                      _buildDottedDivider(isDark),

                      const SizedBox(height: 18),

                      // Bank-Grade Transaction Details Grid
                      _buildReceiptRow(
                        label: 'Transaction Status',
                        value: widget.isSuccess ? 'Successful' : 'Failed',
                        valueColor: statusColor,
                        isBold: true,
                        isDark: isDark,
                      ),
                      _buildReceiptRow(
                        label: 'Beneficiary Name',
                        value: widget.beneficiaryName.toUpperCase(),
                        isBold: true,
                        isDark: isDark,
                      ),
                      _buildReceiptRow(
                        label: 'Destination Bank',
                        value: widget.destinationBank,
                        isDark: isDark,
                      ),
                      _buildReceiptRow(
                        label: 'Account Number',
                        value: widget.accountNumber,
                        isBold: true,
                        isDark: isDark,
                        onCopy: () => _copyToClipboard(widget.accountNumber, 'Account Number'),
                      ),
                      if (widget.senderName != null && widget.senderName!.isNotEmpty)
                        _buildReceiptRow(
                          label: 'Sender',
                          value: widget.senderName!,
                          isDark: isDark,
                        ),
                      _buildReceiptRow(
                        label: 'Day, Date & Time',
                        value: _formattedDayDateTime,
                        isDark: isDark,
                      ),
                      _buildReceiptRow(
                        label: 'Session ID',
                        value: _effectiveSessionId,
                        isBold: true,
                        isDark: isDark,
                        onCopy: () => _copyToClipboard(_effectiveSessionId, 'Session ID'),
                      ),
                      _buildReceiptRow(
                        label: 'Transaction Reference',
                        value: widget.reference,
                        isDark: isDark,
                        onCopy: () => _copyToClipboard(widget.reference, 'Transaction Reference'),
                      ),
                      if (widget.providerReference != null && widget.providerReference!.isNotEmpty)
                        _buildReceiptRow(
                          label: 'Provider Reference',
                          value: widget.providerReference!,
                          isDark: isDark,
                          onCopy: () => _copyToClipboard(widget.providerReference!, 'Provider Reference'),
                        ),
                      if (widget.narration != null && widget.narration!.isNotEmpty)
                        _buildReceiptRow(
                          label: 'Description',
                          value: widget.narration!,
                          isDark: isDark,
                        ),

                      const SizedBox(height: 14),
                      _buildDottedDivider(isDark),
                      const SizedBox(height: 16),

                      // CBN Compliance & Security Footer Watermark
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Official transfer receipt generated by MELE DATA. Settlement processed via CBN-regulated Nigerian Inter-Bank Settlement channels.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.4,
                                  color: isDark ? Colors.white60 : const Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  // Download Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _downloadReceiptImage,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Share Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareReceipt,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Close Button
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onClose?.call();
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    tooltip: 'Done',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    bool isDark = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onCopy,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 3.5;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
