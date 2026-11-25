import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';
import 'package:flyprox_app/services/push_driver.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/widgets/common/startup_intro.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/fake_push_driver.dart';
import 'fakes/test_app.dart';

class MockApiService extends Mock implements ApiService {}

Future<void> pumpRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String get location => testAppRouter.routeInformationProvider.value.uri.path;

PushService tapPush(FakePushDriver driver) =>
    PushService(driver: driver, api: MockApiService());

Future<void> mount(
  WidgetTester tester,
  PushService push,
  String route,
) async {
  final storage = StorageService();
  await storage.init();
  testAppRouter.go(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        pushServiceProvider.overrideWithValue(push),
      ],
      child: MaterialApp.router(routerConfig: testAppRouter),
    ),
  );
  await pumpRoute(tester);
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.instance.resetForTest();
    SubscriptionService.instance.debugGateway(FakeGateway());
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Player',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
  });

  test('push service passes taps through and consumes the initial tap once',
      () async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    final push = tapPush(driver);
    driver.initialTap = const PushTap('vote_received');
    expect((await push.getInitialTap())?.type, 'vote_received');
    expect(await push.getInitialTap(), isNull);
    await push.setTapArmed(true);
    expect(driver.tapArmed, isTrue);
    final received = push.pushTaps.first;
    driver.taps.add(const PushTap('round_ready'));
    expect((await received).type, 'round_ready');
  });

  testWidgets('live push tap opens its screen while the app runs',
      (tester) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mount(tester, tapPush(driver), AppRoutes.home);
    expect(location, AppRoutes.home);

    driver.taps.add(const PushTap('friend_request'));
    await pumpRoute(tester);
    expect(location, AppRoutes.friendRequests);

    driver.taps.add(const PushTap('round_ready'));
    await pumpRoute(tester);
    expect(location, AppRoutes.vote);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown live tap keeps the current route', (tester) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mount(tester, tapPush(driver), AppRoutes.home);
    expect(location, AppRoutes.home);

    driver.taps.add(const PushTap('marketing'));
    await pumpRoute(tester);
    expect(location, AppRoutes.home);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cold start tap skips the intro and opens its screen',
      (tester) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    driver.initialTap = const PushTap('round_ready');
    await mount(tester, tapPush(driver), AppRoutes.splash);

    expect(find.byType(StartupIntro), findsNothing);
    expect(location, AppRoutes.vote);
    expect(driver.initialTap, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guards win over a cold start tap', (tester) async {
    AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
    OnboardingFlow.instance.restart();
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    driver.initialTap = const PushTap('round_ready');
    await mount(tester, tapPush(driver), AppRoutes.splash);

    expect(find.byType(StartupIntro), findsNothing);
    expect(location, AppRoutes.phone);
    expect(driver.initialTap, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shell mount arms taps and unmount disarms', (tester) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mount(tester, tapPush(driver), AppRoutes.home);
    expect(driver.tapArmed, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(driver.tapArmed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
