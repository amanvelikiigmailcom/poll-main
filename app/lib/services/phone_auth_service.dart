import 'api_service.dart';
import 'phone_auth_driver.dart';
import 'storage_service.dart';

class PhoneCodeResult {
  final bool success;
  final String? verificationId;
  final String? autoIdToken;
  final String? message;

  const PhoneCodeResult({
    required this.success,
    this.verificationId,
    this.autoIdToken,
    this.message,
  });
}

class PhoneLoginResult {
  final bool success;
  final bool isNewUser;
  final String? message;

  const PhoneLoginResult({
    required this.success,
    this.isNewUser = false,
    this.message,
  });
}

/// Phone login: Firebase verifies the number, our backend owns the session.
///
/// Flow: [sendCode] → user types the SMS code → [verifyCode] exchanges the
/// Firebase ID token at `POST /api/auth/firebase` for a backend Bearer token,
/// persisted via [StorageService] like the legacy OTP flow. All entry points
/// return result objects instead of throwing.
class PhoneAuthService {
  final PhoneAuthDriver _driver;
  final ApiService _api;
  final StorageService _storage;

  PhoneAuthService({
    required ApiService api,
    required StorageService storage,
    required PhoneAuthDriver driver,
  })  : _api = api,
        _storage = storage,
        _driver = driver;

  bool get isAvailable => _driver.isAvailable;

  Future<PhoneCodeResult> sendCode(String phone) async {
    try {
      final sent = await _driver.sendCode(phone).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw const PhoneAuthException(
            'The code request timed out. Try again or continue without login.'),
      );
      if (sent.verificationId == null && sent.autoIdToken == null) {
        return const PhoneCodeResult(
            success: false, message: 'Couldn’t send the code. Try again.');
      }
      return PhoneCodeResult(
        success: true,
        verificationId: sent.verificationId,
        autoIdToken: sent.autoIdToken,
      );
    } on PhoneAuthException catch (e) {
      return PhoneCodeResult(success: false, message: e.message);
    } catch (_) {
      return const PhoneCodeResult(
          success: false, message: 'Couldn’t send the code. Try again.');
    }
  }

  Future<PhoneLoginResult> verifyCode({
    required String verificationId,
    required String code,
    String? phone,
  }) async {
    try {
      final idToken = await _driver.confirmCode(
          verificationId: verificationId, smsCode: code);
      return loginWithIdToken(idToken, phone: phone);
    } on PhoneAuthException catch (e) {
      return PhoneLoginResult(success: false, message: e.message);
    } catch (_) {
      return const PhoneLoginResult(
          success: false, message: 'Verification failed. Try again.');
    }
  }

  /// Exchanges a Firebase ID token for a backend session. Never throws.
  Future<PhoneLoginResult> loginWithIdToken(String idToken,
      {String? phone}) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/auth/firebase',
        data: {'idToken': idToken},
      );
      final data = response.data ?? {};
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        return PhoneLoginResult(
          success: false,
          message: (data['message'] as String?) ?? 'Login failed. Try again.',
        );
      }
      await _storage.saveToken(token);
      if (phone != null && phone.trim().isNotEmpty) {
        await _storage.savePhone(phone.trim());
      }
      return PhoneLoginResult(
        success: true,
        isNewUser: data['isNewUser'] as bool? ?? false,
      );
    } on ApiException catch (e) {
      return PhoneLoginResult(success: false, message: e.message);
    } catch (_) {
      return const PhoneLoginResult(
          success: false, message: 'Login failed. Try again.');
    }
  }
}
