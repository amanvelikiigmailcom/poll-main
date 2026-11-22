import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../services/subscription_service.dart';

/// Signed-in accounts require explicit server confirmation before local erasure.
/// On failure the credential is retained so deletion can be retried.
Future<void> _wipeServerData(WidgetRef ref) async {
  final storage = ref.read(storageServiceProvider);
  final token = await storage.getToken();
  if (token != null && token.isNotEmpty) {
    final response = await ref
        .read(apiServiceProvider)
        .delete<Map<String, dynamic>>(
          '/api/users/me',
          options: Options(receiveTimeout: const Duration(minutes: 3)),
        )
        .timeout(const Duration(minutes: 3));
    if (response.data?['deleted'] != true) {
      throw StateError('Account deletion was not confirmed');
    }
  }
  try {
    await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Firebase may be unavailable in guest/offline builds; backend erasure was
    // already confirmed for signed-in users. Clear our own persisted data.
  }
  await storage.clearPhone();
  await storage.clearToken();
  await ref.read(contactSyncServiceProvider).clearMatches();
}

/// One confirmation shared by every entry point to local game deletion.
/// Callers may override the wording (e.g. the Delete account screen).
Future<void> showResetGameDialog(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Reset game?',
  String confirmLabel = 'Reset game',
  String intro =
      'Your game profile, participants, university, saved answers, stars, question history '
      'and timer will be deleted. If signed in, your Flyprox account and its server data will also be deleted. '
      'This cannot be undone. Your Apple subscription is managed separately.',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(intro),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  final waiting = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Deleting…'),
          ],
        ),
      ),
    ),
  );
  unawaited(navigator.push(waiting));
  var localCleanupStarted = false;
  try {
    await _wipeServerData(ref);
    localCleanupStarted = true;
    await LocalGameService.instance.clearAll();
    await SubscriptionService.instance.resetUser();
    await ref.read(storageServiceProvider).clearUser();
    if (!context.mounted) return;
    ref.read(userNotifierProvider.notifier).clearUser();
    ref.read(localProfileProvider.notifier).clear();
    if (waiting.isActive) navigator.removeRoute(waiting);
    context.go(AppRoutes.phone);
  } catch (_) {
    if (waiting.isActive) navigator.removeRoute(waiting);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localCleanupStarted
              ? 'Couldn’t finish clearing local data. Please try again.'
              : 'Couldn’t complete account deletion. Your local progress was kept. Try again or contact support.',
        ),
      ),
    );
  }
}
