import 'api_service.dart';

/// A single poll question with its candidate options.
class PollQuestion {
  final String id;
  final String text;
  final String category; // humor | normal | sympathy
  final List<PollCandidate> candidates;

  const PollQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.candidates,
  });

  factory PollQuestion.fromJson(Map<String, dynamic> json) {
    return PollQuestion(
      id: json['id'] as String,
      text: json['text'] as String,
      category: json['category'] as String? ?? 'normal',
      candidates: (json['candidates'] as List<dynamic>? ?? [])
          .map((e) => PollCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PollCandidate {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final int grade;
  final String? gradeClass;

  const PollCandidate({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.grade,
    this.gradeClass,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory PollCandidate.fromJson(Map<String, dynamic> json) {
    return PollCandidate(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
      gradeClass: json['gradeClass'] as String?,
    );
  }
}

/// Full poll session (up to 12 questions for the current round).
class PollSession {
  final String sessionId;
  final List<PollQuestion> questions;
  final int totalQuestions;
  final int answeredCount;

  const PollSession({
    required this.sessionId,
    required this.questions,
    required this.totalQuestions,
    this.answeredCount = 0,
  });

  factory PollSession.fromJson(Map<String, dynamic> json) {
    return PollSession(
      sessionId: json['sessionId'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => PollQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuestions: json['totalQuestions'] as int? ?? 12,
      answeredCount: json['answeredCount'] as int? ?? 0,
    );
  }
}

/// Timer status returned by the server.
class TimerStatus {
  /// Whether a poll round is currently active.
  final bool isActive;

  /// Seconds remaining until the next poll round starts (0 when active).
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

class PollService {
  final ApiService _api;

  PollService(this._api);

  /// Fetches the current poll session (12 questions for this round).
  Future<PollSession> getPolls() async {
    final response = await _api.get<Map<String, dynamic>>('/api/polls/current');
    return PollSession.fromJson(response.data!);
  }

  /// Submits a vote: the user chose [winnerId] for [pollId].
  Future<VoteResult> submitVote({
    required String pollId,
    required String winnerId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/votes',
      data: {
        'pollId': pollId,
        'winnerId': winnerId,
      },
    );
    return VoteResult.fromJson(response.data ?? {});
  }

  /// Returns the current timer / round status.
  Future<TimerStatus> getTimerStatus() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/polls/timer');
    return TimerStatus.fromJson(response.data!);
  }
}
