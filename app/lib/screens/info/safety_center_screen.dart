import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/constants.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  Future<void> _mail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=Hidavo safety',
    );
    await launchUrl(uri);
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
              'Hidavo is a private quiz on your device. '
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
            title: 'First names only',
            body:
                'Do not type phone numbers, addresses, or full legal names.',
          ),
          const _Rule(
            title: 'Your answers stay here',
            body:
                'This version does not send votes to other people or to a Hidavo server.',
          ),
          const _Rule(
            title: 'Be kind',
            body:
                'Use the quiz for fun. Do not use it to harass or shame anyone.',
          ),
          const _Rule(
            title: 'Age 18+',
            body: 'Hidavo is for adults 18+ only. Not for children.',
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _mail,
            child: const Text('Email ${AppConstants.supportEmail}'),
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
            Text(body, style: const TextStyle(color: Colors.black54, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
