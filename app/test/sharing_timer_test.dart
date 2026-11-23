import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/social/invite_friend_screen.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'package:flyprox_app/screens/voting/timer_screen.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';

GoRouter makeRouter(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/invite', builder: (_, __) => const InviteFriendScreen()),
    GoRoute(path: '/timer', builder: (_, __) => const TimerScreen()),
    GoRoute(
      path: '/vote',
      builder: (_, __) => const Scaffold(body: Text('Quiz ready')),
    ),
    GoRoute(path: '/play', builder: (_, __) => const VoteScreen()),
    GoRoute(
      path: '/star-received',
      builder: (_, __) => const Scaffold(body: Text('Round done')),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const Scaffold(body: Text('Home')),
    ),
  ],
);

Future<void> pumpLoaded(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Premium does not remove the waiting period', (tester) async {
    await SubscriptionService.instance.setPro(true);
    await LocalGameService.instance.completeRound();
    final router = makeRouter('/timer');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    expect(
      await LocalGameService.instance.secondsUntilNextRound(),
      greaterThan(3500),
    );
    expect(find.text('Quiz ready'), findsNothing);
    await SubscriptionService.instance.setPro(false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('timer restores saved time and expired timer opens next round', (
    tester,
  ) async {
    final game = LocalGameService.instance;
    await game.completeRound();
    final prefs = await SharedPreferences.getInstance();
    final timeKey = prefs.getKeys().singleWhere(
      (key) => prefs.get(key) is int && prefs.getInt(key)! > 1000000000000,
    );
    await prefs.setInt(
      timeKey,
      DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
    );
    final router = makeRouter('/timer');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    expect(find.text('40:00'), findsNothing);
    expect(await game.secondsUntilNextRound(), inInclusiveRange(2998, 3000));
    await prefs.setInt(
      timeKey,
      DateTime.now()
          .subtract(const Duration(minutes: 61))
          .millisecondsSinceEpoch,
    );
    await tester.pump(const Duration(seconds: 1));
    await pumpLoaded(tester);
    expect(find.text('Quiz ready'), findsOneWidget);
  });

  testWidgets('Shuffle works repeatedly and all 12 questions can be skipped', (
    tester,
  ) async {
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
      playerName: 'Player',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
    final router = makeRouter('/play');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpLoaded(tester);
    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(find.text('Shuffle'));
      await tester.tap(find.text('Shuffle'));
      await tester.pump();
      expect(find.text('Question 1 of 12'), findsOneWidget);
      // All four cards belong to selected contacts, never the player.
      expect(find.text('Player'), findsNothing);
      var shown = 0;
      for (final name in ['Alex', 'Sam', 'Jordan', 'Taylor']) {
        final count = find.text(name).evaluate().length;
        expect(count, lessThanOrEqualTo(1));
        shown += count;
      }
      expect(shown, 4);
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
