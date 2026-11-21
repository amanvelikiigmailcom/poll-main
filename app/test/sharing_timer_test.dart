import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/social/invite_friend_screen.dart';
import 'package:flyprox_app/screens/voting/timer_screen.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';

GoRouter makeRouter(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
            path: '/invite', builder: (_, __) => const InviteFriendScreen()),
        GoRoute(path: '/timer', builder: (_, __) => const TimerScreen()),
        GoRoute(
            path: '/vote',
            builder: (_, __) => const Scaffold(body: Text('Quiz ready'))),
        GoRoute(path: '/play', builder: (_, __) => const VoteScreen()),
        GoRoute(
            path: '/star-received',
            builder: (_, __) => const Scaffold(body: Text('Round done'))),
        GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home'))),
      ],
    );

Future<void> pumpLoaded(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final platform in ['WhatsApp', 'Instagram']) {
    testWidgets('$platform tap skips timer even without external app',
        (tester) async {
      final game = LocalGameService.instance;
      await game.completeRound();
      final router = makeRouter('/invite');
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpLoaded(tester);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
      expect(find.text('Telegram'), findsNothing);
      expect(find.text('All apps'), findsNothing);
      await tester.tap(find.text(platform));
      await pumpLoaded(tester);
      expect(await game.secondsUntilNextRound(), 0);
      expect(find.text('Timer skipped. Your next round is ready.'),
          findsOneWidget);
      await tester.tap(find.text('Start next round'));
      await pumpLoaded(tester);
      expect(find.text('Quiz ready'), findsOneWidget);
    });
  }

  testWidgets('opening sharing and copying do not skip the timer',
      (tester) async {
    final game = LocalGameService.instance;
    await game.completeRound();
    final router = makeRouter('/timer');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    await tester.ensureVisible(find.text('Open sharing options'));
    await tester.tap(find.text('Open sharing options'));
    await pumpLoaded(tester);
    await tester.tap(find.text('Copy message'));
    await pumpLoaded(tester);
    expect(await game.secondsUntilNextRound(), greaterThan(0));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await pumpLoaded(tester);
    expect(find.byType(TimerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('return from social tap unlocks timer screen', (tester) async {
    await LocalGameService.instance.completeRound();
    final router = makeRouter('/timer');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    await tester.ensureVisible(find.text('Open sharing options'));
    await tester.tap(find.text('Open sharing options'));
    await pumpLoaded(tester);
    await tester.tap(find.text('WhatsApp'));
    await pumpLoaded(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await pumpLoaded(tester);
    expect(find.text('Quiz ready'), findsOneWidget);
  });

  testWidgets('timer restores saved time and expired timer opens next round',
      (tester) async {
    final game = LocalGameService.instance;
    await game.completeRound();
    final prefs = await SharedPreferences.getInstance();
    final timeKey = prefs.getKeys().singleWhere(
        (key) => prefs.get(key) is int && prefs.getInt(key)! > 1000000000000);
    await prefs.setInt(
        timeKey,
        DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch);
    final router = makeRouter('/timer');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    expect(find.text('40:00'), findsNothing);
    expect(await game.secondsUntilNextRound(), inInclusiveRange(1798, 1800));
    await prefs.setInt(
        timeKey,
        DateTime.now()
            .subtract(const Duration(minutes: 41))
            .millisecondsSinceEpoch);
    await tester.pump(const Duration(seconds: 1));
    await pumpLoaded(tester);
    expect(find.text('Quiz ready'), findsOneWidget);
  });

  testWidgets('Shuffle works repeatedly and all 12 questions can be skipped',
      (tester) async {
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan', 'Taylor']);
    final router = makeRouter('/play');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(find.text('Shuffle'));
      await tester.tap(find.text('Shuffle'));
      await tester.pump();
      expect(find.text('Question 1 of 12'), findsOneWidget);
      // The player is always an option; exactly 3 of the 4 friends are shown.
      expect(find.text('Player'), findsOneWidget);
      var shown = 0;
      for (final name in ['Alex', 'Sam', 'Jordan', 'Taylor']) {
        final count = find.text(name).evaluate().length;
        expect(count, lessThanOrEqualTo(1));
        shown += count;
      }
      expect(shown, 3);
    }
    for (var i = 1; i <= 12; i++) {
      expect(find.text('Question $i of 12'), findsOneWidget);
      await tester.ensureVisible(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await pumpLoaded(tester);
    }
    expect(find.text('Round done'), findsOneWidget);
    expect(await game.getStars(), 1000);
    expect(await game.secondsUntilNextRound(), greaterThan(0));
  });
}
