import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'local_game_service.dart';

/// Builds a ready invite text + opens WhatsApp / Telegram / Instagram / system share.
///
/// Deep-link patterns (community + official docs):
/// - WhatsApp: https://wa.me/?text=ENCODED  (also whatsapp://send?text=)
/// - Telegram: https://t.me/share/url?url=…&text=…
/// - Instagram: no reliable prefill for DMs → copy text + open app
/// - System: share_plus (native sheet / Web Share API on web)
class InviteShareService {
  InviteShareService._();
  static final InviteShareService instance = InviteShareService._();

  static const String appStoreFallback = 'https://hidavo.app';

  Future<InvitePayload> buildPayload() async {
    final username = await LocalGameService.instance.getUsername();
    final name = await LocalGameService.instance.getPlayerName();
    final handle = (username != null && username.isNotEmpty) ? username : 'friend';
    final link = '$appStoreFallback/invite/$handle';

    final who = (name != null && name.isNotEmpty) ? name : handle;
    final message = '''Hey — it's $who.

I play Hidavo, a short quiz: name people you know and answer “who among these?”.
Your answers stay on your phone. Nobody sees who you picked.

Try it: $link''';

    return InvitePayload(
      username: handle,
      displayName: who,
      link: link,
      message: message,
    );
  }

  Future<void> shareWhatsApp() async {
    final p = await buildPayload();
    final text = Uri.encodeComponent(p.message);
    // Universal https link works on mobile + desktop web (opens app or web.whatsapp)
    final uri = Uri.parse('https://wa.me/?text=$text');
    final ok = await _launch(uri);
    if (!ok) {
      // Fallback scheme (mobile)
      await _launch(Uri.parse('whatsapp://send?text=$text'));
    }
  }

  Future<void> shareTelegram() async {
    final p = await buildPayload();
    // Official share endpoint: prefilled text + url
    final uri = Uri.parse(
      'https://t.me/share/url'
      '?url=${Uri.encodeComponent(p.link)}'
      '&text=${Uri.encodeComponent(p.message)}',
    );
    await _launch(uri);
  }

  /// Instagram has no public API to prefill a DM. Standard approach used by
  /// apps: copy ready message → open Instagram so user pastes into Direct/Story.
  Future<InstagramShareResult> shareInstagram() async {
    final p = await buildPayload();
    await Clipboard.setData(ClipboardData(text: p.message));

    // Try native app first, then web
    final appUri = Uri.parse('instagram://app');
    final webUri = Uri.parse('https://www.instagram.com/');
    final opened = await _launch(appUri) || await _launch(webUri);
    return InstagramShareResult(copied: true, openedApp: opened);
  }

  /// System share sheet — picks any app (WA, TG, Messages, Mail, …).
  Future<void> shareEverywhere() async {
    final p = await buildPayload();
    await SharePlus.instance.share(
      ShareParams(
        text: p.message,
        subject: 'Invite to Hidavo',
      ),
    );
  }

  Future<void> copyMessage() async {
    final p = await buildPayload();
    await Clipboard.setData(ClipboardData(text: p.message));
  }

  Future<void> copyLink() async {
    final p = await buildPayload();
    await Clipboard.setData(ClipboardData(text: p.link));
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
  final String username;
  final String displayName;
  final String link;
  final String message;

  const InvitePayload({
    required this.username,
    required this.displayName,
    required this.link,
    required this.message,
  });
}

class InstagramShareResult {
  final bool copied;
  final bool openedApp;

  const InstagramShareResult({
    required this.copied,
    required this.openedApp,
  });
}
