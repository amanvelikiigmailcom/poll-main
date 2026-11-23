import 'widgets/common/age_gated_startup.dart';
import 'services/question_bank_service.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'services/invite_code_store.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'theme/navigation_icons.dart';
import 'services/content_service.dart';
import 'services/local_game_service.dart';
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
  final links = AppLinks();
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
  await LocalGameService.instance.removeLegacyAvatar();
  await GameSettings.instance.load();
  await ContentService.instance.load();
  await QuestionBankService.instance.load();
  await AgeGateService.instance.load();
  try {
    final link = await links.getInitialLink();
    if (link != null &&
        link.scheme == 'https' &&
        link.host == 'api.flyprox.com' &&
        link.pathSegments.length == 2 &&
        link.pathSegments.first == 'i') {
      final code = InviteCodeStore.normalize(link.toString());
      if (InviteCodeStore.pattern.hasMatch(code) &&
          await InviteCodeStore.code() == null) {
        await InviteCodeStore.save(code, 'link');
      }
    }
  } catch (_) {
    /* Invitation links are optional; normal startup stays usable. */
  }
  // Public screen copy only: no token, user ID, Firebase or Superwall.
  unawaited(ContentService.instance.refreshPublic());

  await _initializePhoneAuth();

  // ── Run ───────────────────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: AgeGatedStartup(
        initialize: () async {
          await _initializeEligibleServices();
          unawaited(QuestionBankService.instance.refresh());
        },
        child: const FlyproxApp(),
      ),
    ),
  );
}

Future<void> _initializePhoneAuth() async {
  // ── Firebase (phone login) ──────────────────────────────────────────────
  // Optional at runtime: without GoogleService-Info.plist the app still runs,
  // only phone login reports itself unavailable (guest mode).
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Firebase unavailable, phone login disabled: $e');
    return;
  }

  // Appwrite sends plain APNs messages, without FCM's gcm.message_id.
  // FlutterFire does not forward these to onMessage. Its native iOS delegate
  // still applies these presentation options to both APNs and FCM messages.
  // This configures presentation only; it does not request OS permission.
  try {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Foreground notification presentation unavailable: $e');
  }
}

Future<void> _initializeEligibleServices() async {
  // ── Subscriptions (Superwall) ───────────────────────────────────────────
  // Public SDK key from lib/config/superwall_keys.dart (placeholder in git,
  // real value local-only).
  if (superwallIosApiKey.isNotEmpty) {
    try {
      final configured = Completer<void>();
      Superwall.configure(
        superwallIosApiKey,
        completion: () {
          if (!configured.isCompleted) configured.complete();
        },
      );
      await configured.future.timeout(const Duration(seconds: 15));
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
  await SubscriptionService.instance.initialize().timeout(
    const Duration(seconds: 10),
  );
}
