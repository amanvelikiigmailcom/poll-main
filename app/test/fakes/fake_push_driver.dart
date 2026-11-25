import 'dart:async';

import 'package:flyprox_app/services/push_driver.dart';

/// Scripted push plumbing: permission results, tokens and message streams.
class FakePushDriver implements PushDriver {
  FakePushDriver({
    this.available = true,
    this.authorized = false,
    this.grantOnRequest = true,
    this.token = 'apns-token-1',
  });

  bool available;
  bool authorized;
  bool grantOnRequest;
  String? token;

  final tokenRefresh = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushTap>.broadcast();
  PushTap? initialTap;
  bool tapArmed = false;
  int requestCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    if (grantOnRequest) authorized = true;
    return authorized;
  }

  @override
  Future<String?> getDeviceToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => messages.stream;

  @override
  Stream<PushTap> get onPushTap => taps.stream;

  @override
  Future<PushTap?> getInitialTap() async {
    final tap = initialTap;
    initialTap = null;
    return tap;
  }

  @override
  Future<void> setTapArmed(bool value) async {
    tapArmed = value;
  }

  void dispose() {
    tokenRefresh.close();
    messages.close();
    taps.close();
  }
}
