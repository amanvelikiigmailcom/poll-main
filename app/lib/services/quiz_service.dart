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
  final String? avatarUrl;
  final int grade;
  final String? gradeClass;

  const QuizCandidate({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.grade,
    this.gradeClass,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory QuizCandidate.fromJson(Map<String, dynamic> json) {
    return QuizCandidate(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
      gradeClass: json['gradeClass'] as String?,
    );
  }
}

/// Full quiz session (up to 12 questions for the current round).
class QuizSession {
  final String sessionId;
  final List<QuizQuestion> questions;
  final int totalQuestions;
  final int answeredCount;

  const QuizSession({
    required this.sessionId,
    required this.questions,
    required this.totalQuestions,
    this.answeredCount = 0,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      sessionId: json['sessionId'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuestions: json['totalQuestions'] as int? ?? 12,
      answeredCount: json['answeredCount'] as int? ?? 0,
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
  Future<QuizSession> getQuizzes() async {
    final response = await _api.get<Map<String, dynamic>>('/api/quizzes/current');
    return QuizSession.fromJson(response.data!);
  }

  /// Submits a vote: the user chose [winnerId] for [quizId].
  Future<VoteResult> submitVote({
    required String quizId,
    required String winnerId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/votes',
      data: {
        'quizId': quizId,
        'winnerId': winnerId,
      },
    );
    return VoteResult.fromJson(response.data ?? {});
  }

  /// Returns the current timer / round status.
  Future<TimerStatus> getTimerStatus() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/quizzes/timer');
    return TimerStatus.fromJson(response.data!);
  }
}
