import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../services/game_settings.dart';
import '../../services/subscription_service.dart';

/// Shows the locally saved round. Premium members see every answer;
/// everyone else sees the first three with an upsell to Premium.
Future<void> showRoundReveal(BuildContext context) async {
  final answers =
      await LocalGameService.instance.getRoundAnswers(completed: true);
  final pro = await SubscriptionService.instance.isPro();
  if (!context.mounted) return;
  GameSettings.instance.feedback();
  final visible = pro ? answers : answers.take(3).toList();
  final locked = answers.length - visible.length;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
          child: Row(children: [
            Expanded(
                child: Text('Your round revealed',
                    style: Theme.of(sheetContext).textTheme.titleLarge)),
            IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(pro
                ? 'Your choices on this device. These are not votes from other people.'
                : 'First 3 of ${answers.length} shown. Go Premium to reveal the whole round.')),
        const SizedBox(height: 12),
        Expanded(
            child: answers.isEmpty
                ? const Center(child: Text('No saved answers for this round.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 28),
                    itemBuilder: (sheetContext, index) {
                      final answer = visible[index];
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
                                    color: Theme.of(sheetContext)
                                        .colorScheme
                                        .primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]);
                    },
                  )),
        if (!pro && locked > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRoutes.premium);
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text('Reveal all $locked more with Premium'),
              ),
            ),
          ),
      ]),
    ),
  );
}
