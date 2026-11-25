import 'fakes/eligible_player.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/screens/voting/star_received_screen.dart';

/// Taps the first visible friend option and returns its name.
///
/// Each question shows four selected contacts.
Future<String> tapFirstVisibleFriend(WidgetTester tester) async {
  for (final name in ['Alex', 'Sam', 'Jordan', 'Taylor']) {
    final found = find.text(name);
    if (found.evaluate().isNotEmpty) {
      await tester.tap(found.first);
      return name;
    }
  }
  throw StateError('no voting option visible');
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
  });

  test(
    'latest round replaces previous choices and reset removes votes and photo',
    () async {
      final game = LocalGameService.instance;
      await game.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['Alex', 'Sam', 'Jordan'],
      );
      await (await SharedPreferences.getInstance()).setString(
        'local_avatar',
        'encoded-test-photo',
      );
      await game.recordAnswer(
        const RoundAnswer(
          questionId: 'q1',
          question: 'Who?',
          voter: 'Player',
          choice: 'Alex',
        ),
      );
      await game.recordAnswer(
        const RoundAnswer(
          questionId: 'q1',
          question: 'Who?',
          voter: 'Player',
          choice: 'Sam',
        ),
      );
      expect((await game.getRoundAnswers()).single.choice, 'Sam');
      await game.completeRound();
      expect(await game.getRoundAnswers(), isEmpty);
      expect(
        (await game.getRoundAnswers(completed: true)).single.choice,
        'Sam',
      );
      final exported = jsonDecode(await game.exportLocalData()) as Map;
      expect(exported.containsKey('avatarPngBase64'), isFalse);
      expect((exported['lastRound'] as List).single['choice'], 'Sam');
      await game.recordAnswer(
        const RoundAnswer(questionId: 'q2', question: 'Next?', voter: 'Player'),
      );
      await game.completeRound();
      expect(
        (await game.getRoundAnswers(completed: true)).single.questionId,
        'q2',
      );
      expect(
        (await game.getRoundAnswers(completed: true)).single.choice,
        isNull,
      );
      await game.clearAll();
      expect(
        (await SharedPreferences.getInstance()).getString('local_avatar'),
        isNull,
      );
      expect(await game.getRoundAnswers(), isEmpty);
      expect(await game.getRoundAnswers(completed: true), isEmpty);
    },
  );

  test('effect settings persist independently of game reset', () async {
    final settings = GameSettings.instance;
    await settings.setOption('sound', false);
    await settings.setOption('haptics', false);
    await settings.setOption('reduce_motion', true);
    await LocalGameService.instance.clearAll();
    await settings.load();
    expect(settings.sound, isFalse);
    expect(settings.haptics, isFalse);
    expect(settings.reduceMotion, isTrue);
  });

  testWidgets(
    'retired photos are cleared without wiping progress; profile has only a smiley',
    (tester) async {
      final game = LocalGameService.instance;
      await game.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_avatar', 'legacy-base64-photo');
      await game.removeLegacyAvatar();
      expect(prefs.getString('local_avatar'), isNull);
      expect(await game.getPlayerName(), 'Player');
      expect(await game.getNames(), hasLength(4));
      final storage = StorageService();
      await storage.init();
      testAppRouter.go(AppRoutes.editProfile);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp.router(routerConfig: testAppRouter),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🙂'), findsOneWidget);
      expect(find.text('Change photo'), findsNothing);
      expect(find.text('Remove photo'), findsNothing);
      expect(find.byIcon(Icons.camera_alt), findsNothing);
      testAppRouter.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.text('🙂'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'round completion rewards all twelve answers without a Full Reveal screen',
    (tester) async {
      await GameSettings.instance.setOption('reduce_motion', true);
      await GameSettings.instance.setOption('sound', false);
      final game = LocalGameService.instance;
      await game.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      final router = GoRouter(
        initialLocation: '/vote',
        routes: [
          GoRoute(path: '/vote', builder: (_, __) => const VoteScreen()),
          GoRoute(
            path: '/star-received',
            builder: (_, __) => const StarReceivedScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        expect(find.text('Reveal'), findsNothing);
        expect(find.text('Question ${i + 1} of 12'), findsOneWidget);
        await tapFirstVisibleFriend(tester);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
      expect(find.text('Review your answers'), findsOneWidget);
      expect(find.text('Reveal'), findsNothing);
      expect(await game.getStars(), 0);
      expect(await game.secondsUntilNextRound(), 0);
      await tester.tap(find.text('Finish round'));
      await tester.pumpAndSettle();
      expect(find.text('Reveal'), findsNothing);
      expect(await game.getRoundAnswers(completed: true), hasLength(12));
      expect(await game.getStars(), 1000);
      expect(find.text('Your round revealed'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('local Premium overrides cannot double guest round rewards', (
    tester,
  ) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    await GameSettings.instance.setOption('sound', false);
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
      playerName: 'Player',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
    await SubscriptionService.instance.setPro(true);
    final router = GoRouter(
      initialLocation: '/vote',
      routes: [
        GoRoute(path: '/vote', builder: (_, __) => const VoteScreen()),
        GoRoute(
          path: '/star-received',
          builder: (_, __) => const StarReceivedScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tapFirstVisibleFriend(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Finish round'));
    await tester.pumpAndSettle();
    expect(await game.getStars(), 1000);
    expect(find.text('Reveal'), findsNothing);
    expect(find.text('Your round revealed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'server-acknowledged double reward is displayed without any Full Reveal action',
    (tester) async {
      await GameSettings.instance.setOption('reduce_motion', true);
      await tester.pumpWidget(
        const MaterialApp(home: StarReceivedScreen(starsAwarded: 2000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collect 2000 stars'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collect-stars')));
      await tester.pumpAndSettle();
      expect(find.text('+2000'), findsWidgets);
      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Reveal'), findsNothing);
      expect(find.text('Your round revealed'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reward keeps Collection navigation after removing Full Reveal', (
    tester,
  ) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const StarReceivedScreen(starsAwarded: 2000),
        ),
        GoRoute(
          path: AppRoutes.collection,
          builder: (_, _) =>
              const Scaffold(body: Text('Collection destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collect-stars')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Collection'));
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('Collection destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.collection);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reward screen has no share action and stays clean on small screens',
    (tester) async {
      await GameSettings.instance.setOption('reduce_motion', true);
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: StarReceivedScreen(starsAwarded: 1000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share Flyprox'), findsNothing);
      expect(find.text('Collect 1000 stars'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collect-stars')));
      await tester.pumpAndSettle();
      expect(find.text('Share Flyprox'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
