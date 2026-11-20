import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/reset_game_action.dart';

/// Kept for older internal routes; this local game has no server account.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Delete game data')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Delete your local game profile and progress. You will be asked '
                'to confirm before any game data is removed.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => showResetGameDialog(
                  context,
                  ref,
                  title: 'Delete account?',
                  confirmLabel: 'Delete account',
                  intro: 'Are you sure you are ready to delete? Your nickname, participant names, university, photo, saved answers, stars, question history '
                      'and current timer will be deleted from this device. This cannot be undone.',
                ),
                child: const Text('Delete account'),
              ),
            ],
          ),
        ),
      );
}
