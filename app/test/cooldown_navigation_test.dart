import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';

Future<void> pumpRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> mount(WidgetTester tester, String route) async {
  final storage = StorageService();
  await storage.init();
  appRouter.go(route);
  await tester.pumpWidget(ProviderScope(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
    child: MaterialApp.router(routerConfig: appRouter),
  ));
  await pumpRoute(tester);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan']);
  });

  testWidgets(
      'center tab preserves the same cooldown through repeated navigation',
      (tester) async {
    final game = LocalGameService.instance;
    await game.completeRound();
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getInt('local_last_round_completed_at');
    await mount(tester, AppRoutes.home);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
      await pumpRoute(tester);
      expect(
          appRouter.routeInformationProvider.value.uri.path, AppRoutes.timer);
      expect(prefs.getInt('local_last_round_completed_at'), original);
      expect(find.text('Question 1 of 12'), findsNothing);
      appRouter.go(AppRoutes.home);
      await pumpRoute(tester);
    }
    await game.bypassTimer();
    await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
    await pumpRoute(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.vote);
    expect(find.text('Question 1 of 12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final route in [AppRoutes.vote]) {
    testWidgets('$route cannot bypass an active cooldown', (tester) async {
      await LocalGameService.instance.completeRound();
      await mount(tester, route);
      expect(
          appRouter.routeInformationProvider.value.uri.path, AppRoutes.timer);
      expect(find.text('Question 1 of 12'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('expired cooldown allows the center tab to open a round',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'local_last_round_completed_at',
        DateTime.now()
            .subtract(const Duration(minutes: 41))
            .millisecondsSinceEpoch);
    await mount(tester, AppRoutes.home);
    await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
    await pumpRoute(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.vote);
    await tester.pumpWidget(const SizedBox());
  });
}
