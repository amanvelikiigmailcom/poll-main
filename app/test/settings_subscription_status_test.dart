import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.instance.resetForTest();
    gateway = FakeGateway();
    SubscriptionService.instance.debugGateway(gateway);
  });
  tearDown(() async {
    await SubscriptionService.instance.resetForTest();
    await gateway.events.close();
  });

  Future<void> openStatus(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSubscriptionStatusDialog(context),
              child: const Text('Status'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'status refreshes stale uninitialized SDK state before reporting free access',
    (tester) async {
      expect(SubscriptionService.instance.billingReady, isFalse);
      await openStatus(tester);
      expect(gateway.identifyCalled, isTrue);
      expect(
        find.textContaining('You are using the free version'),
        findsOneWidget,
      );
      expect(find.textContaining('User ID'), findsNothing);
      expect(find.textContaining('not connected'), findsNothing);
    },
  );

  testWidgets('SDK failure is not displayed as an inactive subscription', (
    tester,
  ) async {
    gateway.entitlementsHandler = () async =>
        throw StateError('temporary store failure');
    await openStatus(tester);
    expect(
      find.textContaining('couldn’t check your subscription'),
      findsOneWidget,
    );
    expect(find.textContaining('free version'), findsNothing);
  });

  test(
    'failed entitlement refresh preserves previously known paid access',
    () async {
      gateway.entitlements = {'pro'};
      await SubscriptionService.instance.initialize();
      expect(await SubscriptionService.instance.isPro(), isTrue);
      gateway.entitlementsHandler = () async => throw StateError('offline');
      await SubscriptionService.instance.refresh();
      expect(await SubscriptionService.instance.isPro(), isTrue);
      expect(SubscriptionService.instance.statusAvailable, isFalse);
    },
  );
}
