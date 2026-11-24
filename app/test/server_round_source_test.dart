import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flyprox_app/services/quiz_service.dart';
import 'package:flyprox_app/services/server_round_source.dart';
import 'package:flyprox_app/services/api_service.dart';

class MockQuizService extends Mock implements QuizService {}

QuizSession _session() => QuizSession(
  sessionId: 's1',
  questions: [
    QuizQuestion(
      id: 'q1',
      text: 'Who?',
      category: 'humor',
      candidates: [
        QuizCandidate(id: 'u1', firstName: 'A', lastName: 'B', grade: 8),
      ],
    ),
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

  test('daily limit cannot fall back into an unlocked local round', () async {
    final quiz = MockQuizService();
    when(
      () => quiz.getQuizzes(),
    ).thenThrow(const ApiException('50 rounds reached', statusCode: 429));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await expectLater(source.tryLoadSession(), throwsA(isA<ApiException>()));
  });

  test('api failure resolves to null', () async {
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    expect(await source.tryLoadSession(), isNull);
  });

  test('login check failure resolves to null', () async {
    final quiz = MockQuizService();
    final source = ServerRoundSource(
      quiz,
      isLoggedIn: () async => throw Exception('x'),
    );
    expect(await source.tryLoadSession(), isNull);
    verifyNever(() => quiz.getQuizzes());
  });

  test('vote submits quiz and winner ids', () async {
    final quiz = MockQuizService();
    when(
      () => quiz.submitVote(quizId: 'q1', winnerId: 'u1'),
    ).thenAnswer((_) async => const VoteResult(success: true, starsAwarded: 0));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await source.trySubmitVote(quizId: 'q1', winnerId: 'u1');
    verify(() => quiz.submitVote(quizId: 'q1', winnerId: 'u1')).called(1);
  });

  test('vote failure stays silent', () async {
    final quiz = MockQuizService();
    when(
      () => quiz.submitVote(quizId: 'q1', winnerId: 'u1'),
    ).thenThrow(Exception('offline'));
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await source.trySubmitVote(quizId: 'q1', winnerId: 'u1');
  });

  test('hanging login check times out to the local game', () async {
    final quiz = MockQuizService();
    final source = ServerRoundSource(
      quiz,
      isLoggedIn: () => Completer<bool>().future,
    );
    expect(await source.tryLoadSession(), isNull);
    verifyNever(() => quiz.getQuizzes());
  });

  test('draft follows the verified account, not a new sign-in', () async {
    final quiz = MockQuizService();
    var token = 'first-session';
    final source = ServerRoundSource(
      quiz,
      isLoggedIn: () async => true,
      readToken: () async => token,
    );
    when(
      () => quiz.getQuizzes(sessionToken: 'first-session'),
    ).thenAnswer((_) async => _session());
    when(
      () => quiz.getAccountId('other-session'),
    ).thenAnswer((_) async => 'other');
    when(
      () => quiz.getAccountId('renewed-session'),
    ).thenAnswer((_) async => 'owner');
    final reply = Completer<void>();
    final answers = {'q1': 'friend'};
    when(
      () => quiz.submitRound(
        sessionId: 's1',
        answers: answers,
        sessionToken: 'renewed-session',
      ),
    ).thenAnswer((_) => reply.future);
    await source.tryLoadSession();
    final key = source.loadedSessionKey;
    expect(await source.ownsDraft(key, ownerId: 'owner'), isTrue);

    token = 'other-session';
    expect(await source.ownsDraft(key, ownerId: 'owner'), isFalse);
    await expectLater(
      source.submitRound(
        sessionId: 's1',
        sessionKey: key,
        ownerId: 'owner',
        answers: answers,
      ),
      throwsA(isA<ApiException>()),
    );
    verifyNever(
      () => quiz.submitRound(
        sessionId: 's1',
        answers: answers,
        sessionToken: 'other-session',
      ),
    );

    token = 'renewed-session';
    expect(await source.ownsDraft(key, ownerId: 'owner'), isTrue);
    final sending = source.submitRound(
      sessionId: 's1',
      sessionKey: key,
      ownerId: 'owner',
      answers: answers,
    );
    final checked = expectLater(sending, throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    verify(
      () => quiz.submitRound(
        sessionId: 's1',
        answers: answers,
        sessionToken: 'renewed-session',
      ),
    ).called(1);
    token = 'other-session';
    reply.complete();
    await checked;
  });
}
