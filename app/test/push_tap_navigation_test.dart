import 'package:flyprox_app/models/user.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'fakes/social_storage.dart';
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

class PushSocial extends SocialService {
  PushSocial(super.api, super.storage);
  int likesLoads = 0;
  final kinds = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    if (path.startsWith('/likes')) {
      likesLoads++;
      return {
        'votesReceived': likesLoads,
        'items': [
          {
            'id': 'vote-$likesLoads',
            'question': 'Fresh vote $likesLoads',
            'occurredAt': DateTime.now().toIso8601String(),
          },
        ],
      };
    }
    if (path == '/me') return {'username': 'player_123'};
    return {};
  }

  @override
  Future<Map<String, dynamic>> list(String kind, {String? cursor}) async {
    kinds.add(kind);
    return {
      'users': kind == 'incoming'
          ? [
              {'id': 'sam', 'username': 'sam_123', 'relationship': 'incoming'},
              {
                'id': 'alex',
                'username': 'alex_123',
                'relationship': 'incoming',
              },
            ]
          : [],
    };
  }
}

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
  String route, {
  SessionStorage? session,
  PushSocial? social,
}) async {
  final storage = session ?? StorageService();
  await storage.init();
  testAppRouter.go(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        pushServiceProvider.overrideWithValue(push),
        if (social != null) socialServiceProvider.overrideWithValue(social),
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

  test(
    'push service passes taps through and consumes the initial tap once',
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
    },
  );

  testWidgets('live push tap opens its screen while the app runs', (
    tester,
  ) async {
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

  testWidgets('repeated vote taps refresh mounted Likes with real new data', (
    tester,
  ) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    final storage = SessionStorage();
    final social = PushSocial(ApiService(storage), storage);
    await mount(
      tester,
      tapPush(driver),
      AppRoutes.likesFilled,
      session: storage,
      social: social,
    );
    final before = social.likesLoads;
    expect(before, greaterThan(0));
    driver.taps.add(const PushTap('vote_received'));
    await pumpRoute(tester);
    expect(location, AppRoutes.likesFilled);
    expect(social.likesLoads, before + 1);
    expect(find.text('Fresh vote ${before + 1}'), findsOneWidget);
    driver.taps.add(const PushTap('vote_received'));
    await pumpRoute(tester);
    expect(social.likesLoads, before + 2);
    expect(find.text('Fresh vote ${before + 2}'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'friend push opens Received with Accept even after visiting Friends',
    (tester) async {
      final driver = FakePushDriver();
      addTearDown(driver.dispose);
      final storage = SessionStorage();
      final social = PushSocial(ApiService(storage), storage);
      await mount(
        tester,
        tapPush(driver),
        AppRoutes.friends,
        session: storage,
        social: social,
      );
      driver.taps.add(const PushTap('friend_request'));
      await pumpRoute(tester);
      expect(location, AppRoutes.friendRequests);
      expect(social.kinds.last, 'incoming');
      expect(find.text('Accept'), findsNWidgets(2));
      driver.taps.add(const PushTap('friend_request'));
      await pumpRoute(tester);
      expect(social.kinds.where((k) => k == 'incoming').length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final type in ['new_device', 'moderation']) {
    testWidgets('$type opens the relevant help screen', (tester) async {
      final driver = FakePushDriver();
      addTearDown(driver.dispose);
      driver.initialTap = PushTap(type);
      await mount(tester, tapPush(driver), AppRoutes.splash);
      expect(
        location,
        type == 'new_device' ? AppRoutes.signInNotice : AppRoutes.accountUpdate,
      );
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.byType(StartupIntro), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'addressed push ignores another account and focuses an authorized request',
    (tester) async {
      final driver = FakePushDriver();
      addTearDown(driver.dispose);
      final storage = SessionStorage();
      await storage.init();
      await storage.saveUser(User.fromJson({'id': 'current'}));
      final social = PushSocial(ApiService(storage), storage);
      await mount(
        tester,
        tapPush(driver),
        AppRoutes.home,
        session: storage,
        social: social,
      );
      driver.taps.add(
        const PushTap(
          'friend_request',
          recipientId: 'previous',
          actorId: 'alex',
          eventId: 'old',
        ),
      );
      await pumpRoute(tester);
      expect(location, AppRoutes.home);
      expect(social.kinds, isEmpty);
      driver.taps.add(
        const PushTap(
          'friend_request',
          recipientId: 'current',
          actorId: 'alex',
          eventId: 'new',
        ),
      );
      await pumpRoute(tester);
      expect(location, AppRoutes.friendRequests);
      expect(
        testAppRouter
            .routeInformationProvider
            .value
            .uri
            .queryParameters['focus'],
        'alex',
      );
      expect(
        tester.getTopLeft(find.text('@alex_123')).dy,
        lessThan(tester.getTopLeft(find.text('@sam_123')).dy),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cold start addressed to another account returns to Home', (
    tester,
  ) async {
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    final storage = SessionStorage();
    await storage.init();
    await storage.saveUser(User.fromJson({'id': 'current'}));
    driver.initialTap = const PushTap(
      'friend_request',
      recipientId: 'previous',
    );
    await mount(tester, tapPush(driver), AppRoutes.splash, session: storage);
    expect(location, AppRoutes.home);
    expect(find.byType(StartupIntro), findsNothing);
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

  testWidgets('cold start tap skips the intro and opens its screen', (
    tester,
  ) async {
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
