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
            server.QuizCandidate(
                id: 'w$i', firstName: 'Winner', lastName: '$i', grade: 8),
            server.QuizCandidate(
                id: 'o${i}a', firstName: 'Other', lastName: 'A', grade: 8),
            server.QuizCandidate(
                id: 'o${i}b', firstName: 'Other', lastName: 'B', grade: 8),
            server.QuizCandidate(
                id: 'o${i}c', firstName: 'Other', lastName: 'C', grade: 8),
          ],
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vote screen shows intro round 1 with no category names',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );

    await tester.pumpWidget(const MaterialApp(home: VoteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(find.textContaining('make the whole group laugh'), findsOneWidget);
    expect(find.textContaining('Sympathy'), findsNothing);
    expect(find.textContaining('General'), findsNothing);
    expect(find.textContaining('Humor'), findsNothing);
    expect(find.textContaining('Симпатия'), findsNothing);
    expect(find.textContaining('Обычное'), findsNothing);
  });

  testWidgets('server branch renders server questions and submits votes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer((_) async => _serverSession());
    when(() => quiz.submitVote(quizId: 'sq0', winnerId: 'w0')).thenAnswer(
        (_) async => const server.VoteResult(success: true));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);

    await tester.pumpWidget(MaterialApp(home: VoteScreen(serverSource: source)));
    await tester.pumpAndSettle();

    expect(find.text('Server question 0'), findsOneWidget);
    await tester.tap(find.text('Winner 0'));
    await tester.pumpAndSettle();
    verify(() => quiz.submitVote(quizId: 'sq0', winnerId: 'w0')).called(1);
    expect(find.text('Question 2 of 12'), findsOneWidget);
  });

  testWidgets('server failure falls back to the local bank', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);

    await tester.pumpWidget(MaterialApp(home: VoteScreen(serverSource: source)));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(find.textContaining('Server question'), findsNothing);
  });
}
