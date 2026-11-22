import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_push_driver.dart';
import 'fakes/test_app.dart';

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'user234432',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
    await LocalGameService.instance.setUsernameSetupPending(true);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool loggedIn = false,
    String route = AppRoutes.username,
    double scale = 1,
  }) async {
    final storage = StorageService();
    await storage.init();
    if (loggedIn) await storage.saveToken('test-session');
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    testAppRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          pushServiceProvider.overrideWithValue(
            PushService(driver: driver, api: ApiService(storage)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testAppRouter,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('valid nickname persists in profile, never in voting cards', (
    tester,
  ) async {
    await mount(tester);
    final field = find.byKey(const Key('onboarding-username'));
    expect(tester.widget<TextFormField>(field).controller!.text, 'user234432');
    for (final invalid in ['', 'ab', 'bad name', 'имя']) {
      await tester.enterText(field, invalid);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your username'), findsOneWidget);
      expect(await LocalGameService.instance.isUsernameSetupPending(), isTrue);
    }
    await tester.enterText(field, 'aman_23');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final game = LocalGameService.instance;
    expect(await game.getUsername(), 'aman_23');
    expect(await game.getPlayerName(), 'aman_23');
    expect(await game.isUsernameSetupPending(), isFalse);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    for (final question in await game.generateRound(languageCode: 'en')) {
      expect(
        question.optionNames,
        unorderedEquals(['Alex', 'Sam', 'Jordan', 'Taylor']),
      );
    }
    testAppRouter.go(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.text('@aman_23'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, route: AppRoutes.splash);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
  });

  testWidgets(
    'unfinished nickname setup resumes after a new router is created',
    (tester) async {
      await mount(tester);
      await tester.pumpWidget(const SizedBox());
      testAppRouter = createAppRouter();
      addTearDown(testAppRouter.dispose);
      await mount(tester, route: AppRoutes.splash);
      expect(find.text('Choose your username'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('onboarding-username')))
            .controller!
            .text,
        'user234432',
      );
    },
  );

  testWidgets(
    'signed-in player gets notification prompt after nickname, not before',
    (tester) async {
      await mount(tester, loggedIn: true);
      expect(find.text('Never miss a vote'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Never miss a vote'), findsOneWidget);
      expect(await LocalGameService.instance.getUsername(), 'user234432');
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('nickname form works at 320px, scale $scale with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await mount(tester, scale: scale);
      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'test_user',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
