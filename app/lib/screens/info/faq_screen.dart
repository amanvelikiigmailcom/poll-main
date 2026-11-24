import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  static const _faqs = [
    (
      'How do I start playing?',
      'Choose a nickname and add at least three participant names, or tap Try with example names. No account or real names are required.',
    ),
    (
      'How does a round work?',
      'Each round contains 12 questions. Pick one of four name cards for each question. Your nickname is included among the cards.',
    ),
    (
      'Can I use fictional names?',
      'Yes. Nicknames and fictional names are welcome. The names are labels on your game cards. They are not connected accounts, and those people are not contacted.',
    ),
    (
      'What do Shuffle and Skip do?',
      'Shuffle changes the order of the same four cards. Skip moves to the next question. Both can be used throughout the round.',
    ),
    (
      'How do I earn stars?',
      'Complete a 12-question round to collect 1,000 stars, or 2,000 for an online round with server-confirmed Premium. Stars have no cash value.',
    ),
    (
      'How does the timer work?',
      'A 60-minute break starts after a round. The center tab shows the same remaining time. You can wait, or earn a wait pass when a new friend registers with your invitation. Premium does not skip the wait.',
    ),
    (
      'What is included in Premium?',
      'Premium Weekly includes 2 full-name voter reveals and 5 first-initial reveals per subscription week, double stars for completed online rounds and a blue membership badge. Eligible new votes only; older votes remain hidden. There is no Max plan.',
    ),
    (
      'When do my reveals reset?',
      'The backend resets the independent limits each subscription week, not on Mondays. Open Premium to see your remaining reveals and reset date. Reopening an already revealed vote is free while your subscription is active. Unused reveals do not roll over.',
    ),
    (
      'How do I choose my university?',
      'Open Profile, then Edit profile and University. Search by name, city or state, choose an institution and save. This field is optional.',
    ),
    (
      'How do I delete my game data?',
      'Open Settings and choose Reset game, then confirm. This removes your local profile, participant names, stars and game progress. The action cannot be undone through Flyprox.',
    ),
    (
      'How can I report a question?',
      'Use Report a question while playing, or contact support from Safety. Please include the question text and leave out participant names or other private information.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Frequently asked questions'),
        backgroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final (question, answer) = _faqs[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              iconColor: _primaryBlue,
              collapsedIconColor: Colors.grey,
              title: Text(
                question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              children: [
                Text(
                  answer,
                  style: const TextStyle(color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
