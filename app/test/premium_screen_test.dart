import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/premium/premium_screen.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'fakes/premium.dart';
import 'fakes/fake_gateway.dart';

void main() {
  setUp(() => ContentService.instance.debugClear());
  tearDown(() => ContentService.instance.debugClear());
  testWidgets(
    'weekly paywall has real reveals, backend remaining counters and no Max/Full Reveal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final subscription = SubscriptionService.instance;
      await subscription.resetForTest();
      final gateway = FakeGateway()..configured = false;
      subscription.debugGateway(gateway);
      ContentService.instance.debugSetOverrides({
        'paywall_features_v3': '["Old badge promise"]',
      });
      final premium = FakePremium()
        ..active = true
        ..full = 1
        ..initial = 4;
      await tester.pumpWidget(
        withPremium(const MaterialApp(home: PremiumScreen()), premium: premium),
      );
      await tester.pumpAndSettle();
      expect(find.text('Premium Weekly'), findsOneWidget);
      expect(find.textContaining('2 full-name reveals'), findsOneWidget);
      expect(
        find.textContaining('5 first-initial reveals'),
        findsOneWidget,
      );
      expect(find.textContaining('Full names: 1 left'), findsOneWidget);
      expect(find.textContaining('Full Reveal'), findsNothing);
      expect(find.textContaining('Old badge promise'), findsNothing);
      expect(find.textContaining('Your votes are protected'), findsOneWidget);
      expect(
        find.textContaining(
          'Protected attempts do not use your weekly reveals.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Blue Premium'), findsNothing);
      expect(find.textContaining('Unlimited'), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('1-week auto-renewing'), findsWidgets);
      expect(find.textContaining('Premium Max'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await subscription.resetForTest();
      await gateway.events.close();
    },
  );
  testWidgets(
    'backend unavailable disables purchase rather than charging for unconfirmed benefits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final subscription = SubscriptionService.instance;
      await subscription.resetForTest();
      final gateway = FakeGateway()..configured = false;
      subscription.debugGateway(gateway);
      final premium = FakePremium()
        ..failure = const ApiException(
          'Benefits are not available yet.',
          statusCode: 503,
        );
      await tester.pumpWidget(
        withPremium(const MaterialApp(home: PremiumScreen()), premium: premium),
      );
      await tester.pumpAndSettle();
      expect(find.text('Benefits are not available yet.'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(gateway.buyCalls, 0);
      await tester.pumpWidget(const SizedBox());
      await subscription.resetForTest();
      await gateway.events.close();
    },
  );
}
