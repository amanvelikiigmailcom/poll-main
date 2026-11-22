import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/quiz_service.dart' as server;
import 'package:flyprox_app/services/server_round_source.dart';

class MockQuizService extends Mock implements server.QuizService {}

server.QuizSession _serverSession() => server.QuizSession(
  sessionId: 'srv1',
  totalQuestions: 12,
  questions: List.generate(
    12,
    (i) => server.QuizQuestion(
      id: 'sq$i',
      text: 'Server question $i',
      category: 'humor',
      candidates: [
        const server.QuizCandidate(
          id: 'self',
          firstName: 'Али',
          lastName: '',
          grade: 8,
          isSelf: true,
        ),
        for (final name in ['Али', 'Маша', 'Даня', 'Саша'])
          server.QuizCandidate(
            id: 'user_$name',
            firstName: name,
            lastName: '',
            grade: 8,
          ),
        const server.QuizCandidate(
          id: 'stranger',
          firstName: 'Stranger',
          lastName: '',
          grade: 8,
        ),
      ],
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vote screen shows intro round 1 with no category names', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );

    await tester.pumpWidget(const MaterialApp(home: VoteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(find.text('Аман'), findsNothing);
    expect(find.textContaining('make the whole group laugh'), findsOneWidget);
    expect(find.textContaining('Sympathy'), findsNothing);
    expect(find.textContaining('General'), findsNothing);
    expect(find.textContaining('Humor'), findsNothing);
    expect(find.textContaining('Симпатия'), findsNothing);
    expect(find.textContaining('Обычное'), findsNothing);
  });

  testWidgets('server branch renders server questions and submits votes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer((_) async => _serverSession());
    when(
      () => quiz.submitVote(quizId: 'sq0', winnerId: 'user_Али'),
    ).thenAnswer((_) async => const server.VoteResult(success: true));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);

    await tester.pumpWidget(
      MaterialApp(home: VoteScreen(serverSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server question 0'), findsOneWidget);
    expect(find.text('Stranger'), findsNothing);
    expect(find.text('Аман'), findsNothing);
    for (final name in ['Али', 'Маша', 'Даня', 'Саша']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('Али'));
    await tester.pumpAndSettle();
    verify(
      () => quiz.submitVote(quizId: 'sq0', winnerId: 'user_Али'),
    ).called(1);
    expect(find.text('Question 2 of 12'), findsOneWidget);
  });

  testWidgets(
    'unmatched selected names stay on cards and never vote for strangers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final friends = ['Local 1', 'Local 2', 'Local 3', 'Local 4'];
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Me',
        friends: friends,
      );
      final quiz = MockQuizService();
      when(() => quiz.getQuizzes()).thenAnswer((_) async => _serverSession());
      when(
        () => quiz.submitVote(quizId: 'sq0', winnerId: null),
      ).thenAnswer((_) async => const server.VoteResult(success: true));
      await tester.pumpWidget(
        MaterialApp(
          home: VoteScreen(
            serverSource: ServerRoundSource(quiz, isLoggedIn: () async => true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stranger'), findsNothing);
      final visible = friends
          .where((name) => find.text(name).evaluate().isNotEmpty)
          .toList();
      expect(visible.length, 4);
      expect(find.text('Me'), findsNothing);
      await tester.tap(find.text(visible.first));
      await tester.pumpAndSettle();
      verify(() => quiz.submitVote(quizId: 'sq0', winnerId: null)).called(1);
      expect(find.text('Question 2 of 12'), findsOneWidget);
    },
  );

  testWidgets('server failure falls back to the local bank', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);

    await tester.pumpWidget(
      MaterialApp(home: VoteScreen(serverSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(find.textContaining('Server question'), findsNothing);
  });
}
