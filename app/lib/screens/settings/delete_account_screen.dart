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
                'Reset your local game profile and progress. You will be asked '
                'to confirm before any game data is removed.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => showResetGameDialog(context, ref),
                child: const Text('Reset game'),
              ),
            ],
          ),
        ),
      );
}
