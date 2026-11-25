import 'fakes/eligible_player.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/models/user.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/providers/user_provider.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';

class DeletionApi extends Mock implements ApiService {}

Future<ProviderContainer> mountResetApp(
  WidgetTester tester,
  String route, {
  ApiService? api,
  bool signedIn = false,
  bool reviewer = false,
}) async {
  final storage = StorageService();
  await storage.init();
  if (reviewer) await storage.markReviewerSeen();
  if (signedIn) {
    await storage.saveToken('signed-in-token');
    await storage.savePhone('+16505551234');
  }
  await storage.saveUser(
    User.fromJson({'id': 'old-local-cache', 'firstName': 'Old cache'}),
  );
  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      if (api != null) apiServiceProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container.read(localProfileProvider.notifier).refresh();
  expect(container.read(localProfileProvider).playerName, 'Old player');
  expect(container.read(currentUserProvider)?.firstName, 'Old cache');
  testAppRouter.go(route);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: testAppRouter),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> seedGame() async {
  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final game = LocalGameService.instance;
  await game.savePlayerAndFriends(
    username: 'old_handle',
    playerName: 'Old player',
    friends: ['Alex', 'Sam', 'Jordan'],
  );
  await game.saveUniversity('Stanford University');
  await game.saveUniversityYear(3);
  await game.generateRound(languageCode: 'en');
  await game.completeRound();
}

