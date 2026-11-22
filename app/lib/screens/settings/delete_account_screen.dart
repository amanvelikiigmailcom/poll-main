import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/reset_game_action.dart';

/// Explicit deletion confirmation for local progress and signed-in accounts.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Delete your game profile and progress, and your Flyprox account if signed in. '
            'You will be asked to confirm before deletion.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => showResetGameDialog(
              context,
              ref,
              title: 'Delete account?',
              confirmLabel: 'Delete account',
              intro:
                  'Are you sure you are ready to delete? Your nickname, participant names, university, saved answers, stars, question history '
                  'and current timer will be deleted. If signed in, your Flyprox account and its server data will also be deleted. This cannot be undone. Your Apple subscription is managed separately.',
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    ),
  );
}
