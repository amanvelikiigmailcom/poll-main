import 'dart:async';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/quiz_service.dart' as server;
import 'package:flyprox_app/services/server_round_source.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'fakes/social_storage.dart';

class MockQuizService extends Mock implements server.QuizService {}

server.QuizSession _serverSession() => server.QuizSession(
  sessionId: 'srv1',
  totalQuestions: 12,
  supportsRoundSubmission: true,
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
            firstName: name == 'Саша' ? 'Different registered name' : name,
            contactHash: name == 'Саша' ? 'local-sasha-hash' : null,
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

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

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

  testWidgets('school round uses server classmates without local contacts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = SessionStorage();
    await storage.init();
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: request,
              data: request.path == '/api/quizzes/mode'
                  ? {
                      'mode': 'school',
                      'enrolled': true,
                      'joined': 5,
                      'threshold': 5,
                    }
                  : {},
            ),
          );
        },
      ),
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer(
      (_) async => server.QuizSession(
        sessionId: 'school-round',
        totalQuestions: 12,
        ownerId: 'me',
        supportsRoundSubmission: true,
        schoolVoting: true,
        questions: [
          for (var i = 0; i < 12; i++)
            server.QuizQuestion(
              id: 'campus-$i',
              text: 'Campus question $i',
              category: 'normal',
              candidates: const [
                server.QuizCandidate(
                  id: 'me',
                  firstName: 'The voter',
                  lastName: '',
                  grade: 8,
                ),
                server.QuizCandidate(
                  id: 'friend',
                  firstName: 'Classmate A',
                  lastName: '',
                  grade: 8,
                ),
              ],
            ),
        ],
      ),
    );
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        apiServiceProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onboardingDetailsProvider).draft({
      'stage': 'done',
      'status': 'selected',
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: VoteScreen(serverSource: source)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Campus question 0'), findsOneWidget);
    expect(find.text('Classmate A'), findsOneWidget);
    expect(find.text('The voter'), findsNothing);
    expect(await LocalGameService.instance.getNames(), isEmpty);
    await choose(tester, 'Classmate A');
    final saved = await LocalGameService.instance.loadRoundProgress();
    expect(saved?.draft?['schoolVoting'], isTrue);
    expect(saved?.draftAnswers?.single.optionId, 'friend');
  });

  testWidgets('preference-aware contacts never reinsert excluded local names', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'contact_labels_by_hash_v1': '{"matched-hash":"Маша"}',
    });
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer(
      (_) async => server.QuizSession(
        sessionId: 'filtered',
        ownerId: 'me',
        totalQuestions: 12,
        supportsRoundSubmission: true,
        serverCandidatesOnly: true,
        questions: [
          for (var i = 0; i < 12; i++)
            server.QuizQuestion(
              id: 'filtered-$i',
              text: 'Filtered question $i',
              category: 'normal',
              candidates: const [
                server.QuizCandidate(
                  id: 'matched',
                  firstName: 'Registered name',
                  lastName: '',
                  grade: 8,
                  contactHash: 'matched-hash',
                ),
              ],
            ),
        ],
      ),
    );
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await tester.pumpWidget(
      MaterialApp(home: VoteScreen(serverSource: source)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Filtered question 0'), findsOneWidget);
    expect(find.text('Маша'), findsOneWidget);
    for (final name in ['Али', 'Даня', 'Саша', 'Registered name']) {
      expect(find.text(name), findsNothing);
    }
    await choose(tester, 'Маша');
    final progress = await LocalGameService.instance.loadRoundProgress();
    expect(progress?.draftAnswers?.single.optionId, 'matched');
  });

  testWidgets(
    'online Shuffle uses only candidates authorized for the current question',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['Excluded A', 'Excluded B', 'Excluded C', 'Excluded D'],
      );
      final quiz = MockQuizService();
      when(() => quiz.getQuizzes()).thenAnswer(
        (_) async => server.QuizSession(
          sessionId: 'per-question',
          ownerId: 'me',
          totalQuestions: 12,
          supportsRoundSubmission: true,
          serverCandidatesOnly: true,
          questions: [
            for (var i = 0; i < 12; i++)
              server.QuizQuestion(
                id: 'p$i',
                text: 'Question $i',
                category: 'normal',
                candidates: [
                  const server.QuizCandidate(
                    id: 'me',
                    firstName: 'Self',
                    lastName: '',
                    grade: 8,
                    isSelf: true,
                  ),
                  for (var j = 0; j < (i == 0 ? 6 : 4); j++)
                    server.QuizCandidate(
                      id: 'q$i-user$j',
                      firstName: 'Q$i person $j',
                      lastName: '',
                      grade: 8,
                    ),
                ],
              ),
          ],
        ),
      );
      final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
      await tester.pumpWidget(
        MaterialApp(home: VoteScreen(serverSource: source)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Q0 person 4'), findsNothing);
      await choose(tester, 'Shuffle (2)');
      expect(find.text('Q0 person 4'), findsOneWidget);
      expect(find.text('Q0 person 5'), findsOneWidget);
      expect(find.text('Self'), findsNothing);
      expect(find.text('Excluded A'), findsNothing);
      await choose(tester, 'Q0 person 4');
      expect(find.text('Q0 person 4'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.text('Q1 person $i'), findsOneWidget);
      }
      final saved = await LocalGameService.instance.loadRoundProgress();
      expect(saved!.draftAnswers!.single.optionId, 'q0-user4');
      expect(saved.draft!['shuffleUses'], 1);
      await choose(tester, 'Shuffle (1)');
      expect(
        find.text('No other eligible people for this question.'),
        findsOneWidget,
      );
      expect(find.text('Shuffle (1)'), findsOneWidget);
      final unchanged = await LocalGameService.instance.loadRoundProgress();
      expect(unchanged!.draft!['shuffleUses'], 1);
      final first =
          ((saved.draft!['questions'] as List).first as Map)['options'] as List;
      expect(first.map((o) => (o as Map)['winnerId']), isNot(contains('me')));
      expect(
        first.map((o) => (o as Map)['winnerId']),
        isNot(contains('q1-user0')),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rejected school choices offer a confirmed refresh, never an automatic discard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['One', 'Two', 'Three', 'Four'],
      );
      final quiz = MockQuizService();
      final base = _serverSession();
      var loads = 0;
      when(() => quiz.getQuizzes()).thenAnswer((_) async {
        loads++;
        return server.QuizSession(
          sessionId: base.sessionId,
          ownerId: 'owner',
          schoolVoting: true,
          serverCandidatesOnly: true,
          totalQuestions: 12,
          supportsRoundSubmission: true,
          questions: base.questions,
        );
      });
      when(
        () => quiz.submitRound(
          sessionId: 'srv1',
          answers: any(named: 'answers'),
          choices: any(named: 'choices'),
        ),
      ).thenThrow(
        const ApiException(
          'Some shown participants are no longer eligible. Reload this round.',
          statusCode: 422,
        ),
      );
      final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
      await tester.pumpWidget(
        MaterialApp(home: VoteScreen(serverSource: source)),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await choose(tester, 'Маша');
      }
      await choose(tester, 'Submit votes');
      expect(find.text('Refresh participants'), findsOneWidget);
      expect(find.text('Review your answers'), findsOneWidget);
      expect(loads, 1);
      await choose(tester, 'Refresh participants');
      await choose(tester, 'Cancel');
      expect(loads, 1);
      await choose(tester, 'Refresh participants');
      await choose(tester, 'Refresh round');
      expect(loads, 2);
      expect(find.text('Question 1 of 12'), findsOneWidget);
      final draft = await LocalGameService.instance.loadRoundProgress();
      expect(draft!.draftAnswers, isEmpty);
      expect(draft.draft!['sessionId'], 'srv1');
    },
  );

  testWidgets('online draft edits, resumes and retries the exact final batch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'contact_labels_by_hash_v1': '{"local-sasha-hash":"Саша"}',
    });
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer((_) async => _serverSession());
    final submissions = <Map<String, String?>>[];
    final firstReply = Completer<void>();
    when(
      () => quiz.submitRound(
        sessionId: 'srv1',
        answers: any(named: 'answers'),
      ),
    ).thenAnswer((invocation) async {
      submissions.add(
        Map.of(invocation.namedArguments[#answers] as Map<String, String?>),
      );
      if (submissions.length == 1) await firstReply.future;
    });
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);

    Future<void> open() async {
      final router = GoRouter(
        initialLocation: '/vote',
        routes: [
          GoRoute(
            path: '/vote',
            builder: (_, _) => VoteScreen(serverSource: source),
          ),
          GoRoute(
            path: '/star-received',
            builder: (_, _) => const Text('Result'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    Future<void> reopen() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await open();
    }

    await open();

    expect(find.text('Server question 0'), findsOneWidget);
    expect(find.text('Stranger'), findsNothing);
    expect(find.text('Аман'), findsNothing);
    for (final name in ['Али', 'Маша', 'Даня', 'Саша']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byTooltip('Previous question'), findsNothing);
    await choose(tester, 'Али');
    expect(find.text('Question 2 of 12'), findsOneWidget);
    await choose(tester, 'Skip (2)');
    await tester.tap(find.byTooltip('Previous question'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 12'), findsOneWidget);
    await choose(tester, 'Next');
    expect(find.text('Question 3 of 12'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous question'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous question'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 12'), findsOneWidget);
    await reopen();
    expect(find.text('Question 1 of 12'), findsOneWidget);
    // A previously saved non-skip remains selectable and can be replaced.
    expect(find.text('Next'), findsOneWidget);
    await choose(tester, 'Маша');
    await choose(tester, 'Даня'); // replaces a previously skipped answer
    for (var i = 2; i < 12; i++) {
      await choose(tester, i == 2 ? 'Skip (1)' : 'Али');
    }
    expect(find.text('Review your answers'), findsOneWidget);
    expect(find.text('11 answered · 1 skipped'), findsOneWidget);
    expect(submissions, isEmpty);
    verifyNever(
      () => quiz.submitVote(
        quizId: any(named: 'quizId'),
        winnerId: any(named: 'winnerId'),
      ),
    );
    await reopen();
    await choose(tester, '1. Server question 0');
    expect(find.text('Back to review'), findsOneWidget);
    await choose(tester, 'Саша');
    expect(find.text('Review your answers'), findsOneWidget);
    await tester.tap(find.text('Submit answers'));
    await tester.tap(find.text('Submit answers'));
    await tester.pumpAndSettle();
    expect(submissions, hasLength(1));
    expect(submissions.single, {
      'sq0': 'user_Саша',
      'sq1': 'user_Даня',
      'sq2': null,
      for (var i = 3; i < 12; i++) 'sq$i': 'user_Али',
    });
    firstReply.completeError(const ApiException('Connection lost.'));
    await tester.pumpAndSettle();
    expect(find.text('Connection lost.'), findsOneWidget);
    expect(await LocalGameService.instance.getCompletedRounds(), 0);
    await reopen();
    await choose(tester, 'Retry submission');
    expect(submissions, hasLength(2));
    expect(submissions.last, submissions.first);
    expect(find.text('Result'), findsOneWidget);
    expect(await LocalGameService.instance.getCompletedRounds(), 1);
    expect(
      await LocalGameService.instance.getStars(),
      0,
      reason: "Online rewards never increase the guest balance",
    );
    verify(() => quiz.getQuizzes()).called(1);
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
      Map<String, String?>? submitted;
      when(
        () => quiz.submitRound(
          sessionId: 'srv1',
          answers: any(named: 'answers'),
        ),
      ).thenAnswer((invocation) async {
        submitted = invocation.namedArguments[#answers] as Map<String, String?>;
        throw const ApiException(
          'Test stops after checking the submitted batch.',
        );
      });
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
      expect(find.text('Question 2 of 12'), findsOneWidget);
      for (var i = 1; i < 12; i++) {
        await choose(tester, i <= 2 ? 'Skip (${3 - i})' : visible.first);
      }
      expect(find.text('10 answered · 2 skipped'), findsOneWidget);
      await choose(tester, 'Submit answers');
      expect(submitted, {for (var i = 0; i < 12; i++) 'sq$i': null});
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

  test('vote draft round-trips tier fields and tolerates legacy drafts', () {
    const question = QuizQuestion(
      id: 'q',
      question: 'Who?',
      emoji: '',
      category: 'normal',
      options: [
        QuizOption(
          id: 'a',
          name: 'Aibek',
          grade: '',
          serverUserId: 'a',
          graduationYear: 2026,
          isFriend: true,
        ),
        QuizOption(id: 'b', name: 'Senior', grade: ''),
      ],
    );
    final restored = QuizQuestion.fromDraft(question.toDraft());
    expect(restored.options[0].graduationYear, 2026);
    expect(restored.options[0].isFriend, isTrue);
    expect(restored.options[1].graduationYear, isNull);
    expect(restored.options[1].isFriend, isFalse);
    final legacy = QuizQuestion.fromDraft({
      'id': 'q',
      'text': 'Who?',
      'emoji': '',
      'category': 'normal',
      'options': [
        {'id': 'a', 'name': 'A', 'winnerId': 'a'},
      ],
    });
    expect(legacy.options.single.graduationYear, isNull);
    expect(legacy.options.single.isFriend, isFalse);
  });

  testWidgets('school round keeps server tier order and shows tier subtitles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = SessionStorage();
    await storage.init();
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: request,
              data: request.path == '/api/quizzes/mode'
                  ? {
                      'mode': 'school',
                      'enrolled': true,
                      'joined': 5,
                      'threshold': 5,
                    }
                  : {},
            ),
          );
        },
      ),
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer(
      (_) async => server.QuizSession(
        sessionId: 'tier-round',
        totalQuestions: 12,
        ownerId: 'me',
        supportsRoundSubmission: true,
        schoolVoting: true,
        questions: [
          for (var i = 0; i < 12; i++)
            server.QuizQuestion(
              id: 'tier-$i',
              text: 'Tier question $i',
              category: 'normal',
              candidates: const [
                server.QuizCandidate(
                  id: 'friend',
                  firstName: 'Aibek',
                  lastName: '',
                  grade: 8,
                  graduationYear: 2026,
                  isFriend: true,
                ),
                server.QuizCandidate(
                  id: 'same',
                  firstName: 'Yearmate',
                  lastName: '',
                  grade: 8,
                  graduationYear: 2026,
                ),
                server.QuizCandidate(
                  id: 'other',
                  firstName: 'Senior',
                  lastName: '',
                  grade: 8,
                  graduationYear: 2024,
                ),
              ],
            ),
        ],
      ),
    );
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        apiServiceProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onboardingDetailsProvider).draft({
      'stage': 'done',
      'status': 'selected',
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: VoteScreen(serverSource: source)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tier question 0'), findsOneWidget);
    expect(find.text('Friend · Graduating in 2026'), findsOneWidget);
    expect(find.text('Graduating in 2026'), findsOneWidget);
    expect(find.text('Graduating in 2024'), findsOneWidget);
    await choose(tester, 'Aibek');
    final saved = await LocalGameService.instance.loadRoundProgress();
    final options = (saved?.draft?['questions'] as List)[0]['options'] as List;
    expect(options.map((option) => option['id']).toList(), [
      'friend',
      'same',
      'other',
    ]);
    expect(options[0]['graduationYear'], 2026);
    expect(options[0]['isFriend'], isTrue);
    expect(options[2]['isFriend'], isFalse);
  });

  testWidgets('fallback round explains itself and keeps the flag in the draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'contact_labels_by_hash_v1': '{"matched-hash":"Маша"}',
    });
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша'],
    );
    final quiz = MockQuizService();
    when(() => quiz.getQuizzes()).thenAnswer(
      (_) async => server.QuizSession(
        sessionId: 'fallback1',
        ownerId: 'me',
        totalQuestions: 12,
        supportsRoundSubmission: true,
        preferenceFallback: true,
        questions: [
          for (var i = 0; i < 12; i++)
            server.QuizQuestion(
              id: 'fallback-$i',
              text: 'Fallback question $i',
              category: 'normal',
              candidates: const [
                server.QuizCandidate(
                  id: 'matched',
                  firstName: 'Registered name',
                  lastName: '',
                  grade: 8,
                  contactHash: 'matched-hash',
                ),
              ],
            ),
        ],
      ),
    );
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await tester.pumpWidget(
      MaterialApp(home: VoteScreen(serverSource: source)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fallback question 0'), findsOneWidget);
    expect(
      find.text(
        'Nobody matches your filters. Playing with your test names this round.',
      ),
      findsOneWidget,
    );
    expect(find.text('Change filters'), findsOneWidget);
    for (final name in ['Али', 'Маша', 'Даня', 'Саша']) {
      expect(find.text(name), findsOneWidget);
    }
    await choose(tester, 'Маша');
    final saved = await LocalGameService.instance.loadRoundProgress();
    expect(saved?.draft?['preferenceFallback'], isTrue);
  });
}
