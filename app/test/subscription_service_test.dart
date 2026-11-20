import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.instance.resetForTest();
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

  test('initialize without Superwall keeps local flag behavior', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    expect(sub.billingReady, isFalse);
    expect(await sub.isPro(), isFalse);
    await sub.setPro(true);
    expect(await sub.isPro(), isTrue);
    expect(sub.proListenable.value, isTrue);
  });

  test('buy without configuration reports unavailable', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    await sub.buyPro('premium_pro_weekly');
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('not available'));
    expect(sub.purchasePending.value, isFalse);
  });

  test('restore without configuration reports unavailable', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    await sub.restore();
    expect(await sub.isPro(), isFalse);
    expect(sub.notice.value, contains('not available'));
    expect(sub.purchasePending.value, isFalse);
  });

  test('price falls back without configuration', () async {
    final sub = SubscriptionService.instance;
    await sub.initialize();
    expect(await sub.priceLabel('premium_pro_weekly'), '\$6.99');
  });
}
