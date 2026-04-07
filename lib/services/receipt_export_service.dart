import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/purchase_result_sheet.dart';

class ReceiptExportService {
  static String buildReceiptText({
    required String title,
    required String subtitle,
    required String status,
    required List<ReceiptField> fields,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('AXISVTU TRANSACTION RECEIPT');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Title: $title');
    buffer.writeln('Status: ${status.toUpperCase()}');
    buffer.writeln('Note: $subtitle');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('----------------------------------------');
    for (final field in fields) {
      final label = field.label.trim().isEmpty ? 'Field' : field.label.trim();
      final value = field.value.trim().isEmpty ? '-' : field.value.trim();
      buffer.writeln('$label: $value');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('AxisVTU - Fast • Secure • Smart');
    return buffer.toString();
  }

  static String inferReference(List<ReceiptField> fields) {
    for (final field in fields) {
      if (field.label.trim().toLowerCase() == 'reference') {
        final ref = field.value.trim();
        if (ref.isNotEmpty) return ref;
      }
    }
    return 'axisvtu_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static String inferReceiptImageFilename(List<ReceiptField> fields) {
    final reference = inferReference(fields);
    return 'axisvtu_receipt_${_sanitize(reference)}.png';
  }

  static Future<void> downloadReceiptImage({
    required BuildContext context,
    required Uint8List imageBytes,
    required List<ReceiptField> fields,
  }) async {
    final filename = inferReceiptImageFilename(fields);
    final file = XFile.fromData(
      imageBytes,
      mimeType: 'image/png',
      name: filename,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          subject: 'AxisVTU Receipt',
          text: 'Save your AxisVTU receipt image.',
          fileNameOverrides: [filename],
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt image ready. Save to Files / Downloads.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save image receipt.')),
      );
    }
  }

  static Future<void> shareReceiptImage({
    required BuildContext context,
    required Uint8List imageBytes,
    required List<ReceiptField> fields,
  }) async {
    final filename = inferReceiptImageFilename(fields);
    final file = XFile.fromData(
      imageBytes,
      mimeType: 'image/png',
      name: filename,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          subject: 'AxisVTU Receipt',
          text: 'AxisVTU receipt.',
          fileNameOverrides: [filename],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share image receipt.')),
      );
    }
  }

  static Future<void> downloadReceiptAsFile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required List<ReceiptField> fields,
  }) async {
    final text = buildReceiptText(
      title: title,
      subtitle: subtitle,
      status: status,
      fields: fields,
    );
    final reference = inferReference(fields);
    final filename = 'axisvtu_receipt_${_sanitize(reference)}.txt';
    final bytes = Uint8List.fromList(utf8.encode(text));
    final file = XFile.fromData(bytes, mimeType: 'text/plain', name: filename);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          subject: 'AxisVTU Receipt',
          text: 'Download and save your receipt file.',
          fileNameOverrides: [filename],
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Receipt file ready. Choose Save to Files / Downloads.',
          ),
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt copied to clipboard (file save unavailable).'),
        ),
      );
    }
  }

  static Future<void> shareReceiptText({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required List<ReceiptField> fields,
  }) async {
    final text = buildReceiptText(
      title: title,
      subtitle: subtitle,
      status: status,
      fields: fields,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'AxisVTU Receipt'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt copied to clipboard.')),
      );
    }
  }
}
