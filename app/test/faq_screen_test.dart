import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/info/faq_screen.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/social_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
    await SubscriptionService.instance.resetForTest();
    gateway = FakeGateway();
    SubscriptionService.instance.debugGateway(gateway);
  });
  tearDown(() async {
    await SubscriptionService.instance.resetForTest();
    await gateway.events.close();
  });

  Future<GoRouter> mount(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const FaqScreen()),
        GoRoute(
          path: AppRoutes.safetyCenter,
          builder: (_, _) => const Scaffold(body: Text('Safety destination')),
        ),
        GoRoute(
          path: AppRoutes.howToUse,
          builder: (_, _) => const Scaffold(body: Text('Guide destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> mountSettings(WidgetTester tester) async {
    final storage = SessionStorage()..token = null;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: AppRoutes.faq,
          builder: (_, _) => const Scaffold(body: Text('FAQ destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  // Settings uses a lazy ListView: unbuilt tiles need scrollUntilVisible.
  Future<void> scrollSettingsTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 400);
    await tester.pumpAndSettle();
  }

  testWidgets('renders hero, search and all category chips', (tester) async {
    await mount(tester);

    expect(find.text('Frequently asked questions'), findsOneWidget);
    expect(
      find.text('Short answers about rounds, stars, friends and privacy.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('faq-search')), findsOneWidget);
    expect(find.text('38 answers'), findsOneWidget);
    expect(find.text('9 topics'), findsOneWidget);
    for (final title in [
      'Getting started',
      'Rounds & voting',
      'Breaks & limits',
      'Stars & Collection',
      'Friends & search',
      'Likes & Activity',
      'Campus & profile',
      'Privacy & safety',
      'Premium & account',
    ]) {
      expect(find.widgetWithText(ActionChip, title), findsOneWidget);
    }
    // Collapsed answers stay hidden until expanded.
    expect(find.textContaining('You cannot vote for yourself'), findsNothing);
    expect(find.text('0 of 38 questions explored'), findsOneWidget);
  });

  testWidgets('expanding a question reveals the answer and moves progress', (
    tester,
  ) async {
    await mount(tester);

    await tester.tap(find.text('How do I start playing?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 4 people'), findsOneWidget);
    expect(find.text('1 of 38 questions explored'), findsOneWidget);

    await tester.tap(find.text('Expand all'));
    await tester.pumpAndSettle();
    expect(find.text('All questions explored — nice!'), findsOneWidget);
    expect(
      find.textContaining('Premium never skips the 60-minute wait'),
      findsOneWidget,
    );
    expect(find.textContaining('Hashing is not anonymity'), findsOneWidget);
  });

  testWidgets('category chip jumps to the category', (tester) async {
    await mount(tester);

    final heading = find.text('Premium & account').last;
    expect(tester.getTopLeft(heading).dy, greaterThan(600));
    await scrollTo(
      tester,
      find.widgetWithText(ActionChip, 'Premium & account'),
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Premium & account'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Premium & account').last).dy,
      lessThan(600),
    );
  });

  testWidgets(
    'new FAQ layout explains weekly Premium and removes old anonymity promise',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('faq-search')),
        'What can Premium reveal?',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('2 full-name voter reveals and 5 first-initial'),
        findsOneWidget,
      );
      expect(find.textContaining('older votes remain hidden'), findsOneWidget);
      expect(find.text('What is Full Reveal?'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('faq-search')),
        'Can I see who voted for me?',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('limited weekly reveals'), findsOneWidget);
      expect(
        find.text('No. Voter names and IDs are never shown.'),
        findsNothing,
      );
    },
  );

  testWidgets('search filters questions and empty state clears', (
    tester,
  ) async {
    await mount(tester);

    await tester.enterText(find.byKey(const ValueKey('faq-search')), 'crush');
    await tester.pumpAndSettle();
    // Matching question opens with its answer visible…
    expect(find.textContaining('1 crush question'), findsOneWidget);
    // …while unrelated categories are filtered out.
    expect(find.text('Privacy & safety'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('faq-search')),
      'zebra-quiz-xyz',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches for'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Getting started'), findsOneWidget);
  });

  testWidgets('help footer navigates to safety center and guide', (
    tester,
  ) async {
    final router = await mount(tester);

    await scrollTo(tester, find.byKey(const ValueKey('faq-safety')));
    await tester.tap(find.byKey(const ValueKey('faq-safety')));
    await tester.pumpAndSettle();
    expect(find.text('Safety destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.safetyCenter);

    router.go('/');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('faq-howto')));
    await tester.tap(find.byKey(const ValueKey('faq-howto')));
    await tester.pumpAndSettle();
    expect(find.text('Guide destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.howToUse);
  });

  testWidgets('works with reduce motion enabled', (tester) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    await mount(tester);

    expect(find.text('Frequently asked questions'), findsOneWidget);
    await scrollTo(tester, find.text('Does Premium skip the wait?'));
    await tester.tap(find.text('Does Premium skip the wait?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Premium never skips the 60-minute wait'),
      findsOneWidget,
    );
  });

  testWidgets('settings links to the FAQ screen', (tester) async {
    final router = await mountSettings(tester);

    await scrollSettingsTo(tester, find.text('FAQ'));
    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(find.text('FAQ destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.faq);
  });
}
