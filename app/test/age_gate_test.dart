import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/fake_age_gate_store.dart';
import 'fakes/fake_gateway.dart';

Future<void> mountPremium(WidgetTester tester) async {
  final storage = StorageService();
  await storage.init();
  appRouter.go(AppRoutes.premium);
  await tester.pumpWidget(ProviderScope(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
    child: MaterialApp.router(routerConfig: appRouter),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.instance.resetForTest();
    SubscriptionService.instance.debugGateway(FakeGateway());
    AgeGateService.instance.debugStore(InMemoryAgeGateStore());
    AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
  });

  tearDown(() async {
    await AgeGateService.instance.resetForTest();
    await SubscriptionService.instance.resetForTest();
  });

  testWidgets('unknown age shows the wheel; default choice blocks',
      (tester) async {
    await mountPremium(tester);
    expect(find.text('How old are you?'), findsOneWidget);
    expect(find.text('Selected age: 10'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Not available for your age'), findsOneWidget);
    expect(find.text('How old are you?'), findsNothing);
    expect(find.text('Premium Weekly'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scrolling to 15 verifies and opens the paywall once',
      (tester) async {
    await mountPremium(tester);
    // The wheel starts at 10 (index 0); each item is 44 logical pixels.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -44 * 5));
    await tester.pumpAndSettle();
    expect(find.text('Selected age: 15'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Premium Weekly'), findsOneWidget);
    // Reopening premium asks nothing again.
    await tester.pumpWidget(const SizedBox());
    await mountPremium(tester);
    expect(find.text('How old are you?'), findsNothing);
    expect(find.text('Premium Weekly'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blocked status survives a remount with no way back',
      (tester) async {
    await AgeGateService.instance.blockMinor();
    await mountPremium(tester);
    expect(find.text('Not available for your age'), findsOneWidget);
    expect(find.text('How old are you?'), findsNothing);
    expect(find.text('For Parents'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
