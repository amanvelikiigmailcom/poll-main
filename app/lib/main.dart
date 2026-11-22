import 'services/question_bank_service.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'theme/navigation_icons.dart';
import 'services/api_service.dart';
import 'services/content_service.dart';
import 'services/game_settings.dart';
import 'providers/service_providers.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'services/age_gate_service.dart';
import 'config/superwall_keys.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NavigationIcons.registerLicense();

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
  await GameSettings.instance.load();
  await ContentService.instance.load();
  await QuestionBankService.instance.load();
  unawaited(QuestionBankService.instance.refresh());
  // Refresh server texts in the background; defaults cover the first paint.
  unawaited(ContentService.instance.refresh(ApiService(storageService)));

  // ── Firebase (phone login) ──────────────────────────────────────────────
  // Optional at runtime: without GoogleService-Info.plist the app still runs,
  // only phone login reports itself unavailable (guest mode).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase unavailable, phone login disabled: $e');
  }
  // Age-gate status for the /premium route; never blocks launch.
  await AgeGateService.instance.load();

  // ── Subscriptions (Superwall) ───────────────────────────────────────────
  // Public SDK key from lib/config/superwall_keys.dart (placeholder in git,
  // real value local-only).
  if (superwallIosApiKey.isNotEmpty) {
    try {
      Superwall.configure(superwallIosApiKey);
    } catch (e) {
      debugPrint('Superwall configure failed: $e');
    }
  } else {
    debugPrint(
      'Superwall key missing: billing disabled. '
      'See lib/config/superwall_keys.example.dart',
    );
  }
  // Attach entitlement tracking early; never blocks launch.
  unawaited(SubscriptionService.instance.initialize());

  // ── Run ───────────────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const FlyproxApp(),
    ),
  );
}
