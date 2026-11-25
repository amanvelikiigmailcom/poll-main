import 'package:flutter/material.dart';
import '../../services/support_email_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/support_email_dialog.dart';

/// Pushes carry a type only; no event details are inferred from it.
class AccountNoticeScreen extends StatelessWidget {
  const AccountNoticeScreen({
    super.key,
    this.security = false,
    this.eventReference,
  });
  final bool security;
  final String? eventReference;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(title: Text(security ? 'New sign-in' : 'Account update')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(security ? Icons.security_outlined : Icons.info_outline, size: 48),
        const SizedBox(height: 24),
        Text(
          security ? 'Was this you?' : 'Questions about your account?',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Text(
          security
              ? 'This notification concerns a sign-in on another app installation. If you recognize it, no further action is needed. If you don’t, contact support. Never share your sign-in codes.'
              : 'This notification concerns a moderation update to your account. Details are not available on this screen. Contact support to ask about the update or request a review.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => showSupportEmail(
            context,
            eventReference: eventReference,
            kind: security
                ? SupportEmailKind.security
                : SupportEmailKind.moderation,
          ),
          child: const Text('Contact support'),
        ),
        const SizedBox(height: 12),
        const SelectableText('support@flyprox.com'),
      ],
    ),
  );
}
