/// app_providers.dart
///
/// Central re-export file that collects every public Riverpod provider used
/// across the Hidavo app into a single import.  Screens and widgets that need
/// more than one provider can import this file instead of multiple individual
/// provider files.
///
/// Additionally this file contains a few cross-cutting providers that do not
/// belong to any single feature slice:
///   • [fcmTokenProvider]       — current Firebase Cloud Messaging token
///   • [appLocaleProvider]      — user-chosen locale override
///   • [connectivityProvider]   — basic online/offline flag
// ignore_for_file: depend_on_referenced_packages

library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

export 'poll_provider.dart'
    show
        PollSessionState,
        PollNotifier,
        TimerState,
        TimerNotifier,
        pollNotifierProvider,
        timerNotifierProvider,
        currentQuestionProvider;

export 'service_providers.dart'
    show
        storageServiceProvider,
        apiServiceProvider,
        authServiceProvider,
        userServiceProvider,
        pollServiceProvider;

// ── Firebase Cloud Messaging token ──────────────────────────────────────────

/// Provides the current FCM registration token as a [String?].
/// Returns null while the token is being fetched or when Firebase is
/// unavailable.  Automatically refreshes whenever the token rotates.
final fcmTokenProvider = StateProvider<String?>((ref) => null);

/// Initialises FCM token fetching and refresh.  Call
/// `ref.read(fcmTokenInitProvider)` once (e.g. from main or a startup
/// provider) to wire everything up.
final fcmTokenInitProvider = Provider<void>((ref) {
  Future<void> fetchAndStore() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      ref.read(fcmTokenProvider.notifier).state = token;
    } catch (_) {
      // Not fatal — the app works without push.
    }
  }

  fetchAndStore();

  // Keep the token fresh when Firebase rotates it.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    ref.read(fcmTokenProvider.notifier).state = newToken;
  });
});

// ── Locale override ──────────────────────────────────────────────────────────

/// Stores the user-selected [Locale].  When null the app uses the system locale
/// resolved in [HidavoApp.localeResolutionCallback].
final appLocaleProvider = StateProvider<Locale?>((ref) => null);

// ── Timer provider (standalone countdown) ────────────────────────────────────
//
// The full timer notifier lives in poll_provider.dart (TimerNotifier /
// timerNotifierProvider).  The alias below gives screens a short import path.

/// Shorthand alias — already exported via poll_provider.dart above.
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
