import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/content_service.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  Future<void> _mail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: ContentService.instance.text('support_email'),
      queryParameters: const {'subject': 'Flyprox game support'},
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Safety'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Flyprox is a name-based quiz game on your device. '
              'People you name are not contacted.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Rule(
            title: 'Use game names',
            body:
                'Nicknames and fictional names are welcome. Do not type phone numbers, addresses, full legal names or other private information.',
          ),
          const _Rule(
            title: 'Your answers stay here',
            body:
                'The local game does not send your choices to other people or to a Flyprox server.',
          ),
          const _Rule(
            title: 'Be kind',
            body:
                'Use the quiz for fun. Do not use it to harass or shame anyone.',
          ),
          const _Rule(
            title: 'Age 14+',
            body:
                'Flyprox is for people 14 and older. Do not use the app if you are under 14.',
          ),
          const _Rule(
            title: 'Report a question',
            body:
                'Use Report a question during a round or email support with the question text. Leave out participant names and sensitive information.',
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _mail(context),
            child: Text(
                'Email ${ContentService.instance.text('support_email')}'),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(body,
                style: const TextStyle(color: Colors.black54, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
