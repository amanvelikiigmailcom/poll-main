import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/quiz_service.dart';
import 'service_providers.dart';

// ── Quiz session state ────────────────────────────────────────────────────────

class QuizSessionState {
  final QuizSession? session;
  final int currentQuestionIndex;
  final bool isLoading;
  final String? errorMessage;
  final bool isComplete;

  const QuizSessionState({
    this.session,
    this.currentQuestionIndex = 0,
    this.isLoading = false,
    this.errorMessage,
    this.isComplete = false,
  });

  QuizSessionState copyWith({
    QuizSession? session,
    int? currentQuestionIndex,
    bool? isLoading,
    String? errorMessage,
    bool? isComplete,
    bool clearError = false,
  }) {
    return QuizSessionState(
      session: session ?? this.session,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  QuizQuestion? get currentQuestion {
    final s = session;
    if (s == null || currentQuestionIndex >= s.questions.length) return null;
    return s.questions[currentQuestionIndex];
  }

  int get totalQuestions => session?.totalQuestions ?? 12;
  bool get hasSession => session != null;
}

// ── Quiz notifier ─────────────────────────────────────────────────────────────

class QuizNotifier extends StateNotifier<QuizSessionState> {
  final QuizService _quizService;

  QuizNotifier(this._quizService) : super(const QuizSessionState());

  Future<void> loadQuizzes() async {
    state = state.copyWith(isLoading: true, clearError: true, isComplete: false);
    try {
      final session = await _quizService.getQuizzes();
      state = state.copyWith(
        isLoading: false,
        session: session,
        currentQuestionIndex: session.answeredCount,
        isComplete: session.answeredCount >= session.totalQuestions,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Submits the vote and advances to the next question.
  Future<VoteResult?> submitVote({
    required String quizId,
    required String winnerId,
  }) async {
    try {
      final result = await _quizService.submitVote(
        quizId: quizId,
        winnerId: winnerId,
      );
      _advance();
      return result;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  void _advance() {
    final next = state.currentQuestionIndex + 1;
    final total = state.totalQuestions;
    state = state.copyWith(
      currentQuestionIndex: next,
      isComplete: next >= total,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = const QuizSessionState();
  }
}

// ── Timer state ───────────────────────────────────────────────────────────────

class TimerState {
  final bool isActive;
  final int secondsRemaining;
  final DateTime? nextRoundAt;
  final bool isLoading;
  final String? errorMessage;

  const TimerState({
    this.isActive = false,
    this.secondsRemaining = 0,
    this.nextRoundAt,
    this.isLoading = false,
    this.errorMessage,
  });

  TimerState copyWith({
    bool? isActive,
    int? secondsRemaining,
    DateTime? nextRoundAt,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TimerState(
      isActive: isActive ?? this.isActive,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      nextRoundAt: nextRoundAt ?? this.nextRoundAt,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  /// Formatted mm:ss string.
  String get formattedTime {
    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ── Timer notifier ────────────────────────────────────────────────────────────

class TimerNotifier extends StateNotifier<TimerState> {
  final QuizService _quizService;
  Timer? _ticker;

  TimerNotifier(this._quizService) : super(const TimerState());

  Future<void> fetchTimerStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _quizService.getTimerStatus();
      state = state.copyWith(
        isLoading: false,
        isActive: status.isActive,
        secondsRemaining: status.secondsRemaining,
        nextRoundAt: status.nextRoundAt,
      );
      if (!status.isActive && status.secondsRemaining > 0) {
        _startLocalCountdown();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _startLocalCountdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.secondsRemaining - 1;
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(secondsRemaining: 0, isActive: true);
      } else {
        state = state.copyWith(secondsRemaining: remaining);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final quizNotifierProvider =
    StateNotifierProvider<QuizNotifier, QuizSessionState>((ref) {
  return QuizNotifier(ref.watch(quizServiceProvider));
});

final timerNotifierProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref.watch(quizServiceProvider));
});

/// Convenience read-only provider for the current quiz question (may be null).
final currentQuestionProvider = Provider<QuizQuestion?>((ref) {
  return ref.watch(quizNotifierProvider).currentQuestion;
});
