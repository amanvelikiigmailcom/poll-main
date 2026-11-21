/// A foreground push, already mapped to plain strings.
class PushMessage {
  final String title;
  final String body;

  const PushMessage({required this.title, required this.body});
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
}
