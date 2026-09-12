import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StartupPopupDialog extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const StartupPopupDialog({super.key, required this.announcement});

  static Future<void> show(BuildContext context, Map<String, dynamic> announcement) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartupPopupDialog(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (announcement['title'] ?? '').toString();
    final message = (announcement['message'] ?? '').toString();
    final imageUrl = (announcement['image_url'] ?? '').toString();
    final buttonLabel = (announcement['button_label'] ?? '').toString();
    final buttonLink = (announcement['button_link'] ?? '').toString();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl.isNotEmpty)
            Flexible(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (message.isNotEmpty)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 32),
                if (buttonLabel.isNotEmpty && buttonLink.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(buttonLink);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
