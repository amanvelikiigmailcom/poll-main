import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'push_driver.dart';

/// Push lifecycle: one-time pre-prompt, permission, token upload to our
/// backend, refresh re-uploads. All entry points are total (bool results).
class PushService {
  static const String _promptSeenKey = 'push_prompt_seen';

  final PushDriver _driver;
  final ApiService _api;

  PushService({required PushDriver driver, required ApiService api})
      : _driver = driver,
        _api = api;

  bool get isAvailable => _driver.isAvailable;

  /// Whether the pre-permission screen should be shown: supported device,
  /// not yet authorized, never asked before.
  Future<bool> needsPrompt() async {
    try {
      if (!isAvailable || await _driver.isAuthorized()) return false;
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_promptSeenKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Asks the system for permission and uploads the token on grant.
  Future<bool> enable() async {
    try {
      (await SharedPreferences.getInstance())
          .setBool(_promptSeenKey, true);
    } catch (_) {}
    if (!isAvailable) return false;
    try {
      if (!await _driver.requestPermission()) return false;
      return syncToken();
    } catch (_) {
      return false;
    }
  }

  /// Uploads the current token when authorized. Never throws.
  Future<bool> syncToken() async {
    try {
      if (!isAvailable || !await _driver.isAuthorized()) return false;
      final token = await _driver.getDeviceToken();
      if (token == null || token.isEmpty) return false;
      await _api.post<void>('/api/devices',
          data: {'token': token, 'platform': 'ios'});
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<PushMessage> get foregroundMessages =>
      _driver.onForegroundMessage;

  /// Re-uploads the token whenever Firebase rotates it.
  StreamSubscription<void> startTokenRefreshSync() =>
      _driver.onTokenRefresh.listen((_) => syncToken());
}
