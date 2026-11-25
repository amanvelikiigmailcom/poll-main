import 'package:dio/dio.dart';

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
    final generation = _storage.beginAuthentication();
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/auth/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      final data = response.data ?? {};
      final token = data['token'] as String?;
      final isNewUser = data['isNewUser'] as bool? ?? false;

      if (token == null || token.isEmpty) {
        return const AuthResult(
          success: false,
          message: 'Login failed. Try again.',
        );
      }
      if (!await _storage.saveAuthenticatedSession(
        generation,
        token: token,
        phone: phone,
      )) {
        return const AuthResult(
          success: false,
          message: 'Sign-in was cancelled.',
        );
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
    final token = await _storage.clearSession();
    if (token == null || token.isEmpty) return;
    try {
      // Best-effort server-side invalidation; ignore errors.
      await _api.post<void>(
        '/api/auth/logout',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          extra: {'callerHandlesUnauthorized': true},
        ),
      );
    } catch (_) {}
  }

  /// Returns true when a non-empty auth token is stored locally.
  /// Never throws: storage errors (or missing test bindings) mean logged out.
  Future<bool> isLoggedIn() async {
    try {
      final token = await _storage.getToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
