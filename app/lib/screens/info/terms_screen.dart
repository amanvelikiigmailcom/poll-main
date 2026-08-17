import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Terms of Use',
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
            'Hidavo Terms of Use',
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
            'Hidavo is a personal quiz. You name people you know and answer '
            '“who among these” questions. It is not a live social network '
            'and does not require those people to join.',
          ),
          _H('Your use'),
          _P(
            'You must be at least 14. Use the app only for fun, personal '
            'quizzes. Do not harass anyone. Do not enter other people’s '
            'private data (phones, addresses, full legal names).',
          ),
          _H('Content'),
          _P(
            'Answers stay on your device in this version. You are '
            'responsible for the names you type.',
          ),
          _H('No account on our servers'),
          _P(
            'This version does not create a Hidavo server account. '
            'Deleting the app data or using Delete account removes the '
            'local quiz from this device.',
          ),
          _H('Contact'),
          _P(AppConstants.supportEmail),
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
