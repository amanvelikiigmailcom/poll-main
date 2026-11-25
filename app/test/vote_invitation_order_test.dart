import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/quiz_service.dart' as server;
import 'package:flyprox_app/services/server_round_source.dart';
import 'package:flyprox_app/services/invitation_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/providers/service_providers.dart';

class MockQuiz extends Mock implements server.QuizService {}

class MockInvites extends Mock implements InvitationService {}

void main() {
  testWidgets('quiz loading waits for invitation redemption', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Me',
      friends: ['One', 'Two', 'Three', 'Four'],
    );
    final quiz = MockQuiz();
    final invites = MockInvites();
    final redemption = Completer<void>();
    final calls = <String>[];
    when(() => invites.refresh()).thenAnswer((_) async {
      calls.add('refresh');
      await redemption.future;
      calls.add('redeemed');
    });
    when(() => quiz.getQuizzes()).thenAnswer((_) async {
      calls.add('quiz');
      if (!redemption.isCompleted) {
        throw const ApiException('Next round in 3500 seconds', statusCode: 409);
      }
      return const server.QuizSession(
        sessionId: 'next',
        totalQuestions: 12,
        questions: [],
      );
    });
    final source = ServerRoundSource(quiz, isLoggedIn: () async => true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invitationServiceProvider.overrideWith((ref) => invites)],
        child: MaterialApp(home: VoteScreen(serverSource: source)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, ['refresh']);
    redemption.complete();
    await tester.pumpAndSettle();
    expect(
      calls.indexOf('redeemed'),
      lessThan(calls.indexOf('quiz')),
      reason:
          'A quiz request before the invitation redemption gets cooldown 409. Calls: $calls',
    );
    expect(find.text('Next round in 3500 seconds'), findsNothing);
  });
}
