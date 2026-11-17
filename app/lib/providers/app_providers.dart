/// app_providers.dart
///
/// Central re-export file that collects every public Riverpod provider used
/// across the Hidavo app into a single import.  Screens and widgets that need
/// more than one provider can import this file instead of multiple individual
/// provider files.
///
/// Additionally this file contains a few cross-cutting providers that do not
/// belong to any single feature slice:
///   • [appLocaleProvider]      — user-chosen locale override
///   • [connectivityProvider]   — basic online/offline flag
// ignore_for_file: depend_on_referenced_packages

library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart' show authNotifierProvider;

// ── Feature providers (re-exported for convenience) ─────────────────────────
export 'auth_provider.dart'
    show
        AuthStatus,
        AuthState,
        AuthNotifier,
        OtpVerifyResult,
        authNotifierProvider;

export 'user_provider.dart'
    show
        UserState,
        UserNotifier,
        userNotifierProvider,
        currentUserProvider;

export 'quiz_provider.dart'
    show
        QuizSessionState,
        QuizNotifier,
        TimerState,
        TimerNotifier,
        quizNotifierProvider,
        timerNotifierProvider,
        currentQuestionProvider;

export 'service_providers.dart'
    show
        storageServiceProvider,
        apiServiceProvider,
        authServiceProvider,
        userServiceProvider,
        quizServiceProvider;

// ── Locale override ──────────────────────────────────────────────────────────

/// Stores the user-selected [Locale].  When null the app uses the system locale
/// resolved in [HidavoApp.localeResolutionCallback].
final appLocaleProvider = StateProvider<Locale?>((ref) => null);

// ── Timer provider (standalone countdown) ────────────────────────────────────
//
// The full timer notifier lives in quiz_provider.dart (TimerNotifier /
// timerNotifierProvider).  The alias below gives screens a short import path.

/// Shorthand alias — already exported via quiz_provider.dart above.
// (no additional code needed; re-exported as timerNotifierProvider)

// ── Auth state convenience alias ─────────────────────────────────────────────

/// Convenience boolean provider: true when the user is fully authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});

// ── Global loading overlay ────────────────────────────────────────────────────

/// When true, a full-screen loading overlay should be displayed.
/// Individual screens set this via [ref.read(globalLoadingProvider.notifier)].
final globalLoadingProvider = StateProvider<bool>((ref) => false);

// ── Snackbar / toast message bus ─────────────────────────────────────────────

/// Emits a one-shot message string that the root scaffold can display as a
/// SnackBar.  After reading, reset to null.
final globalMessageProvider = StateProvider<String?>((ref) => null);
