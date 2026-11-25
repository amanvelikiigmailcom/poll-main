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
    expect(find.text('Premium benefits'), findsNothing);
    expect(find.text('Don’t want to wait 60 minutes?'), findsOneWidget);
    expect(find.text('Invite a friend'), findsOneWidget);
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

  testWidgets(
    'Skip and Shuffle each allow two uses, retain limits on resume and complete the round',
    (tester) async {
      final game = LocalGameService.instance;
      final names = [
        'Alex',
        'Sam',
        'Jordan',
        'Taylor',
        'Morgan',
        'Casey',
        'Riley',
        'Jamie',
      ];
      await game.savePlayerAndFriends(playerName: 'Player', friends: names);
      final router = makeRouter('/play');
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpLoaded(tester);
      Set<String> shown() =>
          names.where((name) => find.text(name).evaluate().isNotEmpty).toSet();
      final first = shown();
      expect(first, hasLength(4));
      for (var remaining = 2; remaining > 0; remaining--) {
        await tester.ensureVisible(find.text('Shuffle ($remaining)'));
        await tester.tap(find.text('Shuffle ($remaining)'));
        await tester.pumpAndSettle();
        expect(find.text('Question 1 of 12'), findsOneWidget);
        expect(find.text('Player'), findsNothing);
        expect(shown(), hasLength(4));
        if (remaining == 2) expect(shown().intersection(first), isEmpty);
      }
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Shuffle (0)'),
            )
            .onPressed,
        isNull,
      );
      for (var remaining = 2; remaining > 0; remaining--) {
        await tester.ensureVisible(find.text('Skip ($remaining)'));
        await tester.tap(find.text('Skip ($remaining)'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Question 3 of 12'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Skip (0)'),
            )
            .onPressed,
        isNull,
      );
      router.go('/home');
      await tester.pumpAndSettle();
      router.go('/play');
      await tester.pumpAndSettle();
      expect(find.text('Question 3 of 12'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Shuffle (0)'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Skip (0)'),
            )
            .onPressed,
        isNull,
      );
      for (var i = 3; i <= 12; i++) {
        expect(find.text('Question $i of 12'), findsOneWidget);
        await tester.tap(find.text(shown().first));
        await tester.pumpAndSettle();
      }
      expect(find.text('10 answered · 2 skipped'), findsOneWidget);
      expect(await game.secondsUntilNextRound(), 0);
      await tester.tap(find.text('Finish round'));
      await pumpLoaded(tester);
      expect(find.text('Round done'), findsOneWidget);
      expect(await game.getStars(), 1000);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
