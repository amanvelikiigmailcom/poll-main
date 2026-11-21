import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../services/subscription_service.dart';

/// Best-effort server erasure for logged-in users. Drops the backend account
/// (profile, hashes, rounds, votes) and the local token plus cached matches.
/// Local wipe proceeds regardless of the outcome.
Future<void> _wipeServerData(WidgetRef ref) async {
  try {
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getToken();
    if (token != null && token.isNotEmpty) {
      final api = ref.read(apiServiceProvider);
      await api
          .delete('/api/users/me')
          .timeout(const Duration(seconds: 5));
    }
  } catch (_) {
    // Best effort: local wipe proceeds regardless.
  } finally {
    try {
      await ref.read(storageServiceProvider).clearToken();
      await ref.read(contactSyncServiceProvider).clearMatches();
    } catch (_) {}
  }
}

/// One confirmation shared by every entry point to local game deletion.
/// Callers may override the wording (e.g. the Delete account screen).
Future<void> showResetGameDialog(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Reset game?',
  String confirmLabel = 'Reset game',
  String intro = 'Your nickname, participant names, university, photo, saved answers, stars, question history '
      'and current timer will be deleted from this device. This cannot be undone.',
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

  try {
    await _wipeServerData(ref);
    await LocalGameService.instance.clearAll();
    await SubscriptionService.instance.resetUser();
    await ref.read(storageServiceProvider).clearUser();
    if (!context.mounted) return;
    ref.read(userNotifierProvider.notifier).clearUser();
    ref.read(localProfileProvider.notifier).clear();
    context.go(AppRoutes.namesEntry);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Couldn’t reset the game. Please try again.')),
    );
  }
}
