import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shares a short, text-only invite. No website or referral link is required.
/// Instagram and Telegram use copy-and-open so no URL is added to the message.
class InviteShareService {
  InviteShareService._();
  static final InviteShareService instance = InviteShareService._();

  Future<InvitePayload> buildPayload() async {
    return const InvitePayload(
      message: 'Try Flyprox — fun quizzes about people you know!',
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

  Future<ClipboardShareResult> shareTelegram() async {
    await copyMessage();
    final opened = await _launch(Uri.parse('tg://')) ||
        await _launch(Uri.parse('https://web.telegram.org/'));
    return ClipboardShareResult(copied: true, openedApp: opened);
  }

  /// Instagram has no public API to prefill a DM. Standard approach used by
  /// apps: copy ready message → open Instagram so user pastes into Direct/Story.
  Future<ClipboardShareResult> shareInstagram() async {
    final p = await buildPayload();
    await Clipboard.setData(ClipboardData(text: p.message));

    // Try native app first, then web
    final appUri = Uri.parse('instagram://app');
    final webUri = Uri.parse('https://www.instagram.com/');
    final opened = await _launch(appUri) || await _launch(webUri);
    return ClipboardShareResult(copied: true, openedApp: opened);
  }

  /// System share sheet — picks any app (WA, TG, Messages, Mail, …).
  Future<void> shareEverywhere() async {
    final p = await buildPayload();
    await SharePlus.instance.share(
      ShareParams(
        text: p.message,
        subject: 'Invite to Flyprox',
      ),
    );
  }

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

class ClipboardShareResult {
  final bool copied;
  final bool openedApp;

  const ClipboardShareResult({
    required this.copied,
    required this.openedApp,
  });
}