Future<void> checkClearedGame(ProviderContainer container) async {
  final game = LocalGameService.instance;
  expect(await game.getUsername(), isNull);
  expect(await game.getPlayerName(), isNull);
  expect(await game.getNames(), isEmpty);
  expect(await game.getUniversity(), isNull);
  expect(await game.getUniversityYear(), isNull);
  expect(await game.getStars(), 0);
  expect(await game.secondsUntilNextRound(), 0);
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('local_used_question_ids'), isNull);
  expect(prefs.getString('current_user'), isNull);
  final cached = container.read(localProfileProvider);
  expect(cached.playerName, isEmpty);
  expect(cached.university, isEmpty);
  expect(cached.stars, 0);
  expect(cached.peopleCount, 0);
  expect(container.read(currentUserProvider), isNull);
  expect(container.read(storageServiceProvider).isOnboardingDone(), isTrue);
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() async {
    await seedGame();
  });

  for (final route in [
    AppRoutes.settings,
    AppRoutes.deleteAccount,
  ]) {
    final deleteWording = route == AppRoutes.deleteAccount;
    final buttonLabel = deleteWording ? 'Delete account' : 'Reset game';
    final dialogTitle = deleteWording ? 'Delete account?' : 'Reset game?';
    testWidgets('$route cancel leaves local game and cache intact', (
      tester,
    ) async {
      final container = await mountResetApp(tester, route);
      await tester.ensureVisible(
        deleteWording
            ? find.widgetWithText(FilledButton, buttonLabel)
            : find.text(buttonLabel),
      );
      await tester.tap(
        deleteWording
            ? find.widgetWithText(FilledButton, buttonLabel)
            : find.text(buttonLabel),
      );
      await tester.pumpAndSettle();
      expect(find.text(dialogTitle), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await LocalGameService.instance.getPlayerName(), 'Old player');
      expect(await LocalGameService.instance.getStars(), 1000);
      expect(
        await LocalGameService.instance.secondsUntilNextRound(),
        greaterThan(0),
      );
      expect(container.read(localProfileProvider).playerName, 'Old player');
      expect(testAppRouter.routeInformationProvider.value.uri.path, route);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$route confirm clears game, cache and persisted progress', (
      tester,
    ) async {
      final container = await mountResetApp(tester, route);
      await tester.ensureVisible(
        deleteWording
            ? find.widgetWithText(FilledButton, buttonLabel)
            : find.text(buttonLabel),
      );
      await tester.tap(
        deleteWording
            ? find.widgetWithText(FilledButton, buttonLabel)
            : find.text(buttonLabel),
      );
      await tester.pumpAndSettle();
      if (deleteWording) {
        expect(
          find.textContaining('Are you sure you are ready to delete?'),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, buttonLabel),
        ),
      );
      await tester.pumpAndSettle();
      await checkClearedGame(container);
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.phone,
      );
      await tester.pumpWidget(const SizedBox());
      testAppRouter.go(AppRoutes.splash);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: testAppRouter),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.phone,
      );
      expect(find.text('Old player'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Edit profile cannot reset a guest game or silently edit local identity', (tester) async {
    final container = await mountResetApp(tester, AppRoutes.editProfile);
    expect(find.text('Sign in to edit your profile.'), findsOneWidget);
    expect(find.text('Reset game'), findsNothing);
    expect(await LocalGameService.instance.getPlayerName(), 'Old player');
    expect(await LocalGameService.instance.getStars(), 1000);
    expect(await LocalGameService.instance.secondsUntilNextRound(), greaterThan(0));
    expect(container.read(localProfileProvider).playerName, 'Old player');
    await tester.pumpWidget(const SizedBox());
  });

  test('cache clear defeats an already pending refresh', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(localProfileProvider.notifier);
    final refresh = notifier.refresh();
    notifier.clear();
    await refresh;
    expect(container.read(localProfileProvider).playerName, isEmpty);
    expect(container.read(localProfileProvider).stars, 0);
  });

  testWidgets(
    'new setup after reset displays the new profile instead of cached data',
    (tester) async {
      final container = await mountResetApp(
        tester,
        AppRoutes.settings,
        reviewer: true,
      );
      await tester.tap(find.text('Reset game'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reset game'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue without login'));
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('onboarding-first-name')),
        'New',
      );
      await tester.enterText(
        find.byKey(const Key('onboarding-last-name')),
        'Player',
      );
      await tester.ensureVisible(find.text('Female'));
      await tester.tap(find.text('Female'));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('skip-school')));
      await tester.tap(find.byKey(const Key('skip-school')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Try with example names'));
      await tester.tap(find.text('Try with example names'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your username'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final name = container.read(localProfileProvider).playerName;
      expect(name, 'New Player');
      testAppRouter.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(find.text('Old player'), findsNothing);
      expect(find.text('Old cache'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('settings renders cleanly with local-game actions', (
    tester,
  ) async {
    await mountResetApp(tester, AppRoutes.settings);
    expect(find.text('Reset game'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Language'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed server erasure preserves credentials and local progress for retry',
    (tester) async {
      final api = DeletionApi();
      when(
        () => api.delete<Map<String, dynamic>>(
          '/api/users/me',
          options: any(named: 'options'),
        ),
      ).thenThrow(const ApiException('Network unavailable'));
      final container = await mountResetApp(
        tester,
        AppRoutes.settings,
        api: api,
        signedIn: true,
      );
      await tester.ensureVisible(find.text('Reset game'));
      await tester.tap(find.text('Reset game'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reset game'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        await container.read(storageServiceProvider).getToken(),
        'signed-in-token',
      );
      expect(await LocalGameService.instance.getPlayerName(), 'Old player');
      expect(await LocalGameService.instance.getStars(), 1000);
      expect(
        find.textContaining('Your local progress was kept'),
        findsOneWidget,
      );
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.settings,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'only explicit server erasure confirmation clears a signed-in account locally',
    (tester) async {
      final api = DeletionApi();
      when(
        () => api.delete<Map<String, dynamic>>(
          '/api/users/me',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/users/me'),
          data: {'deleted': true},
        ),
      );
      final container = await mountResetApp(
        tester,
        AppRoutes.settings,
        api: api,
        signedIn: true,
      );
      await tester.ensureVisible(find.text('Reset game'));
      await tester.tap(find.text('Reset game'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reset game'),
        ),
      );
      await tester.pumpAndSettle();
      expect(await container.read(storageServiceProvider).getToken(), isNull);
      expect(container.read(storageServiceProvider).getPhone(), isNull);
      await checkClearedGame(container);
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.phone,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
