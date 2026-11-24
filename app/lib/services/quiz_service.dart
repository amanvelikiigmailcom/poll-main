import 'package:dio/dio.dart';
import 'api_service.dart';

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

  const QuizCandidate({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.contactHash,
    this.avatarUrl,
    required this.grade,
    this.gradeClass,
    this.isSelf = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory QuizCandidate.fromJson(Map<String, dynamic> json) {
    return QuizCandidate(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      contactHash: json['contactHash'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
      gradeClass: json['gradeClass'] as String?,
      isSelf: json['isSelf'] == true,
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

  const QuizSession({
    required this.sessionId,
    this.ownerId,
    required this.questions,
    required this.totalQuestions,
    this.answeredCount = 0,
    this.supportsRoundSubmission = false,
    this.schoolVoting = false,
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

  /// Fetches the current quiz session (12 questions for this round).
  Future<QuizSession> getQuizzes({String? sessionToken}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/quizzes/current',
      queryParameters: {'lang': 'en', 'schoolVoting': '1'},
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
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/quizzes/submit',
      options: _sessionOptions(sessionToken),
      data: {
        'sessionId': sessionId,
        'answers': [
          for (final answer in answers.entries)
            {'quizId': answer.key, 'winnerId': answer.value},
        ],
      },
    );
    if (response.data?['success'] != true) {
      throw const ApiException('Could not confirm the round.');
    }
  }

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
