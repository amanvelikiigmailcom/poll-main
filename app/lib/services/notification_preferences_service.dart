import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'subscription_service.dart';

const notificationCategories = <String, String>{
  'votes': 'New quiz results',
  'invitations': 'Invitations',
  'friends': 'Friend requests and acceptances',
  'premium': 'Premium subscription',
  'reminders': 'Reminders after 1, 3 and 7 days',
  'moderation': 'Account moderation updates',
};

class NotificationPreferencesService extends ChangeNotifier {
  NotificationPreferencesService(
    this.api,
    this.storage, {
    Future<void> Function()? requestReview,
    Future<String> Function()? timezone,
  }) : _requestReview = requestReview ?? _nativeReview,
       _timezone = timezone ?? _nativeTimezone {
    storage.addListener(_accountChanged);
  }
  final ApiService api;
  final StorageService storage;
  final Future<void> Function() _requestReview;
  final Future<String> Function() _timezone;
  Map<String, bool>? preferences;
  bool _disposed = false;
  bool _activityBusy = false;
  static const channel = MethodChannel('flyprox/app_info');
  static Future<void> _nativeReview() async {
    await channel.invokeMethod<void>('requestReview');
  }

  static Future<String> _nativeTimezone() async {
    try {
      return await channel.invokeMethod<String>('getTimezone') ?? 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _accountChanged() {
    preferences = null;
    SubscriptionService.instance.bindNotificationBillingIdentity(null);
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    storage.removeListener(_accountChanged);
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in to manage notifications.',
        statusCode: 401,
      );
    }
    try {
      final r = await api.dio.request<Map<String, dynamic>>(
        '/api/notifications$path',
        data: data,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Account changed. Please try again.',
          statusCode: 409,
        );
      }
      return r.data ?? {};
    } on DioException catch (e) {
      if (await storage.getToken() != token) {
        throw const ApiException(
          'Account changed. Please try again.',
          statusCode: 409,
        );
      }
      throw ApiException(
        e.response?.data is Map
            ? e.response!.data['message']?.toString() ??
                  'Couldn’t save notification settings.'
            : 'Couldn’t connect. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, bool>> load() async {
    final data = await _call('/settings');
    final raw = data['preferences'];
    if (raw is! Map ||
        !notificationCategories.keys.every((key) => raw[key] is bool)) {
      throw const ApiException('Incomplete notification settings. Try again.');
    }
    preferences = {
      for (final key in notificationCategories.keys) key: raw[key] as bool,
    };
    _changed();
    return Map.of(preferences!);
  }

  Future<void> save(Map<String, bool> values) async {
    final data = await _call(
      '/settings',
      method: 'PUT',
      data: {
        'preferences': values,
        'timezone': await _timezone(),
        'locale': 'en',
      },
    );
    final raw = data['preferences'];
    if (raw is! Map ||
        !notificationCategories.keys.every((key) => raw[key] is bool)) {
      throw const ApiException('Incomplete notification settings. Try again.');
    }
    preferences = {
      for (final key in notificationCategories.keys) key: raw[key] as bool,
    };
    _changed();
  }

  Future<void> recordActivityAndReview() async {
    if (_activityBusy) return;
    _activityBusy = true;
    final token = await storage.getToken();
    try {
      if (token == null || token.isEmpty) return;
      final data = await _call(
        '/activity',
        method: 'POST',
        data: {'timezone': await _timezone(), 'locale': 'en'},
      );
      if (await storage.getToken() != token) return;
      final billingId = data['billingId'];
      if (billingId is String) {
        await SubscriptionService.instance.bindNotificationBillingIdentity(
          billingId,
        );
      }
      if (await storage.getToken() != token) return;
      final result = await _call('/review/claim', method: 'POST');
      if (result['requestReview'] == true &&
          await storage.getToken() == token) {
        // Server claims the one attempt before showing Apple's system prompt.
        // Apple may choose not to display it; never force a review or repeat.
        await _requestReview();
      }
    } catch (_) {
      /* Offline, unavailable rollout or denied native UI: retry activity on resume. */
    } finally {
      _activityBusy = false;
    }
  }
}
