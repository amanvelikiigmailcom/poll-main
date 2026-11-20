import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'theme/navigation_icons.dart';
import 'services/game_settings.dart';
import 'providers/service_providers.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
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
    debugPrint('Superwall key missing: billing disabled. '
        'See lib/config/superwall_keys.example.dart');
  }
  // Attach entitlement tracking early; never blocks launch.
  unawaited(SubscriptionService.instance.initialize());

  // ── Run ───────────────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const FlyproxApp(),
    ),
  );
}
