import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/social/like_person_screen.dart';
import 'package:flyprox_app/screens/social/likes_result_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'fakes/premium.dart';

const _question = 'Who makes everyone smile?';
const _friends = ['Alex', 'Sam', 'Jordan', 'Taylor'];

Map<String, dynamic> _like({List<Map<String, dynamic>>? participants}) => {
  'id': 'v1',
  'question': _question,
  'occurredAt': DateTime.now().toIso8601String(),
  if (participants != null) 'participants': participants,
};

GoRouter _router({Map<String, dynamic>? like}) {
  final router = GoRouter(
    initialLocation: '/details',
    routes: [
      GoRoute(
        path: '/details',
        builder: (_, _) => LikesResultScreen(like: like),
      ),
      GoRoute(
        path: '/likes-person',
        builder: (_, state) {
          final extra = state.extra;
          return LikePersonScreen(
            data: extra is Map ? Map<String, dynamic>.from(extra) : null,
          );
        },
      ),
      GoRoute(path: '/premium', builder: (_, _) => const Text('Premium stub')),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Future<void> _mount(WidgetTester tester, {Map<String, dynamic>? like}) async {
  await tester.pumpWidget(
    withPremium(
      MaterialApp.router(routerConfig: _router(like: like ?? _like())),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Me',
      friends: _friends,
    );
  });

  testWidgets(
    'missing server participants never substitutes local names or picks',
    (tester) async {
      await LocalGameService.instance.recordAnswer(
        RoundAnswer(
          questionId: 'q1',
          question: _question,
          voter: 'Me',
          choice: 'Alex',
        ),
      );
      await _mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Vote details'), findsOneWidget);
      expect(find.text(_question), findsOneWidget);
      expect(
        find.text('Participants are not available for this vote.'),
        findsOneWidget,
      );
      for (final name in _friends) {
        expect(find.text(name), findsNothing);
      }
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Share the result'), findsNothing);
      expect(find.text('Find out who voted for you'), findsOneWidget);
    },
  );

  testWidgets('server participants win over local names with class year', (
    tester,
  ) async {
    await _mount(
      tester,
      like: _like(
        participants: [
          {'id': 'u1', 'name': 'Rival One', 'graduationYear': 2027},
          {'id': 'u2', 'name': 'Rival Two'},
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Rival One'), findsOneWidget);
    expect(find.text('Rival Two'), findsOneWidget);
    expect(find.text('Class of 2027'), findsOneWidget);
    for (final name in _friends) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('tapping a participant opens share and reveal actions', (
    tester,
  ) async {
    await LocalGameService.instance.recordAnswer(
      RoundAnswer(
        questionId: 'q1',
        question: _question,
        voter: 'Me',
        choice: 'Rival One',
      ),
    );
    await _mount(
      tester,
      like: _like(
        participants: [
          {'id': 'u1', 'name': 'Rival One', 'graduationYear': 2027},
        ],
      ),
    );
    await tester.pumpAndSettle();
    final card = find.text('Rival One');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Participant'), findsOneWidget);
    expect(find.text('Class of 2027'), findsWidgets);
    expect(find.text('Your pick'), findsNothing);
    expect(find.text('Share the result'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Snapchat'), findsOneWidget);
    final reveal = find.text('Find out who voted for you');
    await tester.ensureVisible(reveal);
    await tester.pumpAndSettle();
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(find.text('Premium stub'), findsOneWidget);
  });

  testWidgets('empty circle state without saved names', (tester) async {
    await LocalGameService.instance.saveNames([]);
    await _mount(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Participants are not available for this vote.'),
      findsOneWidget,
    );
    expect(find.text('Vote details'), findsOneWidget);
  });

  testWidgets('missing like shows the not-found state', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(like: null)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Like not found.'), findsOneWidget);
  });
}
