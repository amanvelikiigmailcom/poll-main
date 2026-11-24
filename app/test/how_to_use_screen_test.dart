import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/info/how_to_use_screen.dart';
import 'package:flyprox_app/services/game_settings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
  });

  Future<GoRouter> mount(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HowToUseScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('Home destination')),
        ),
        GoRoute(
          path: AppRoutes.invite,
          builder: (_, _) => const Scaffold(body: Text('Invite destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('renders hero, quick start and all section titles', (
    tester,
  ) async {
    await mount(tester);

    expect(find.text('How to use Flyprox'), findsOneWidget);
    expect(find.text('Rules, stars and 20 pro tips — everything in one guide.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('howto-search')), findsOneWidget);
    // Quick-start timeline keeps its five steps.
    for (final title in [
      'Create your profile',
      'Add 4+ people',
      'Answer 12 questions',
      'Collect 1,000 stars',
      'Play again your way',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // Section tiles render collapsed with their titles.
    for (final title in [
      'Game rules',
      'Breaks & daily limits',
      'Stars & Collection',
      'Invitations & wait passes',
      'Friends & search',
      'Likes & Activity',
      'Campus & profile',
      'Privacy & safety',
      'Premium',
      '20 pro tips',
    ]) {
      expect(find.text(title), findsWidgets);
    }
    // Collapsed bodies stay hidden until expanded.
    expect(find.textContaining('You cannot vote for yourself'), findsNothing);
    expect(find.text('0 of 10 sections explored'), findsOneWidget);
  });

  testWidgets('expanding a section reveals rules and moves progress', (
    tester,
  ) async {
    await mount(tester);

    await scrollTo(tester, find.widgetWithText(ActionChip, 'Game rules'));
    await tester.tap(find.widgetWithText(ActionChip, 'Game rules'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You cannot vote for yourself'), findsOneWidget);
    expect(find.text('1 of 10 sections explored'), findsOneWidget);

    await scrollTo(tester, find.text('Expand all'));
    await tester.tap(find.text('Expand all'));
    await tester.pumpAndSettle();
    expect(find.text('Guide complete — nice!'), findsOneWidget);
    expect(find.textContaining('Who voted for you is never revealed'),
        findsOneWidget);
    expect(find.textContaining('Replay the intro from Settings anytime'),
        findsOneWidget);
  });

  testWidgets('search filters the guide and empty state clears', (
    tester,
  ) async {
    await mount(tester);

    await tester.enterText(
      find.byKey(const ValueKey('howto-search')),
      'crush',
    );
    await tester.pumpAndSettle();
    // Matching section opens with its bullets visible…
    expect(find.textContaining('at most 1 crush question'), findsOneWidget);
    // …while unrelated sections are filtered out.
    expect(find.text('Privacy & safety'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('howto-search')),
      'zebra-quiz-xyz',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches for'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Quick start'), findsOneWidget);
  });

  testWidgets('ready card navigates to home and invite', (tester) async {
    final router = await mount(tester);

    await scrollTo(tester, find.byKey(const ValueKey('howto-invite')));
    await tester.tap(find.byKey(const ValueKey('howto-invite')));
    await tester.pumpAndSettle();
    expect(find.text('Invite destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.invite);

    router.go('/');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('howto-start')));
    await tester.tap(find.byKey(const ValueKey('howto-start')));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.home);
  });

  testWidgets('works with reduce motion enabled', (tester) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    await mount(tester);

    expect(find.text('How to use Flyprox'), findsOneWidget);
    await scrollTo(tester, find.widgetWithText(ActionChip, 'Premium'));
    await tester.tap(find.widgetWithText(ActionChip, 'Premium'));
    await tester.pumpAndSettle();
    expect(find.textContaining('never skips the 60-minute wait'), findsOneWidget);
  });
}
