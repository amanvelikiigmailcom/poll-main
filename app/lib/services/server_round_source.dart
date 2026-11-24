import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'api_service.dart';
import 'quiz_service.dart';

/// Server branch of the quiz: online + logged in → questions and votes go
/// through the backend. Authenticated production loads never fall back locally;
/// submission of an existing online draft must be explicitly acknowledged.
class ServerRoundSource {
  final QuizService _quiz;
  final Future<bool> Function() _isLoggedIn;
  final Future<String?> Function()? readToken;
  String? _loadedToken;
  int? lastStarsAwarded;

  ServerRoundSource(this._quiz, {required this._isLoggedIn, this.readToken});

  String _key(String token) =>
      sha256.convert(utf8.encode('flyprox-round-draft:$token')).toString();

  String get loadedSessionKey => _key(_loadedToken ?? '');

  Future<String?> _token() async {
    final read = readToken;
    return read == null ? '' : await read().timeout(const Duration(seconds: 3));
  }

  Future<bool> ownsDraft(String key, {String? ownerId}) async {
    try {
      final token = await _token();
      return token != null && await _matchesDraft(token, key, ownerId);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _matchesDraft(String token, String key, String? ownerId) async {
    if (_key(token) == key) return true;
    if (ownerId == null || token.isEmpty) return false;
    // After re-authentication, verify the owner with the API, not cached user data.
    final actual = await _quiz.getAccountId(token);
    return actual == ownerId && await _token() == token;
  }

  /// Loads the current server session, or null when the local game applies.
  Future<QuizSession?> tryLoadSession() async {
    var authenticatedAttempt = false;
    try {
      if (readToken == null && !await _loginSettled()) return null;
      authenticatedAttempt = readToken != null;
      final token = await _token();
      if (token == null || (readToken != null && token.isEmpty)) return null;
      final session = readToken == null
          ? await _quiz.getQuizzes()
          : await _quiz.getQuizzes(sessionToken: token);
      if (await _token() != token) {
        if (authenticatedAttempt) {
          throw const ApiException('Account changed. Please try again.');
        }
        return null;
      }
      _loadedToken = token;
      return session;
    } on ApiException catch (error) {
      // A server daily limit must never become permission for local fallback.
      if (authenticatedAttempt || error.statusCode == 429) rethrow;
      return null;
    } catch (_) {
      if (authenticatedAttempt) {
        throw const ApiException(
          'Couldn’t load your quiz. Check your connection and try again.',
        );
      }
      return null;
    }
  }

  Future<void> submitRound({
    required String sessionId,
    required String sessionKey,
    String? ownerId,
    required Map<String, String?> answers,
  }) async {
    lastStarsAwarded = null;
    final token = await _token();
    if (token == null || !await _matchesDraft(token, sessionKey, ownerId)) {
      throw const ApiException('This draft belongs to another sign-in.');
    }
    await _quiz.submitRound(
      sessionId: sessionId,
      answers: answers,
      sessionToken: readToken == null ? null : token,
    );
    if (await _token() != token) {
      throw const ApiException('Sign-in changed during submission.');
    }
    lastStarsAwarded = _quiz.awardedFor(
      sessionId,
      readToken == null ? null : token,
    );
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
