import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/support_email_service.dart';
import '../../widgets/common/support_email_dialog.dart';

import '../../services/content_service.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';

class ForParentsScreen extends ConsumerWidget {
  const ForParentsScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('For parents'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              Icons.info_rounded,
              'How the game works',
              'Flyprox is a quiz game with 12-question rounds. Guest players use selected contacts or examples on their device. Eligible signed-in players can take part in online quiz answers with their campus community.',
            ),
            _section(
              Icons.chat_bubble_outline_rounded,
              'No in-app chat',
              'Flyprox has no direct messages or group chats. Players cannot send each other custom messages, photos or videos in the app. Optional invitations open the device’s Messages app only when the player chooses to send one.',
            ),
            _section(
              Icons.favorite_outline_rounded,
              'Respectful play',
              'Our aim is friendly, encouraging play. Players choose from prepared questions rather than sending their own prompts to other people. A question can be skipped or reported if it feels uncomfortable. We do not promise that every prompt will suit every player.',
            ),
            _section(
              Icons.people_outline_rounded,
              'Friends are a choice',
              'Friendship requires an accepted request. People are found by username, not by searching their first name, last name or phone number. Adding a friend does not open a chat. A username is visible to someone who finds the account.',
            ),
            _section(
              Icons.shield_outlined,
              'Block, remove or report',
              'Players can remove a friend, block an account or open an email report from its profile. Email reports must be sent by the player to support@flyprox.com. Blocking prevents new friend requests and online quiz answers between those accounts and hides them from each other in search. Manage blocked accounts in Settings. Blocking does not erase names someone has typed into their own offline game.',
            ),
            _section(
              Icons.timer_outlined,
              'Time for a break',
              'Rounds contain 12 questions, followed by a 60-minute wait. Earned invitation passes can skip a wait. This is a game mechanic, not a parental screen-time control.',
            ),
            _section(
              Icons.lock_rounded,
              'Participant names',
              'Nicknames and fictional names are welcome. Participant labels may be fictional. In optional online play, selected contacts matching registered accounts can receive quiz-result notifications. Merely choosing a contact sends no invitation.',
            ),
            _section(
              Icons.child_care_rounded,
              'Age and responsible play',
              'Flyprox is intended for people aged 13 and over. Use it for entertainment and discuss respectful play. Do not enter sensitive information about anyone or use the game to harass or embarrass another person.',
            ),
            _section(
              Icons.privacy_tip_rounded,
              'Game data and privacy',
              'Guest play needs no account and game progress is stored on the device. Signed-in features also store account data, usernames, friend relationships, blocks, selected-contact hashes and online quiz answers on our server. Selected contacts’ raw phone numbers are not uploaded; the account’s own phone number is used for sign-in. Optional phone sign-in is offered before the age question. Underage answers block contacts, gameplay and subscription access for the current run. Read the Privacy Policy for details.',
            ),
            _section(
              Icons.supervisor_account_rounded,
              'Deleting an account',
              'Players can request account deletion at any time in Settings → Delete account. Confirmation is required. Signed-in deletion removes the Flyprox account and associated server data; a connection is needed and errors can be retried. Reset game is separate and clears local game progress. Apple subscriptions are managed separately. Parents and guardians can contact support for help; account-related requests may require verification.',
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.privacy),
              child: const Text('Read the Privacy Policy'),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mail_rounded, color: _primaryBlue, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Parent and guardian support',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ContentService.instance.text('support_email'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => showSupportEmail(
                      context,
                      kind: SupportEmailKind.parent,
                    ),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('Email support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}
