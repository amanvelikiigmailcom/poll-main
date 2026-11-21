import 'package:flyprox_app/services/phone_auth_driver.dart';

/// Scripted phone verification: canned code/confirm results or errors.
class FakePhoneAuthDriver implements PhoneAuthDriver {
  FakePhoneAuthDriver({
    this.available = true,
    this.codeResult = const CodeSent(verificationId: 'vid-1'),
    this.confirmToken = 'id-token-1',
  });

  bool available;
  CodeSent? codeResult;
  Object? sendError;
  Future<CodeSent> Function(String)? sendHandler;
  String? confirmToken;
  Object? confirmError;

  String? lastPhone;
  String? lastVerificationId;
  String? lastSmsCode;
  int sendCalls = 0;
  int confirmCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<CodeSent> sendCode(String phoneNumber) async {
    sendCalls++;
    lastPhone = phoneNumber;
    if (sendError != null) throw sendError!;
    if (sendHandler != null) return sendHandler!(phoneNumber);
    return codeResult ?? const CodeSent(verificationId: 'vid-1');
  }

  @override
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    confirmCalls++;
    lastVerificationId = verificationId;
    lastSmsCode = smsCode;
    if (confirmError != null) throw confirmError!;
    return confirmToken ?? 'id-token-1';
  }
}
