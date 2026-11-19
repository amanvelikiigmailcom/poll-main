import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
