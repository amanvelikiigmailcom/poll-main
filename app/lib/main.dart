import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/service_providers.dart';
import 'services/storage_service.dart';

// ---------------------------------------------------------------------------
// Firebase background message handler — must be a top-level function so that
// the background isolate can locate it via the @pragma annotation.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase may need re-initialisation in a separate isolate.
  await Firebase.initializeApp();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  // Skipped on web: no firebase_options.dart / web config exists yet, and
  // firebase_messaging's web init hangs indefinitely without one.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Firebase not configured yet — app runs without push notifications
    }
  }

  // ── System UI ─────────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS light-mode status bar
    ),
  );

  // ── Storage ───────────────────────────────────────────────────────────────
  final storageService = StorageService();
  await storageService.init();

  // ── Run ───────────────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const HidavoApp(),
    ),
  );
}
