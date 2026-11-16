import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

/// Contains only the built-in question, never player names, choices or profile data.
class QuestionReport {
  const QuestionReport({required this.questionId, required this.questionText});

  final String questionId;
  final String questionText;

  String get recipient => AppConstants.supportEmail;
  String get subject => 'Flyprox question report: $questionId';
  String get body => 'Question ID: $questionId\n'
      'Question: $questionText\n\n'
      'Please describe the issue below. Do not include participant names '
      'or other private information.\n\n';

  Uri get emailUri => Uri(
        scheme: 'mailto',
        path: recipient,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

  String get copyText => 'To: $recipient\nSubject: $subject\n\n$body';
}

class QuestionReportService {
  const QuestionReportService({Future<bool> Function(Uri)? openEmail})
      : _openEmail = openEmail;

  final Future<bool> Function(Uri)? _openEmail;

  /// Opening an email draft never sends the report on the player's behalf.
  Future<bool> openDraft(QuestionReport report) async {
    try {
      return await (_openEmail?.call(report.emailUri) ??
          launchUrl(report.emailUri, mode: LaunchMode.externalApplication));
    } catch (_) {
      return false;
    }
  }
}
