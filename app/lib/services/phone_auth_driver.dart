/// Result of [PhoneAuthDriver.sendCode]: either a verification id (the user
/// must type the SMS code) or an instantly issued Firebase ID token
/// (automatic verification).
class CodeSent {
  final String? verificationId;
  final String? autoIdToken;

  const CodeSent({this.verificationId, this.autoIdToken});
}

class PhoneAuthException implements Exception {
  final String message;

  const PhoneAuthException(this.message);

  @override
  String toString() => 'PhoneAuthException: $message';
}

/// Phone-number verification behind a seam tests can fake.
abstract class PhoneAuthDriver {
  /// Whether phone login can run in this build (Firebase configured).
  bool get isAvailable;

  /// Sends an SMS code to [phoneNumber] (E.164).
  Future<CodeSent> sendCode(String phoneNumber);

  /// Confirms [smsCode] for [verificationId]; returns a Firebase ID token.
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  });
}
