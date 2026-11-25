import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/widgets/common/voter_reveal_card.dart';
import 'fakes/premium.dart';
import 'fakes/social_storage.dart';

Future<void> mount(
  WidgetTester tester,
  FakePremium premium, {
  SessionStorage? storage,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: VoterRevealCard(voteId: 'v1')),
      ),
      GoRoute(
        path: '/premium',
        builder: (_, _) => const Scaffold(body: Text('Paywall')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    withPremium(
      MaterialApp.router(routerConfig: router),
      premium: premium,
      storage: storage,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'inactive server entitlement opens paywall and never reveals locally',
    (tester) async {
      final premium = FakePremium();
      await mount(tester, premium);
      await tester.tap(find.text('See who picked you'));
      await tester.pumpAndSettle();
      expect(find.text('Paywall'), findsOneWidget);
      expect(premium.spends, 0);
      expect(find.textContaining('Maria'), findsNothing);
    },
  );
  testWidgets(
    'Premium offers independent server quotas and renders initial/year then full name',
    (tester) async {
      final premium = FakePremium()..active = true;
      await mount(tester, premium);
      expect(find.text('From a girl · Class of 2028'), findsOneWidget);
      await tester.tap(find.text('See who picked you'));
      await tester.pumpAndSettle();
      expect(find.text('2 left this week'), findsOneWidget);
      expect(find.text('5 left this week'), findsOneWidget);
      expect(find.textContaining('Max'), findsNothing);
      await tester.tap(find.text('Reveal first initial'));
      await tester.pumpAndSettle();
      expect(find.text('From M. (girl) · Class of 2028'), findsOneWidget);
      await tester.tap(find.text('See who picked you'));
      await tester.pumpAndSettle();
      expect(find.text('4 left this week'), findsOneWidget);
      await tester.tap(find.text('Reveal full name'));
      await tester.pumpAndSettle();
      expect(
        find.text('From Maria Rivera (girl) · Graduating in 2028'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'network error never falls back to paywall or locally unlocks identity',
    (tester) async {
      final premium = FakePremium()
        ..failure = const ApiException('Network unavailable', statusCode: 503);
      await mount(tester, premium);
      await tester.tap(find.text('See who picked you'));
      await tester.pumpAndSettle();
      expect(find.text('Network unavailable'), findsOneWidget);
      expect(find.text('Paywall'), findsNothing);
      expect(premium.spends, 0);
    },
  );
  testWidgets('account change clears an unlocked name immediately', (
    tester,
  ) async {
    final storage = SessionStorage();
    final premium = FakePremium(storage)
      ..active = true
      ..revealed = 'full';
    await mount(tester, premium, storage: storage);
    expect(find.textContaining('Maria Rivera'), findsOneWidget);
    await storage.clearToken();
    await tester.pump();
    expect(find.textContaining('Maria Rivera'), findsNothing);
  });
  for (final kind in ['full', 'initial']) {
    testWidgets(
      'protected $kind explains the author also bought Premium and preserves 2/5 attempts',
      (tester) async {
        final premium = FakePremium()
          ..active = true
          ..protected = true;
        await mount(tester, premium);
        expect(find.text('This user also has Premium'), findsOneWidget);
        expect(
          find.textContaining('Your reveal was not used.'),
          findsOneWidget,
        );
        expect(find.textContaining('Maria'), findsNothing);
        await tester.tap(find.text('Find out who voted for you'));
        await tester.pumpAndSettle();
        expect(find.text('2 left this week'), findsOneWidget);
        expect(find.text('5 left this week'), findsOneWidget);
        await tester.tap(
          find.text(
            kind == 'full' ? 'Reveal full name' : 'Reveal first initial',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This user also has Premium. Their votes are protected. Your reveal was not used.',
          ),
          findsOneWidget,
        );
        expect(premium.spends, 0);
        expect(premium.full, 2);
        expect(premium.initial, 5);
        expect(find.textContaining('Maria'), findsNothing);
        expect(find.textContaining('From M.'), findsNothing);
      },
    );
  }
  testWidgets(
    'author purchasing Premium hides a previously unlocked name on refresh',
    (tester) async {
      final premium = FakePremium()
        ..active = true
        ..revealed = 'full';
      await mount(tester, premium);
      expect(find.textContaining('Maria Rivera'), findsOneWidget);
      premium.protected = true;
      await tester.tap(find.text('Find out who voted for you'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Maria Rivera'), findsNothing);
      await tester.tap(find.text('Reveal full name'));
      await tester.pumpAndSettle();
      expect(find.text('This user also has Premium'), findsOneWidget);
      expect(premium.spends, 0);
    },
  );
  for (final code in [403, 429]) {
    testWidgets(
      'server $code during reveal keeps quota and handles access change',
      (tester) async {
        final premium = FakePremium()..active = true;
        await mount(tester, premium);
        await tester.tap(find.text('Find out who voted for you'));
        await tester.pumpAndSettle();
        premium.failure = ApiException(
          code == 429
              ? 'Your reveals reset on January 1.'
              : 'An active Premium subscription is required.',
          statusCode: code,
        );
        await tester.tap(find.text('Reveal full name'));
        await tester.pumpAndSettle();
        if (code == 403) {
          expect(find.text('Paywall'), findsOneWidget);
        } else {
          expect(find.text('Your reveals reset on January 1.'), findsOneWidget);
          expect(find.text('Paywall'), findsNothing);
        }
        expect(premium.spends, 0);
        expect(premium.full, 2);
        expect(premium.initial, 5);
        expect(find.textContaining('Maria'), findsNothing);
      },
    );
  }
  testWidgets('protected explanation fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final premium = FakePremium()
      ..active = true
      ..protected = true;
    await tester.pumpWidget(
      withPremium(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(body: VoterRevealCard(voteId: 'v1')),
        ),
        premium: premium,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This user also has Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
