import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/quiz_service.dart';
import 'fakes/social_storage.dart';

class _QuizApi extends ApiService {
  _QuizApi(super.storage);
  Map<String, dynamic>? capabilities;
  Options? session;
  dynamic submitted;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    expect(path, '/api/quizzes/submit');
    submitted = data;
    session = options;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'starsAwarded': 2000} as T,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    expect(path, '/api/quizzes/current');
    capabilities = queryParameters;
    session = options;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'sessionId': 'round',
                'ownerId': 'owner',
                'questions': [],
                'totalQuestions': 12,
                'supportsRoundSubmission': true,
                'serverCandidatesOnly': true,
                'votingMode': 'school',
              }
              as T,
    );
  }
}

void main() {
  test(
    'batch submission acknowledges the voter notice and uses the confirmed reward',
    () async {
      final api = _QuizApi(SessionStorage());
      final quiz = QuizService(api);
      await quiz.submitRound(
        sessionId: 'round',
        answers: {'q1': 'friend'},
        sessionToken: 'pinned',
      );
      expect(api.submitted, {
        'sessionId': 'round',
        'revealPolicyVersion': 1,
        'answers': [
          {'quizId': 'q1', 'winnerId': 'friend'},
        ],
      });
      expect(api.session?.headers?['Authorization'], 'Bearer pinned');
      expect(quiz.awardedFor('round', 'pinned'), 2000);
      expect(quiz.awardedFor('round', 'another-account'), isNull);
    },
  );
  test(
    'quiz request keeps preferences and Premium capabilities together',
    () async {
      final api = _QuizApi(SessionStorage());
      final session = await QuizService(api).getQuizzes(sessionToken: 'pinned');
      expect(api.capabilities, {
        'lang': 'en',
        'schoolVoting': '1',
        'quizPreferences': '1',
        'revealPolicyVersion': '1',
      });
      expect(api.session?.headers?['Authorization'], 'Bearer pinned');
      expect(session.schoolVoting, isTrue);
      expect(session.serverCandidatesOnly, isTrue);
    },
  );
  test('school candidate cards parse tier fields with legacy defaults', () {
    final session = QuizSession.fromJson({
      'sessionId': 'round',
      'ownerId': 'owner',
      'questions': [
        {
          'id': 'q1',
          'text': 'Who?',
          'category': 'normal',
          'candidates': [
            {
              'id': 'a',
              'firstName': 'Aibek',
              'graduationYear': 2026,
              'isFriend': true,
            },
            {'id': 'b', 'firstName': 'Classmate'},
          ],
        },
      ],
      'totalQuestions': 12,
      'supportsRoundSubmission': true,
      'votingMode': 'school',
    });
    final cards = session.questions.single.candidates;
    expect(cards[0].graduationYear, 2026);
    expect(cards[0].isFriend, isTrue);
    expect(cards[1].graduationYear, isNull);
    expect(cards[1].isFriend, isFalse);
  });
}
