import 'fakes/eligible_player.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/providers/user_provider.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/widgets/common/round_reveal.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/screens/voting/star_received_screen.dart';

/// Taps the first visible friend option and returns its name.
///
/// Each question shows the player plus 3 of the 4 friends, so a fixed name
/// is not always on screen.
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
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan']);
    await game.saveAvatar('encoded-test-photo');
    await game.recordAnswer(const RoundAnswer(
        questionId: 'q1', question: 'Who?', voter: 'Player', choice: 'Alex'));
    await game.recordAnswer(const RoundAnswer(
        questionId: 'q1', question: 'Who?', voter: 'Player', choice: 'Sam'));
    expect((await game.getRoundAnswers()).single.choice, 'Sam');
    await game.completeRound();
    expect(await game.getRoundAnswers(), isEmpty);
    expect((await game.getRoundAnswers(completed: true)).single.choice, 'Sam');
    final exported = jsonDecode(await game.exportLocalData()) as Map;
    expect(exported['avatarPngBase64'], 'encoded-test-photo');
    expect((exported['lastRound'] as List).single['choice'], 'Sam');
    await game.recordAnswer(const RoundAnswer(
        questionId: 'q2', question: 'Next?', voter: 'Player'));
    await game.completeRound();
    expect(
        (await game.getRoundAnswers(completed: true)).single.questionId, 'q2');
    expect((await game.getRoundAnswers(completed: true)).single.choice, isNull);
    await game.clearAll();
    expect(await game.getAvatar(), isNull);
    expect(await game.getRoundAnswers(), isEmpty);
    expect(await game.getRoundAnswers(completed: true), isEmpty);
  });

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
      'saved photo survives profile reload and can be removed without resetting the game',
      (tester) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6dtcAAAAASUVORK5CYII=';
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        username: 'player',
        playerName: 'Player',
        friends: ['Alex', 'Sam', 'Jordan']);
    await game.saveAvatar(png);
    final storage = StorageService();
    await storage.init();
    final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);
    await container.read(localProfileProvider.notifier).refresh();
    expect(container.read(localProfileProvider).avatar, png);
    appRouter.go(AppRoutes.editProfile);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: appRouter)));
    await tester.pumpAndSettle();
    expect(find.text('Remove photo'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(await game.getAvatar(), png); // Form changes apply on Save.
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await game.getAvatar(), isNull);
    expect(container.read(localProfileProvider).avatar, isNull);
    expect(await game.getPlayerName(), 'Player');
    expect(await game.getNames(), hasLength(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Reveal appears only after all twelve questions and shows saved choices',
      (tester) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    await GameSettings.instance.setOption('sound', false);
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan', 'Taylor']);
    final router = GoRouter(initialLocation: '/vote', routes: [
      GoRoute(path: '/vote', builder: (_, __) => const VoteScreen()),
      GoRoute(
          path: '/star-received',
          builder: (_, __) => const StarReceivedScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final voted = <String>[];
    for (var i = 0; i < 12; i++) {
      expect(find.text('Reveal'), findsNothing);
      expect(find.text('Question ${i + 1} of 12'), findsOneWidget);
      voted.add(await tapFirstVisibleFriend(tester));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('Reveal'), findsOneWidget);
    expect(await game.getRoundAnswers(completed: true), hasLength(12));
    expect(await game.getStars(), 1000);
    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    expect(find.text('Your round revealed'), findsOneWidget);
    expect(find.text('You → ${voted.first}'), findsAtLeast(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> seedTwelveAnswers() async {
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan']);
    for (var i = 0; i < 12; i++) {
      await game.recordAnswer(RoundAnswer(
          questionId: 'q$i',
          question: 'Question $i?',
          voter: 'Player',
          choice: 'Alex'));
    }
    await game.completeRound();
  }

  Future<void> openRevealSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRoundReveal(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('pro Reveal shows all twelve answers without upsell',
      (tester) async {
    await seedTwelveAnswers();
    await SubscriptionService.instance.setPro(true);
    await openRevealSheet(tester);
    await tester.dragUntilVisible(
      find.text('12. Question 11?'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('12. Question 11?'), findsOneWidget);
    expect(find.textContaining('with Premium'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('free Reveal shows three answers with a Premium upsell',
      (tester) async {
    await seedTwelveAnswers();
    await openRevealSheet(tester);
    expect(find.text('You → Alex'), findsWidgets);
    expect(find.text('Reveal all 9 more with Premium'), findsOneWidget);
    expect(find.text('4. Question 3?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pro members earn double stars for a completed round',
      (tester) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    await GameSettings.instance.setOption('sound', false);
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan', 'Taylor']);
    await SubscriptionService.instance.setPro(true);
    final router = GoRouter(initialLocation: '/vote', routes: [
      GoRoute(path: '/vote', builder: (_, __) => const VoteScreen()),
      GoRoute(
          path: '/star-received',
          builder: (_, __) => const StarReceivedScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tapFirstVisibleFriend(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(await game.getStars(), 2000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
