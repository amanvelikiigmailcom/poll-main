import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flyprox_app/services/quiz_service.dart';
import 'package:flyprox_app/services/server_round_source.dart';

class MockQuizService extends Mock implements QuizService {}

QuizSession _session() => QuizSession(
      sessionId: 's1',
      questions: [
        QuizQuestion(id: 'q1', text: 'Who?', category: 'humor', candidates: [
          QuizCandidate(id: 'u1', firstName: 'A', lastName: 'B', grade: 8),
        ]),
      ],
      totalQuestions: 12,
    );

void main() {
  test('logged out resolves to null without touching the api', () async {
    final quiz = MockQuizService();
    final source = ServerRoundSource(quiz, isLoggedIn: () async => false);
    expect(await source.tryLoadSession(), isNull);
    verifyNever(() => quiz.getQuizzes());
  });

  test('logged in returns the server session', () async {
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer((_) async => _session());
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    final session = await source.tryLoadSession();
    expect(session?.sessionId, 's1');
    expect(session?.questions.length, 1);
  });

  test('api failure resolves to null', () async {
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    expect(await source.tryLoadSession(), isNull);
  });

  test('login check failure resolves to null', () async {
    final quiz = MockQuizService();
    final source =
        ServerRoundSource(quiz, isLoggedIn: () async => throw Exception('x'));
    expect(await source.tryLoadSession(), isNull);
    verifyNever(() => quiz.getQuizzes());
  });

  test('vote submits quiz and winner ids', () async {
    final quiz = MockQuizService();
    when(() => quiz.submitVote(quizId: 'q1', winnerId: 'u1')).thenAnswer(
        (_) async => const VoteResult(success: true, starsAwarded: 0));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await source.trySubmitVote(quizId: 'q1', winnerId: 'u1');
    verify(() => quiz.submitVote(quizId: 'q1', winnerId: 'u1')).called(1);
  });

  test('vote failure stays silent', () async {
    final quiz = MockQuizService();
    when(() => quiz.submitVote(quizId: 'q1', winnerId: 'u1'))
        .thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await source.trySubmitVote(quizId: 'q1', winnerId: 'u1');
  });

  test('hanging login check times out to the local game', () async {
    final quiz = MockQuizService();
    final source = ServerRoundSource(quiz,
        isLoggedIn: () => Completer<bool>().future);
    expect(await source.tryLoadSession(), isNull);
    verifyNever(() => quiz.getQuizzes());
  });
}
