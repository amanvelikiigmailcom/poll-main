import 'dart:async';

import 'package:flyprox_app/services/billing_gateway.dart';

/// Scripted billing backend: proves the service logic end to end without
/// touching any store SDK. Widget tests must never reach the real SDK:
/// its platform channel has no native side here and never settles.
class FakeGateway implements BillingGateway {
  bool configured = true;
  Set<String> entitlements = {};
  Future<Set<String>> Function()? entitlementsHandler;
  String? price;
  BuyResult buyResult = const BuyResult(BuyOutcome.purchased);
  bool identifyCalled = false;
  bool resetCalled = false;
  bool restoreCalled = false;
  Object? identifyError;
  int buyCalls = 0;
  final events = StreamController<Set<String>>.broadcast();

  @override
  Future<bool> isConfigured() async => configured;

  @override
  Future<void> identify(String installId) async {
    identifyCalled = true;
    if (identifyError != null) throw identifyError!;
  }

  @override
  Stream<Set<String>> watchActiveEntitlements() => events.stream;

  @override
  Future<Set<String>> activeEntitlements() async =>
      entitlementsHandler == null ? entitlements : await entitlementsHandler!();

  @override
  Future<String?> priceFor(String productId) async => price;

  @override
  Future<BuyResult> buy(String productId) async {
    buyCalls++;
    return buyResult;
  }

  @override
  Future<void> restore() async {
    restoreCalled = true;
  }

  @override
  Future<void> reset() async {
    resetCalled = true;
  }
}
