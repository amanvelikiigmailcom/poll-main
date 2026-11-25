import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/widgets/common/voter_reveal_card.dart';
import 'package:flyprox_app/widgets/common/premium_badge.dart';
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
        find.text('From Maria Rivera (girl) · Class of 2028'),
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
  testWidgets(
    'badge requires server status and expiry; expires on an open page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumBadge(
            active: true,
            until: DateTime.now()
                .add(const Duration(seconds: 2))
                .toIso8601String(),
          ),
        ),
      );
      expect(find.byIcon(Icons.verified), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(Icons.verified), findsNothing);
    },
  );
}
