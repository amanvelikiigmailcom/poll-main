import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/screens/social/like_person_screen.dart';
import 'fakes/premium.dart';

const _question = 'Who makes everyone smile?';

Map<String, dynamic> _data({
  String name = 'Rival One',
  bool isPick = true,
  int? graduationYear = 2027,
}) => {
  'name': name,
  'question': _question,
  'isPick': isPick,
  if (graduationYear != null) 'graduationYear': graduationYear,
};

GoRouter _router({Map<String, dynamic>? data}) {
  final router = GoRouter(
    initialLocation: '/person',
    routes: [
      GoRoute(
        path: '/person',
        builder: (_, _) => LikePersonScreen(data: data),
      ),
      GoRoute(path: '/premium', builder: (_, _) => const Text('Premium stub')),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Future<void> _mount(WidgetTester tester, {Map<String, dynamic>? data}) async {
  await tester.pumpWidget(
    withPremium(
      MaterialApp.router(routerConfig: _router(data: data ?? _data())),
    ),
  );
}

void main() {
  testWidgets('person shows question, year, share and reveal actions', (
    tester,
  ) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Participant'), findsOneWidget);
    expect(find.text('Rival One'), findsOneWidget);
    expect(find.text('Class of 2027'), findsOneWidget);
    expect(find.text(_question), findsOneWidget);
    expect(find.text('Your pick'), findsOneWidget);
    expect(find.text('Share the result'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Snapchat'), findsOneWidget);
    expect(find.text('TikTok'), findsNothing);
    expect(find.text('Find out who voted for you'), findsOneWidget);
  });

  testWidgets('reveal opens the paywall without revealing the voter', (
    tester,
  ) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    final reveal = find.text('Find out who voted for you');
    await tester.ensureVisible(reveal);
    await tester.pumpAndSettle();
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(find.text('Premium stub'), findsOneWidget);
    expect(find.text('Participant'), findsNothing);
  });

  testWidgets('plain participant hides pick badge and class year', (
    tester,
  ) async {
    await _mount(tester, data: _data(isPick: false, graduationYear: null));
    await tester.pumpAndSettle();
    expect(find.text('Rival One'), findsOneWidget);
    expect(find.text('Your pick'), findsNothing);
    expect(find.textContaining('Class of'), findsNothing);
  });

  testWidgets('missing data shows the not-found state', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(data: null)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Person not found.'), findsOneWidget);
  });
}
