import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

/// One confirmation shared by every entry point to local game deletion.
Future<void> showResetGameDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Reset game?'),
      content: const Text(
        'Your nickname, participant names, university, stars, question history '
        'and current timer will be deleted from this device. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Reset game'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await LocalGameService.instance.clearAll();
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
