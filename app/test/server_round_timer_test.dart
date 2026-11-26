import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/server_round_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/quiz_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'fakes/social_storage.dart';

class MockQuiz extends Mock implements QuizService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'server waiting response opens the timer route instead of a generic error',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage()..token = 'session';
      await storage.init();
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) => h.resolve(
            Response(
              requestOptions: r,
              data: r.path == '/api/invites/rewards'
                  ? {
                      'balance': 0,
                      'earned': 0,
                      'used': 0,
                      'rewards': [],
                      'redemptions': [],
                    }
                  : <String, dynamic>{},
            ),
          ),
        ),
      );
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Local reviewer',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      final quiz = MockQuiz();
      when(() => quiz.getQuizzes(sessionToken: 'session')).thenThrow(
        const ApiException(
          'Next round in 3033 seconds',
          statusCode: 409,
          details: {'code': 'round_cooldown', 'secondsRemaining': 3033},
        ),
      );
      final source = ServerRoundSource(
        quiz,
        isLoggedIn: () async => true,
        readToken: () async => 'session',
      );
      final router = GoRouter(
        initialLocation: '/vote',
        routes: [
          GoRoute(
            path: '/vote',
            builder: (_, _) => VoteScreen(serverSource: source),
          ),
          GoRoute(
            path: '/timer',
            builder: (_, _) =>
                const Scaffold(body: Text('Designed timer route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            apiServiceProvider.overrideWithValue(api),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/timer',
        reason: tester.allWidgets
            .whereType<Text>()
            .map((t) => t.data)
            .join('|'),
      );
      expect(find.text('Designed timer route'), findsOneWidget);
      expect(find.text('Next round in 3033 seconds'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    },
  );
  test(
    'server cooldown survives missing local timer and is scoped to the session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage();
      await storage.init();
      final quiz = QuizService(ApiService(storage));
      expect(await LocalGameService.instance.secondsUntilNextRound(), 0);
      await quiz.rememberTimer({'secondsRemaining': 3033});
      expect(
        await quiz.secondsUntilNextRound(refresh: false),
        inInclusiveRange(3032, 3033),
      );
      storage.token = 'other';
      expect(await quiz.secondsUntilNextRound(refresh: false), 0);
    },
  );
  test(
    'a confirmed available response replaces a cached server cooldown',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage();
      await storage.init();
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) => h.resolve(
            Response(
              requestOptions: r,
              data: {'secondsRemaining': 0, 'isActive': true},
            ),
          ),
        ),
      );
      final quiz = QuizService(api);
      await quiz.rememberTimer({'secondsRemaining': 3033});
      expect(await quiz.secondsUntilNextRound(), 0);
      expect(await quiz.secondsUntilNextRound(refresh: false), 0);
    },
  );
  test(
    'switching accounts restores only its own names, username and draft fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      final game = LocalGameService.instance;
      await game.activateAccount('aman');
      await game.savePlayerAndFriends(
        playerName: 'Aman',
        friends: ['One', 'Two', 'Three', 'Four'],
      );
      await game.saveUsername('aman_original');
      await game.completeRound();
      await game.activateAccount('reviewer');
      expect(await game.getNames(), isEmpty);
      expect(await game.getUsername(), isNull);
      expect(await game.secondsUntilNextRound(), 0);
      await game.savePlayerAndFriends(
        playerName: '',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      await game.activateAccount('aman');
      expect(await game.getUsername(), 'aman_original');
      expect(await game.getNames(), ['One', 'Two', 'Three', 'Four']);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
      await game.activateAccount('reviewer');
      expect(await game.getNames(), ['Alex', 'Sam', 'Jordan', 'Taylor']);
    },
  );
}
