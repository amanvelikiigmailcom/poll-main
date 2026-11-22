import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/content_service.dart';

class ForParentsScreen extends ConsumerWidget {
  const ForParentsScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: ContentService.instance.text('support_email'),
      queryParameters: const {'subject': 'Flyprox parent or guardian question'},
    );
    try {
      final opened = await launchUrl(uri);
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      final email = ContentService.instance.text('support_email');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please email $email')),
      );
    }
  }

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
              'Flyprox is a name-based quiz game played on one device. Players select at least four contacts or use ready-made examples, then play 12-question rounds.',
            ),
            _section(
              Icons.lock_rounded,
              'Participant names',
              'Nicknames and fictional names are welcome. Participant labels may be fictional. In optional online play, selected contacts matching registered accounts can receive vote notifications. Merely choosing a contact sends no invitation.',
            ),
            _section(
              Icons.child_care_rounded,
              'Age and responsible play',
              'Flyprox is intended for people aged 13 and over. Use it for entertainment and discuss respectful play. Do not enter sensitive information about anyone or use the game to harass or embarrass another person.',
            ),
            _section(
              Icons.privacy_tip_rounded,
              'Game data and privacy',
              'The game profile, participant names and progress are stored locally. Guest play needs no account. Signed-in online rounds use account identifiers, selected-contact hashes and votes. Optional phone sign-in is offered before the age question. Underage answers block contacts, gameplay and subscription access for the current run. Read the Privacy Policy for details.',
            ),
            _section(
              Icons.supervisor_account_rounded,
              'Helping a player',
              'Explore the game together, use example names if preferred, and discuss the prompts. Report a concerning question using Report a question or email support. Choose Reset game in Settings to delete local game data.',
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
                  const Text('Parent and guardian support',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  Text(ContentService.instance.text('support_email'),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendEmail(context),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('Email support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _primaryBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
          const SizedBox(height: 10),
          Text(body,
              style: const TextStyle(color: Colors.black87, height: 1.5)),
        ],
      ),
    );
  }
}
