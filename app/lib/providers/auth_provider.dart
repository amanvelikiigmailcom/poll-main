import 'package:flutter_riverpod/legacy.dart';
import '../services/auth_service.dart';
import '../services/phone_auth_service.dart';
import 'service_providers.dart';

// ── State ────────────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final PhoneAuthService? _phoneAuth;
  int _operation = 0;

  AuthNotifier(this._authService, {PhoneAuthService? phoneAuth})
    : _phoneAuth = phoneAuth,
      super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final operation = _operation;
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted || operation != _operation) return;
    state = state.copyWith(
      status: loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  /// Sends OTP to [phone]. Returns true on success.
  Future<bool> sendOtp(String phone) async {
    final operation = ++_operation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authService.sendOtp(phone);
    if (!mounted || operation != _operation) return false;
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.success ? null : result.message,
    );
    return result.success;
  }

  /// Verifies [code] for [phone]. Updates auth status and returns [OtpVerifyResult].
  Future<OtpVerifyResult> verifyOtp(String phone, String code) async {
    final operation = ++_operation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authService.verifyOtp(phone, code);
    if (!mounted || operation != _operation) {
      return const OtpVerifyResult(
        success: false,
        isNewUser: false,
        message: 'Sign-in was cancelled.',
      );
    }
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
      );
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
    return OtpVerifyResult(
      success: result.success,
      isNewUser: result.isNewUser,
      message: result.message,
    );
  }

  /// Logs out and resets state.
  Future<void> logout() async {
    final operation = ++_operation;
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    if (!mounted || operation != _operation) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  bool get isPhoneLoginAvailable => _phoneAuth?.isAvailable ?? false;

  /// Sends an SMS code via Firebase. Returns the raw result; when the number
  /// verifies instantly ([PhoneCodeResult.autoIdToken]), login completes here.
  Future<PhoneCodeResult> sendFirebaseCode(String phone) async {
    final svc = _phoneAuth;
    if (svc == null || !svc.isAvailable) {
      return const PhoneCodeResult(
        success: false,
        message: 'Phone login isn’t available in this build.',
      );
    }
    final operation = ++_operation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final sent = await svc.sendCode(phone);
    if (!mounted || operation != _operation) {
      return const PhoneCodeResult(
        success: false,
        message: 'Sign-in was cancelled.',
      );
    }
    if (sent.autoIdToken != null) {
      final login = await svc.loginWithIdToken(sent.autoIdToken!, phone: phone);
      if (!mounted || operation != _operation) {
        return const PhoneCodeResult(
          success: false,
          message: 'Sign-in was cancelled.',
        );
      }
      state = state.copyWith(
        isLoading: false,
        status: login.success ? AuthStatus.authenticated : state.status,
        errorMessage: login.success ? null : login.message,
      );
      return PhoneCodeResult(
        success: login.success,
        autoIdToken: sent.autoIdToken,
        message: login.message,
      );
    }
    state = state.copyWith(
      isLoading: false,
      errorMessage: sent.success ? null : sent.message,
    );
    return sent;
  }

  /// Verifies an SMS [code] and signs into the backend. Updates auth status.
  Future<OtpVerifyResult> verifyFirebaseCode({
    required String verificationId,
    required String code,
    String? phone,
  }) async {
    final svc = _phoneAuth;
    if (svc == null || !svc.isAvailable) {
      return const OtpVerifyResult(
        success: false,
        isNewUser: false,
        message: 'Phone login isn’t available in this build.',
      );
    }
    final operation = ++_operation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await svc.verifyCode(
      verificationId: verificationId,
      code: code,
      phone: phone,
    );
    if (!mounted || operation != _operation) {
      return const OtpVerifyResult(
        success: false,
        isNewUser: false,
        message: 'Sign-in was cancelled.',
      );
    }
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
      );
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
    return OtpVerifyResult(
      success: result.success,
      isNewUser: result.isNewUser,
      message: result.message,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Thin result object returned to UI after OTP verification.
class OtpVerifyResult {
  final bool success;
  final bool isNewUser;
  final String? message;

  const OtpVerifyResult({
    required this.success,
    required this.isNewUser,
    this.message,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    phoneAuth: ref.watch(phoneAuthServiceProvider),
  );
});
