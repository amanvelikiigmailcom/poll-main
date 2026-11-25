import 'package:flutter/material.dart';
import '../../services/support_email_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/support_email_dialog.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(title: const Text('Safety')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final entry in const [
          ('Age 13+', 'Flyprox is for people aged 13 and over.'),
          (
            'Be kind',
            'Do not use the game to bully, harass or embarrass anyone. You can skip a question that feels uncomfortable.',
          ),
          (
            'Guest and online play',
            'Guest rounds stay on your device. Eligible signed-in players can send and receive online votes. Matching registered contacts can receive vote notifications; selecting a contact alone sends no invitation.',
          ),
          (
            'Report an account',
            'Open the account menu, choose Report account, select a reason and open email. Send the draft to support@flyprox.com. Opening a draft does not send your report.',
          ),
          (
            'Block an account',
            'Choose Block account from the account menu to prevent new requests and online votes between your accounts and hide each other in search. Blocking is separate from reporting. Manage blocks in Settings → Blocked users.',
          ),
          (
            'Report a question',
            'During a round, choose Report a question. The email draft includes the question and its reference, without participant names or your answers. Send it from your email app.',
          ),
          (
            'Protect private information',
            'Do not include passwords, sign-in codes, phone numbers, contact lists or other sensitive details in reports. If email is unavailable, copy the message and send it later.',
          ),
        ]) ...[
          Text(
            entry.$1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(entry.$2),
          const SizedBox(height: 24),
        ],
        FilledButton.icon(
          onPressed: () => showSupportEmail(context),
          icon: const Icon(Icons.mail_outline),
          label: const Text('Contact support'),
        ),
        TextButton(
          onPressed: () =>
              showSupportEmail(context, kind: SupportEmailKind.problem),
          child: const Text('Report a problem'),
        ),
        const Center(child: SelectableText('support@flyprox.com')),
      ],
    ),
  );
}
