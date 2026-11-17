import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/question_report_service.dart';

class QuestionReportDialog extends StatefulWidget {
  const QuestionReportDialog({
    super.key,
    required this.report,
    this.service = const QuestionReportService(),
  });

  final QuestionReport report;
  final QuestionReportService service;

  @override
  State<QuestionReportDialog> createState() => _QuestionReportDialogState();
}

class _QuestionReportDialogState extends State<QuestionReportDialog> {
  bool _opening = false;
  String? _status;

  Future<void> _openEmail() async {
    if (_opening) return;
    setState(() => _opening = true);
    final opened = await widget.service.openDraft(widget.report);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _status = opened
          ? 'Email draft opened. Send it from your email app when ready.'
          : 'Couldn’t open an email app. Copy the report and email it to '
              '${widget.report.recipient}.';
    });
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.report.copyText));
      if (!mounted) return;
      setState(() =>
          _status = 'Report copied. Email it to ${widget.report.recipient}.');
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _status = 'Couldn’t copy the report. Select the text below.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Report question'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe the issue in your email app, then send.',
            ),
            const SizedBox(height: 16),
            SelectableText(widget.report.copyText),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy report'),
          ),
          ElevatedButton(
            onPressed: _opening ? null : _openEmail,
            child: Text(_opening ? 'Opening…' : 'Open email'),
          ),
        ],
      );
}
