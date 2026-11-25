import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'push_driver.dart';

/// Production driver: Firebase SDK only as a token pipe. Sending is done by
/// our backend through Appwrite Messaging, never through FCM.
class FirebasePushDriver implements PushDriver {
  FirebaseMessaging get _msg => FirebaseMessaging.instance;

  @override
  bool get isAvailable {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      FirebaseMessaging.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAuthorized() async {
    try {
      final s = await _msg.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final s = await _msg.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      final token = await _msg.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      // APNs registration can finish after the permission dialog closes.
      for (var attempt = 0; attempt < 5; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final ready = await _msg.getAPNSToken();
        if (ready != null && ready.isNotEmpty) return ready;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh {
    try {
      return _msg.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  // FlutterFire emits only FCM payloads here. Plain Appwrite/APNs alerts are
  // presented by iOS using the options configured at Firebase startup.
  @override
  Stream<PushMessage> get onForegroundMessage {
    try {
      return FirebaseMessaging.onMessage.map((m) => PushMessage(
            title: m.notification?.title?.trim() ?? '',
            body: m.notification?.body?.trim() ?? '',
          ));
    } catch (_) {
      return const Stream.empty();
    }
  }

  static const _tapChannel = MethodChannel('flyprox/push_tap');
  final _taps = StreamController<PushTap>.broadcast();
  bool _tapHandlerSet = false;

  void _ensureTapHandler() {
    if (_tapHandlerSet) return;
    _tapHandlerSet = true;
    _tapChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPushTap' && call.arguments is String) {
        final type = (call.arguments as String).trim();
        if (type.isNotEmpty) _taps.add(PushTap(type));
      }
    });
  }

  @override
  Stream<PushTap> get onPushTap {
    try {
      _ensureTapHandler();
      return _taps.stream;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<PushTap?> getInitialTap() async {
    try {
      final type = await _tapChannel.invokeMethod<String>('getInitialPush');
      final trimmed = type?.trim() ?? '';
      return trimmed.isEmpty ? null : PushTap(trimmed);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setTapArmed(bool armed) async {
    try {
      _ensureTapHandler();
      await _tapChannel.invokeMethod<void>('setArmed', armed);
    } catch (_) {}
  }
}
