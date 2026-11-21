import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'phone_auth_driver.dart';

/// Production driver: Firebase phone verification. Firebase only proves the
/// number; the session itself comes from our backend (see PhoneAuthService).
class FirebasePhoneAuthDriver implements PhoneAuthDriver {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  bool get isAvailable {
    try {
      FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CodeSent> sendCode(String phoneNumber) async {
    final completer = Completer<CodeSent>();
    void complete(CodeSent r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          try {
            final userCred = await _auth.signInWithCredential(credential);
            final token = await userCred.user?.getIdToken();
            if (token == null || token.isEmpty) {
              complete(const CodeSent());
            } else {
              complete(CodeSent(autoIdToken: token));
            }
          } catch (e) {
            if (e is PhoneAuthException) {
              if (!completer.isCompleted) completer.completeError(e);
            } else {
              complete(const CodeSent());
            }
          }
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) {
            completer.completeError(PhoneAuthException(_friendly(e)));
          }
        },
        codeSent: (verificationId, _) =>
            complete(CodeSent(verificationId: verificationId)),
        codeAutoRetrievalTimeout: (verificationId) =>
            complete(CodeSent(verificationId: verificationId)),
      );
    } catch (e) {
      if (!completer.isCompleted) {
        throw e is PhoneAuthException
            ? e
            : PhoneAuthException(_friendly(e));
      }
    }
    return completer.future;
  }

  @override
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final userCred = await _auth.signInWithCredential(credential);
      final token = await userCred.user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw const PhoneAuthException('Sign-in failed. Try again.');
      }
      return token;
    } on PhoneAuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthException(_friendly(e));
    } catch (_) {
      throw const PhoneAuthException('Sign-in failed. Try again.');
    }
  }

  static String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That phone number looks invalid.';
        case 'invalid-verification-code':
          return 'Wrong code. Try again.';
        case 'session-expired':
          return 'Code expired. Request a new one.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          final msg = e.message?.trim();
          if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return 'Phone login failed. Try again.';
  }
}
