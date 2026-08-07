import 'api_service.dart';
import 'storage_service.dart';

class OtpResult {
  final bool success;
  final String? message;
  /// Some backends return a verification token on send-otp to be echoed back.
  final String? verificationToken;

  const OtpResult({
    required this.success,
    this.message,
    this.verificationToken,
  });
}

class AuthResult {
  final bool success;
  final String? token;
  final String? message;
  /// True when the user exists but has not completed onboarding yet.
  final bool isNewUser;

  const AuthResult({
    required this.success,
    this.token,
    this.message,
    this.isNewUser = false,
  });
}

class AuthService {
  final ApiService _api;
  final StorageService _storage;

  AuthService(this._api, this._storage);

  /// Sends a one-time password to [phone].
  /// [phone] should be in E.164 format, e.g. "+79991234567".
  Future<OtpResult> sendOtp(String phone) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/auth/send-otp',
        data: {'phone': phone},
      );
      final data = response.data ?? {};
      await _storage.savePhone(phone);
      return OtpResult(
        success: true,
        message: data['message'] as String?,
        verificationToken: data['verificationToken'] as String?,
      );
    } on ApiException catch (e) {
      return OtpResult(success: false, message: e.message);
    }
  }

  /// Verifies [code] for [phone]. On success the auth token is persisted.
  Future<AuthResult> verifyOtp(String phone, String code) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/auth/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      final data = response.data ?? {};
      final token = data['token'] as String?;
      final isNewUser = data['isNewUser'] as bool? ?? false;

      if (token != null) {
        await _storage.saveToken(token);
      }

      return AuthResult(
        success: true,
        token: token,
        isNewUser: isNewUser,
        message: data['message'] as String?,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  /// Logs the user out by clearing stored credentials.
  Future<void> logout() async {
    try {
      // Best-effort server-side invalidation; ignore errors.
      await _api.post<void>('/api/auth/logout');
    } catch (_) {}
    await _storage.clearToken();
    await _storage.clearUser();
  }

  /// Returns true when a non-empty auth token is stored locally.
  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }
}
