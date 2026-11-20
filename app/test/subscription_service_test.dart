import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/billing_gateway.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';

import 'fakes/fake_gateway.dart';

Future<void> _settleForPro() async {
  final sub = SubscriptionService.instance;
  for (var i = 0; i < 100 && !await sub.isPro(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _settleListenable(bool want) async {
  final sub = SubscriptionService.instance;
  for (var i = 0; i < 100 && sub.proListenable.value != want; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = FakeGateway();
    final sub = SubscriptionService.instance;
    await sub.resetForTest();
    sub.debugGateway(fake);
  });

  tearDown(() async {
    await fake.events.close();
  });

  test('premium flag is off by default and can be enabled', () async {
    final sub = SubscriptionService.instance;
    expect(await sub.isPro(), isFalse);
    await sub.setPro(true, productId: 'premium_pro_weekly');
    expect(await sub.isPro(), isTrue);
    await sub.setPro(false);
    expect(await sub.isPro(), isFalse);
  });

  test('reset game keeps the premium purchase', () async {
    final sub = SubscriptionService.instance;
    await sub.setPro(true, productId: 'premium_pro_weekly');
    await LocalGameService.instance.clearAll();
    expect(await sub.isPro(), isTrue);
  });

  test('purchased event grants Pro with success notice', () async {
    final sub = SubscriptionService.instance;
    fake.entitlements = {'pro'};
    await sub.buyPro('premium_pro_weekly');
    await _settleForPro();
    expect(await sub.isPro(), isTrue);
    expect(sub.proListenable.value, isTrue);
    expect(sub.notice.value, contains('activated'));
    expect(sub.purchasePending.value, isFalse);
  });

  test('cancelled purchase stays free with notice', () async {
    final sub = SubscriptionService.instance;
    fake.buyResult = const BuyResult(BuyOutcome.cancelled);
    await sub.buyPro('premium_pro_weekly');
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('canceled'));
    expect(sub.purchasePending.value, isFalse);
  });

  test('failed purchase stays free with error notice', () async {
    final sub = SubscriptionService.instance;
    fake.buyResult = const BuyResult(BuyOutcome.failed, error: 'store down');
    await sub.buyPro('premium_pro_weekly');
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('store down'));
    expect(sub.purchasePending.value, isFalse);
  });

  test('pending purchase stays free with notice', () async {
    final sub = SubscriptionService.instance;
    fake.buyResult = const BuyResult(BuyOutcome.pending);
    await sub.buyPro('premium_pro_weekly');
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('pending'));
  });

  test('restore with entitlement grants Pro', () async {
    final sub = SubscriptionService.instance;
    fake.entitlements = {'pro'};
    await sub.restore();
    await _settleForPro();
    expect(await sub.isPro(), isTrue);
    expect(sub.notice.value, contains('restored'));
    expect(fake.restoreCalled, isTrue);
  });

  test('restore without entitlement reports nothing found', () async {
    final sub = SubscriptionService.instance;
    await sub.restore();
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('No purchases found'));
  });

  test('price uses live value with fallback', () async {
    final sub = SubscriptionService.instance;
    fake.price = '₸3 290';
    expect(await sub.priceLabel('premium_pro_weekly'), '₸3 290');
    fake.price = null;
    expect(await sub.priceLabel('premium_pro_weekly'), '\$6.99');
  });

  test('unconfigured backend degrades gracefully', () async {
    final sub = SubscriptionService.instance;
    fake.configured = false;
    await sub.initialize();
    expect(sub.billingReady, isFalse);
    await sub.buyPro('premium_pro_weekly');
    expect(sub.notice.value, contains('not available'));
    await sub.restore();
    expect(sub.notice.value, contains('not available'));
    expect(await sub.priceLabel('premium_pro_weekly'), '\$6.99');
    expect(await sub.isPro(), isFalse);
  });

  test('billing recovers when backend becomes available', () async {
    final sub = SubscriptionService.instance;
    fake.configured = false;
    await sub.buyPro('premium_pro_weekly');
    expect(sub.notice.value, contains('not available'));
    fake.configured = true;
    fake.entitlements = {'pro'};
    await sub.buyPro('premium_pro_weekly');
    await _settleForPro();
    expect(await sub.isPro(), isTrue);
    expect(sub.notice.value, contains('activated'));
  });

  test('entitlement stream updates Pro live', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    fake.events.add({'pro'});
    await _settleListenable(true);
    expect(sub.proListenable.value, isTrue);
    fake.events.add(<String>{});
    await _settleListenable(false);
    expect(sub.proListenable.value, isFalse);
  });

  test('local override grants Pro without backend', () async {
    final sub = SubscriptionService.instance;
    fake.configured = false;
    await sub.initialize();
    await sub.setPro(true);
    expect(await sub.isPro(), isTrue);
  });

  test('resetUser clears install id and resets backend', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    expect(fake.identifyCalled, isTrue);
    final before = await sub.debugInstallId();
    expect(before, isNot('not set'));
    await sub.resetUser();
    expect(fake.resetCalled, isTrue);
    final after = await sub.debugInstallId();
    expect(after, isNot('not set'));
    expect(after, isNot(before));
  });
}
