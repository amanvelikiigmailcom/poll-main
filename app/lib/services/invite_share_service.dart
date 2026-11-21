import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content_service.dart';

/// Shares a short, text-only invite. No website or referral link is required.
/// Instagram opens its recipient picker with a short greeting and no URL.
class InviteShareService {
  InviteShareService._();
  static final InviteShareService instance = InviteShareService._();

  Future<InvitePayload> buildPayload() async {
    return InvitePayload(
      message: ContentService.instance.text('invite_message'),
    );
  }

  Future<bool> shareWhatsApp() async {
    final p = await buildPayload();
    final text = Uri.encodeComponent(p.message);
    // Universal https link works on mobile + desktop web (opens app or web.whatsapp)
    final uri = Uri.parse('https://wa.me/?text=$text');
    final ok = await _launch(uri);
    if (!ok) {
      // Fallback scheme (mobile)
      return _launch(Uri.parse('whatsapp://send?text=$text'));
    }
    return true;
  }

  /// Undocumented Instagram route, verified by the user on their iPhone.
  /// Opening it does not confirm that the user sent a message.
  Future<bool> shareInstagram() =>
      _launch(Uri.parse('instagram://sharesheet?text=Hi%21'));

  Future<void> copyMessage() async {
    final p = await buildPayload();
    await Clipboard.setData(ClipboardData(text: p.message));
  }

  Future<bool> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(
          uri,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
      }
      // Still try — some platforms return false for canLaunch but open fine
      return launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

class InvitePayload {
  final String message;

  const InvitePayload({required this.message});
}
