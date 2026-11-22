import 'dart:async';

import 'quiz_service.dart';

/// Server branch of the quiz: online + logged in → questions and votes go
/// through the backend (`/api/quizzes/current`, `POST /api/votes`), which also
/// fires push notifications for server votes. Offline, logged out, expired
/// session or a server break all resolve to null so callers fall back to the
/// local game. Nothing here ever throws.
class ServerRoundSource {
  final QuizService _quiz;
  final Future<bool> Function() _isLoggedIn;

  ServerRoundSource(this._quiz, {required this._isLoggedIn});

  /// Loads the current server session, or null when the local game applies.
  Future<QuizSession?> tryLoadSession() async {
    try {
      if (!await _loginSettled()) return null;
      return await _quiz.getQuizzes();
    } catch (_) {
      return null;
    }
  }

  /// The token lives in secure storage; never let a slow keychain hang the
  /// vote screen. Settles false on login errors and after 3s without an
  /// answer; the timer is always cancelled so no test is held up.
  Future<bool> _loginSettled() {
    final result = Completer<bool>();
    Timer? fallback;
    void settle(bool value) {
      if (result.isCompleted) return;
      fallback?.cancel();
      result.complete(value);
    }

    fallback = Timer(const Duration(seconds: 3), () => settle(false));
    try {
      _isLoggedIn().then(settle, onError: (_) => settle(false));
    } catch (_) {
      settle(false);
    }
    return result.future;
  }

  /// Submits one server vote; failures stay silent (the local record keeps UX).
  Future<void> trySubmitVote({
    required String quizId,
    required String? winnerId,
  }) async {
    try {
      await _quiz.submitVote(quizId: quizId, winnerId: winnerId);
    } catch (_) {
      // Offline or already voted: the local answer is the source of truth.
    }
  }
}
