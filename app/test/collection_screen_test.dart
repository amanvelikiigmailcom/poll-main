import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/profile/collection_screen.dart';
import 'package:flyprox_app/screens/profile/profile_screen.dart';
import 'package:flyprox_app/screens/voting/star_received_screen.dart';
import 'package:flyprox_app/services/collection_service.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'fakes/collection_api.dart';
import 'fakes/social_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
  });

  Future<({GoRouter router, CollectionApiFake api, SessionStorage storage})>
  mount(
    WidgetTester tester, {
    int stars = 25000,
    bool fail = false,
    bool guest = false,
    Completer<void>? pending,
    Widget? entry,
    double textScale = 1,
  }) async {
    final storage = SessionStorage()..token = guest ? null : 'buyer';
    final api = CollectionApiFake(storage)
      ..balance = stars
      ..failLoad = fail
      ..pending = pending;
    final shop = CollectionService(api, storage);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => entry ?? const CollectionScreen(),
        ),
        GoRoute(
          path: '/collection',
          builder: (_, _) => const CollectionScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, _) => const Scaffold(body: Text('Profile destination')),
        ),
        GoRoute(
          path: '/phone',
          builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          collectionServiceProvider.overrideWith((ref) => shop),
          starBalanceProvider.overrideWith((ref) async => stars),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 650),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    return (router: router, api: api, storage: storage);
  }

  testWidgets('balance and insufficient state; close falls back to profile', (
    tester,
  ) async {
    final result = await mount(tester, stars: 1000);
    await tester.pumpAndSettle();
    expect(find.text('⭐ 1,000'), findsOneWidget);
    await tester.ensureVisible(find.text('⭐ 5,000'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough stars'), findsWidgets);
    final purchase = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '⭐ 5,000'),
    );
    expect(purchase.onPressed, isNull);
    await tester.ensureVisible(find.text('⭐ 20,000'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough stars'), findsWidgets);
    final second = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '⭐ 20,000'),
    );
    expect(second.onPressed, isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      result.router.routeInformationProvider.value.uri.path,
      AppRoutes.profile,
    );
  });

  testWidgets('cancel does not buy; confirm updates absolute balance', (
    tester,
  ) async {
    final result = await mount(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('⭐ 5,000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⭐ 5,000'));
    await tester.pumpAndSettle();
    expect(find.text('Buy boost?'), findsOneWidget);
    expect(find.textContaining('at most 1 crush'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result.api.requests, isEmpty);
    await tester.tap(find.text('⭐ 5,000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(result.api.requests.length, 1);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '⭐ 20,000' &&
            widget.style?.fontSize == 48,
      ),
      findsOneWidget,
    ); // absolute balance updated
  });

  testWidgets(
    'double tap opens one confirmation and logout invalidates that confirmation',
    (tester) async {
      final result = await mount(tester);
      await tester.pumpAndSettle();
      final buy = tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('⭐ 5,000'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed!;
      // Deliver two activations before the dialog has blocked pointer input.
      buy();
      buy();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await result.storage.clearToken();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy'));
      await tester.pumpAndSettle();
      expect(result.api.requests, isEmpty);
      expect(find.text('Sign in to use your stars'), findsOneWidget);
    },
  );

  testWidgets(
    'unconfirmed purchase exposes a safe retry and disables the other boost',
    (tester) async {
      final result = await mount(tester);
      await tester.pumpAndSettle();
      result.api.loseReply = true;
      await tester.ensureVisible(find.text('⭐ 5,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('⭐ 5,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy'));
      await tester.pumpAndSettle();
      expect(find.text('Check purchase'), findsOneWidget);
      final other = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '⭐ 20,000'),
      );
      expect(other.onPressed, isNull);
      result.api.loseReply = false;
      await tester.tap(find.text('Check purchase'));
      await tester.pumpAndSettle();
      expect(result.api.requests.length, 2);
      expect(
        result.api.requests[0]['requestId'],
        result.api.requests[1]['requestId'],
      );
      expect(result.api.balance, 20000);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'skeleton, failed load and retry are distinct from zero balance',
    (tester) async {
      final pending = Completer<void>();
      final result = await mount(tester, pending: pending);
      expect(find.bySemanticsLabel('Loading collection'), findsWidgets);
      result.api.failLoad = true;
      pending.complete();
      await tester.pumpAndSettle();
      // The first request was already accepted by the fake; explicitly refresh.
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t load your balance. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('⭐ 0'), findsNothing);
      result.api.failLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('⭐ 25,000'), findsOneWidget);
    },
  );

  testWidgets('collection explains itself and its benefits', (tester) async {
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('What is Collection?'), findsOneWidget);
    expect(
      find.text(
        'Stars are in-game points. Spend them on boosts that put your name in more polls.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('More placements, more chances to be voted for.'),
      findsOneWidget,
    );
  });

  testWidgets('guest cannot spend and gets a sign-in action', (tester) async {
    final result = await mount(tester, guest: true);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to use your stars'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
    expect(result.api.requests, isEmpty);
  });

  testWidgets('profile Collection card opens the shop', (tester) async {
    final result = await mount(
      tester,
      entry: const Scaffold(body: CollectionProfileCard()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(result.router.canPop(), isTrue);
    expect(find.text('IN-GAME POINTS'), findsOneWidget);
  });

  testWidgets('reward Collection action opens shop and preserves return path', (
    tester,
  ) async {
    final result = await mount(tester, entry: const StarReceivedScreen());
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(result.router.canPop(), isTrue);
    expect(find.text('IN-GAME POINTS'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Your round is complete.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small screen and large text stay scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, textScale: 1.8);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('How do I earn stars?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
