import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: const [
          Text(
            'Hidavo Privacy Policy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Last updated: 17 August 2026',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 20),
          _P(
            'Hidavo is a personal “who among these people” quiz. '
            'You type a login, your display name, and first names of people '
            'you know. You then answer questions about that group. '
            'Those people do not need an account, and the app does not '
            'message them.',
          ),
          _H('What we store on your device'),
          _P(
            'This version keeps data only on your device: your login, '
            'display name, optional university and year, the first names '
            'you typed, your star balance, and quiz progress. '
            'There is no Hidavo server account in this build.',
          ),
          _H('What we do not collect'),
          _P(
            'We do not read your contacts, photos, or phone number. '
            'We do not sell personal data. We do not show ads in this version.',
          ),
          _H('Names you type'),
          _P(
            'First names you enter are answer labels for your quiz. '
            'Enter only names of people you know. Do not enter phone numbers, '
            'full legal names, or other private data.',
          ),
          _H('Sharing'),
          _P(
            'If you tap Share, the system share sheet can send a link to '
            'Hidavo. We do not upload your quiz answers when you share.',
          ),
          _H('Delete your data'),
          _P(
            'Settings → Delete account wipes the local data immediately. '
            'That cannot be undone.',
          ),
          _H('Age'),
          _P(
            'Hidavo is for people 14 and older. Do not use the app if you '
            'are under 14.',
          ),
          _H('Contact'),
          _P('Questions: ${AppConstants.supportEmail}'),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
    );
  }
}

Future<void> openSupportEmail() async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConstants.supportEmail,
    query: 'subject=Hidavo privacy',
  );
  await launchUrl(uri);
}
