import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

/// Contains only the built-in question, never player names, choices or profile data.
class QuestionReport {
  const QuestionReport({required this.questionId, required this.questionText});

  final String questionId;
  final String questionText;

  String get recipient => AppConstants.supportEmail;
  String get subject => 'Flyprox question report';
  String get body => 'Question: $questionText\n\n'
      'What’s wrong?\n\n\n'
      'Please leave out names and private details.\n\n'
      'Reference: $questionId';

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
