import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open a public information page from a user gesture, with a copy fallback.
Future<void> openExternalLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Couldn’t open the page'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Copy this link and open it in your browser.'),
          const SizedBox(height: 12),
          SelectableText(url),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Copy link'),
        ),
      ],
    ),
  );
}
