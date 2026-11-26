import 'package:dio/dio.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_game_service.dart';

/// A single quiz question with its candidate options.
class QuizQuestion {
  final String id;
  final String text;
  final String emoji;
  final String category; // humor | normal | sympathy
  final List<QuizCandidate> candidates;

  const QuizQuestion({
    required this.id,
    required this.text,
    this.emoji = '',
    required this.category,
    required this.candidates,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      text: json['text'] as String,
      emoji: json['emoji'] as String? ?? '',
      category: json['category'] as String? ?? 'normal',
      candidates: (json['candidates'] as List<dynamic>? ?? [])
          .map((e) => QuizCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizCandidate {
  final String id;
  final String firstName;
  final String lastName;
  final String? contactHash;
  final String? avatarUrl;
  final int grade;
  final String? gradeClass;
  final bool isSelf;
  final int? graduationYear;
  final bool isFriend;

  const QuizCandidate({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.contactHash,
    this.avatarUrl,
    required this.grade,
    this.gradeClass,
    this.isSelf = false,
    this.graduationYear,
    this.isFriend = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory QuizCandidate.fromJson(Map<String, dynamic> json) {
    final year = json['graduationYear'];
    return QuizCandidate(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      contactHash: json['contactHash'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
      gradeClass: json['gradeClass'] as String?,
      isSelf: json['isSelf'] == true,
      graduationYear: year is int ? year : null,
      isFriend: json['isFriend'] == true,
    );
  }
}

/// Full quiz session (up to 12 questions for the current round).
class QuizSession {
  final String sessionId;
  final String? ownerId;
  final List<QuizQuestion> questions;
  final int totalQuestions;
  final int answeredCount;
  final bool supportsRoundSubmission;
  final bool schoolVoting;
  final bool serverCandidatesOnly;
  final bool preferenceFallback;

  const QuizSession({
    required this.sessionId,
    this.ownerId,
    required this.questions,
    required this.totalQuestions,
    this.answeredCount = 0,
    this.supportsRoundSubmission = false,
    this.schoolVoting = false,
    this.serverCandidatesOnly = false,
    this.preferenceFallback = false,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      sessionId: json['sessionId'] as String? ?? '',
      ownerId: json['ownerId'] as String?,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuestions: json['totalQuestions'] as int? ?? 12,
      answeredCount: json['answeredCount'] as int? ?? 0,
      supportsRoundSubmission: json['supportsRoundSubmission'] == true,
      schoolVoting: json['votingMode'] == 'school',
      serverCandidatesOnly: json['serverCandidatesOnly'] == true,
      preferenceFallback: json['preferenceFallback'] == true,
    );
  }
}

/// Timer status returned by the server.
class TimerStatus {
  /// Whether a quiz round is currently active.
  final bool isActive;

  /// Seconds remaining until the next quiz round starts (0 when active).
  final int secondsRemaining;

  /// UTC timestamp when the next round begins (nullable when active).
  final DateTime? nextRoundAt;

  const TimerStatus({
    required this.isActive,
    required this.secondsRemaining,
    this.nextRoundAt,
  });

  factory TimerStatus.fromJson(Map<String, dynamic> json) {
    return TimerStatus(
      isActive: json['isActive'] as bool? ?? false,
      secondsRemaining: json['secondsRemaining'] as int? ?? 0,
      nextRoundAt: json['nextRoundAt'] != null
          ? DateTime.tryParse(json['nextRoundAt'] as String)
          : null,
    );
  }
}

/// Result of submitting a single vote.
class VoteResult {
  final bool success;
  final int starsAwarded;
  final String? message;

  const VoteResult({
    required this.success,
    this.starsAwarded = 0,
    this.message,
  });

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      success: json['success'] as bool? ?? true,
      starsAwarded: json['starsAwarded'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }
}

class QuizService {
  final ApiService _api;

  QuizService(this._api);

  String _timerKey(String token) =>
      'server_round_deadline_v1_${sha256.convert(utf8.encode(token))}';

  Future<void> rememberTimer(
    Map<String, dynamic> data, {
    String? expectedToken,
  }) async {
    final token = await _api.readSessionToken();
    if (token == null || token.isEmpty) return;
    if (expectedToken != null && expectedToken != token) return;
    final seconds = data['secondsRemaining'];
    if (seconds is! int || seconds < 0) return;
    final deadline =
        DateTime.tryParse(data['nextRoundAt'] as String? ?? '') ??
        DateTime.now().add(Duration(seconds: seconds));
    final prefs = await SharedPreferences.getInstance();
    if (token != await _api.readSessionToken()) return;
    await prefs.setInt(_timerKey(token), deadline.millisecondsSinceEpoch);
  }

  Future<int> secondsUntilNextRound({bool refresh = true}) async {
    final token = await _api.readSessionToken();
    if (token == null || token.isEmpty) {
      return LocalGameService.instance.secondsUntilNextRound();
    }
    if (refresh) {
      try {
        final response = await _api.get<Map<String, dynamic>>(
          '/api/quizzes/timer',
          options: _sessionOptions(token),
        );
        if (token != await _api.readSessionToken()) return 0;
        final data = response.data;
        if (data?['secondsRemaining'] is int) {
          await rememberTimer(data!);
          return (data['secondsRemaining'] as int).clamp(0, 86400);
        }
      } catch (_) {
        /* Keep the confirmed deadline while offline. */
      }
    }
    if (token != await _api.readSessionToken()) return 0;
    final prefs = await SharedPreferences.getInstance();
    final deadline = prefs.getInt(_timerKey(token));
    return deadline == null
        ? LocalGameService.instance.secondsUntilNextRound()
        : ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000)
              .ceil()
              .clamp(0, 86400);
  }

  /// Fetches the current quiz session (12 questions for this round).
  Future<QuizSession> getQuizzes({String? sessionToken}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/quizzes/current',
      queryParameters: {
        'lang': 'en',
        'schoolVoting': '1',
        'quizPreferences': '1',
        'revealPolicyVersion': '1',
        'choicePolicyVersion': '1',
      },
      options: _sessionOptions(sessionToken),
    );
    return QuizSession.fromJson(response.data!);
  }

  Options? _sessionOptions(String? token) => token == null
      ? null
      : Options(headers: {'Authorization': 'Bearer $token'});

  Future<String?> getAccountId(String sessionToken) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/users/profile',
      options: _sessionOptions(sessionToken),
    );
    return response.data?['id'] as String?;
  }

  Future<void> submitRound({
    required String sessionId,
    required Map<String, String?> answers,
    String? sessionToken,
    Map<String, List<String>>? choices,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/quizzes/submit',
      options: _sessionOptions(sessionToken),
      data: {
        'sessionId': sessionId,
        'revealPolicyVersion': 1,
        if (choices != null) 'choicePolicyVersion': 1,
        'answers': [
          for (final answer in answers.entries)
            {
              'quizId': answer.key,
              'winnerId': answer.value,
              if (choices != null)
                'choiceIds': choices[answer.key] ?? <String>[],
            },
        ],
      },
    );
    if (response.data?['success'] != true) {
      throw const ApiException('Could not confirm the round.');
    }
    final reward = response.data?['starsAwarded'];
    _lastReward = (
      sessionId: sessionId,
      token: sessionToken,
      stars: reward is int && (reward == 1000 || reward == 2000)
          ? reward
          : null,
    );
    // Submission is already confirmed. Cache its waiting period before the
    // receipt opens the timer; the next server read replaces this estimate.
    await rememberTimer({
      'secondsRemaining': LocalGameService.roundBreakSeconds,
    }, expectedToken: sessionToken);
  }

  ({String sessionId, String? token, int? stars})? _lastReward;
  int? awardedFor(String sessionId, String? token) =>
      _lastReward?.sessionId == sessionId && _lastReward?.token == token
      ? _lastReward?.stars
      : null;

  /// Submits a vote: the user chose [winnerId] for [quizId].
  Future<VoteResult> submitVote({
    required String quizId,
    required String? winnerId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/votes',
      data: {
        'quizId': quizId,
        if (winnerId != null) 'winnerId': winnerId,
        if (winnerId == null) 'skip': true,
      },
    );
    return VoteResult.fromJson(response.data ?? {});
  }

  /// Returns the current timer / round status.
  Future<TimerStatus> getTimerStatus() async {
    final response = await _api.get<Map<String, dynamic>>('/api/quizzes/timer');
    return TimerStatus.fromJson(response.data!);
  }
}
