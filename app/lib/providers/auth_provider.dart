import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
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

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await _authService.isLoggedIn();
    state = state.copyWith(
      status: loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  /// Sends OTP to [phone]. Returns true on success.
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authService.sendOtp(phone);
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.success ? null : result.message,
    );
    return result.success;
  }

  /// Verifies [code] for [phone]. Updates auth status and returns [OtpVerifyResult].
  Future<OtpVerifyResult> verifyOtp(String phone, String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authService.verifyOtp(phone, code);
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
    return OtpVerifyResult(
      success: result.success,
      isNewUser: result.isNewUser,
      message: result.message,
    );
  }

  /// Logs out and resets state.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
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

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
