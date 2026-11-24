import 'dart:async';
import 'package:flyprox_app/screens/profile/person_profile_screen.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/screens/voting/timer_screen.dart';
import 'fakes/eligible_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/utils/constants.dart';

import 'fakes/fake_age_gate_store.dart';
import 'fakes/fake_gateway.dart';
import 'package:flyprox_app/widgets/common/bottom_nav_bar.dart';

Future<void> pumpRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> mount(WidgetTester tester, String route) async {
  final storage = StorageService();
  await storage.init();
  testAppRouter.go(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
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

  testWidgets('settings is the fifth tab and remains selected on help pages', (
    tester,
  ) async {
    await mount(tester, AppRoutes.profile);
    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await pumpRoute(tester);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.settings,
    );
    expect(
      tester.widget<AppBottomNavBar>(find.byType(AppBottomNavBar)).currentIndex,
      4,
    );
    await tester.dragUntilVisible(
      find.text('How to play'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to play'));
    await pumpRoute(tester);
    expect(find.text('How to use'), findsOneWidget);
    expect(
      tester.widget<AppBottomNavBar>(find.byType(AppBottomNavBar)).currentIndex,
      4,
    );
    await tester.tap(find.byTooltip('Profile'));
    await pumpRoute(tester);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.profile,
    );
    expect(
      tester.widget<AppBottomNavBar>(find.byType(AppBottomNavBar)).currentIndex,
      3,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home preserves the same cooldown through repeated navigation', (
    tester,
  ) async {
    final game = LocalGameService.instance;
    await game.completeRound();
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getInt('local_last_round_completed_at');
    await mount(tester, AppRoutes.home);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await pumpRoute(tester);
      expect(find.byType(TimerScreen), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavBar>(find.byType(AppBottomNavBar))
            .currentIndex,
        0,
      );
      expect(prefs.getInt('local_last_round_completed_at'), original);
      expect(find.text('Question 1 of 12'), findsNothing);
      testAppRouter.pop();
      await pumpRoute(tester);
    }
    await game.bypassTimer();
    testAppRouter.go(AppRoutes.vote);
    await pumpRoute(tester);
    expect(find.byType(VoteScreen), findsOneWidget);
    expect(find.text('Question 1 of 12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final route in [AppRoutes.vote]) {
    testWidgets('$route cannot bypass an active cooldown', (tester) async {
      await LocalGameService.instance.completeRound();
      await mount(tester, route);
      expect(find.byType(TimerScreen), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavBar>(find.byType(AppBottomNavBar))
            .currentIndex,
        0,
      );
      expect(find.text('Question 1 of 12'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('pro members preserve an active cooldown', (tester) async {
    await LocalGameService.instance.completeRound();
    await SubscriptionService.instance.setPro(true);
    await mount(tester, AppRoutes.vote);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.timer,
    );
    expect(find.text('Question 1 of 12'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('profile shows the verified badge for pro members', (
    tester,
  ) async {
    await SubscriptionService.instance.setPro(true);
    await mount(tester, AppRoutes.profile);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('profile hides the verified badge when free', (tester) async {
    await mount(tester, AppRoutes.profile);
    expect(find.byIcon(Icons.verified), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final retired in [AppRoutes.premiumResult]) {
    testWidgets('$retired returns to the free game without a purchase screen', (
      tester,
    ) async {
      await mount(tester, retired);
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      await tester.ensureVisible(find.text('Go to quiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to quiz'));
      await pumpRoute(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      expect(find.text('Question 1 of 12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('/premium opens the Premium paywall', (tester) async {
    AgeGateService.instance.debugStore(InMemoryAgeGateStore());
    addTearDown(AgeGateService.instance.resetForTest);
    await AgeGateService.instance.verifyAdult();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, AppRoutes.premium);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.premium,
    );
    expect(find.text('Premium Weekly'), findsOneWidget);
    expect(
      find.textContaining('1-week auto-renewing subscription'),
      findsWidgets,
    );
    expect(find.textContaining('\$6.99'), findsWidgets);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.textContaining('renews automatically'), findsOneWidget);
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          if (call.method == 'launch') {
            launchedUrl = (call.arguments as Map)['url'] as String?;
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, null),
    );
    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();
    expect(launchedUrl, AppConstants.termsUrl);
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(launchedUrl, AppConstants.privacyUrl);
    // Multi-frame stability: content persists across further pumps.
    await pumpRoute(tester);
    await pumpRoute(tester);
    expect(find.text('Premium Weekly'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'search keeps its query and a running round survives switching tabs',
    (tester) async {
      await mount(tester, AppRoutes.vote);
      await tester.ensureVisible(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 of 12'), findsOneWidget);
      final progress = await LocalGameService.instance.loadRoundProgress();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'alex_123');
      await tester.pump(const Duration(milliseconds: 500));
      for (final path in ['/people/alex', '/p/@alex_123']) {
        unawaited(testAppRouter.push<void>(path));
        await tester.pumpAndSettle();
        expect(find.byType(PersonProfileScreen), findsOneWidget);
        expect(
          tester
              .widget<AppBottomNavBar>(find.byType(AppBottomNavBar))
              .currentIndex,
          1,
        );
        testAppRouter.pop();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'alex_123',
        );
      }
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 of 12'), findsOneWidget);
      expect(
        (await LocalGameService.instance.loadRoundProgress())?.questionIds,
        progress?.questionIds,
      );
      expect(
        (await LocalGameService.instance.loadRoundProgress())?.questionIndex,
        progress?.questionIndex,
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'alex_123',
      );
      expect(find.byTooltip('Quiz'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expired cooldown allows home to open a round', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'local_last_round_completed_at',
      DateTime.now()
          .subtract(const Duration(minutes: 61))
          .millisecondsSinceEpoch,
    );
    await mount(tester, AppRoutes.home);
    await tester.ensureVisible(find.text('Go to quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to quiz'));
    await pumpRoute(tester);
    expect(find.byType(VoteScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
