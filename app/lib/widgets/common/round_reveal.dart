import 'package:flutter/material.dart';
import '../../services/local_game_service.dart';
import '../../services/game_settings.dart';

Future<void> showRoundReveal(BuildContext context) async {
  final answers =
      await LocalGameService.instance.getRoundAnswers(completed: true);
  if (!context.mounted) return;
  GameSettings.instance.feedback();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
          child: Row(children: [
            Expanded(
                child: Text('Your round revealed',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
        ),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
                'Your choices on this device. These are not votes from other people.')),
        const SizedBox(height: 12),
        Expanded(
            child: answers.isEmpty
                ? const Center(child: Text('No saved answers for this round.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: answers.length,
                    separatorBuilder: (_, __) => const Divider(height: 28),
                    itemBuilder: (context, index) {
                      final answer = answers[index];
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${index + 1}. ${answer.question}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                                answer.choice == null
                                    ? 'Skipped'
                                    : 'You → ${answer.choice}',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]);
                    },
                  )),
      ]),
    ),
  );
}
