/// A foreground push, already mapped to plain strings.
class PushMessage {
  final String title;
  final String body;

  const PushMessage({required this.title, required this.body});
}

/// A user tap on a push, mapped to its backend type.
class PushTap {
  final String type;

  const PushTap(this.type);
}

/// Push plumbing behind a seam tests can fake. Tokens go to our backend,
/// which sends through Appwrite Messaging (APNs provider).
abstract class PushDriver {
  /// Whether push can run here (real device build with messaging support).
  bool get isAvailable;

  /// Whether the OS already granted notification permission.
  Future<bool> isAuthorized();

  /// Shows the OS permission prompt. True when granted.
  Future<bool> requestPermission();

  /// Raw APNs device token on iOS; null when unavailable.
  Future<String?> getDeviceToken();

  /// Fires when the token changes; re-read it via [getDeviceToken].
  Stream<String> get onTokenRefresh;

  /// Messages arriving while the app is open.
  Stream<PushMessage> get onForegroundMessage;

  /// Taps on pushes delivered while the shell is mounted and taps are armed.
  /// Plain APNs taps arrive through the native bridge. Never throws.
  Stream<PushTap> get onPushTap;

  /// Consumes the tap that launched the app (or arrived before the shell
  /// mounted). Null when none. Never throws.
  Future<PushTap?> getInitialTap();

  /// Enables live tap delivery once a navigation shell is mounted.
  Future<void> setTapArmed(bool armed);
}
