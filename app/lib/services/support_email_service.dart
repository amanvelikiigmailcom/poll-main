import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

enum SupportEmailKind {
  support,
  feedback,
  problem,
  account,
  parent,
  moderation,
  security,
}

extension SupportEmailKindText on SupportEmailKind {
  String get title => switch (this) {
    SupportEmailKind.support => 'Contact support',
    SupportEmailKind.feedback => 'Send feedback',
    SupportEmailKind.problem => 'Report a problem',
    SupportEmailKind.account => 'Report account',
    SupportEmailKind.parent => 'Parent and guardian support',
    SupportEmailKind.moderation => 'Ask about an account update',
    SupportEmailKind.security => 'Report an unrecognized sign-in',
  };
  String get subject => switch (this) {
    SupportEmailKind.support => 'Flyprox support',
    SupportEmailKind.feedback => 'Flyprox feedback',
    SupportEmailKind.problem => 'Flyprox problem report',
    SupportEmailKind.account => 'Flyprox account report',
    SupportEmailKind.parent => 'Flyprox parent or guardian question',
    SupportEmailKind.moderation => 'Flyprox moderation question',
    SupportEmailKind.security => 'Flyprox sign-in concern',
  };
}

/// Only explicitly entered text and the public target reference enter the draft.
/// Opening a draft does not submit a server report or prove an email was sent.
class SupportEmail {
  const SupportEmail({
    required this.kind,
    this.details = '',
    this.reason,
    this.targetId,
    this.username,
    this.version,
    this.eventReference,
  });

  final SupportEmailKind kind;
  final String details;
  final String? reason, targetId, username, version, eventReference;
  String get recipient => AppConstants.supportEmail;
  String get subject => kind.subject;
  String get body => [
    if (username != null) 'Account: @$username',
    if (targetId != null) 'Account reference: $targetId',
    if (reason != null) 'Reason: $reason',
    if (eventReference != null) 'Notification reference: $eventReference',
    '',
    details.trim().isEmpty
        ? 'Describe your question or concern here.'
        : details.trim(),
    '',
    'Please leave out passwords, sign-in codes, phone numbers and other private details.',
    if (version != null) 'App: $version',
  ].join('\n');
  Uri get emailUri => Uri(
    scheme: 'mailto',
    path: recipient,
    query:
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  String get copyText => 'To: $recipient\nSubject: $subject\n\n$body';
}

class SupportEmailService {
  const SupportEmailService({this.openEmail});
  final Future<bool> Function(Uri)? openEmail;
  Future<bool> openDraft(SupportEmail email) async {
    try {
      return await (openEmail?.call(email.emailUri) ??
          launchUrl(email.emailUri, mode: LaunchMode.externalApplication));
    } catch (_) {
      return false;
    }
  }
}

final supportEmailServiceProvider = Provider<SupportEmailService>(
  (ref) => const SupportEmailService(),
);
