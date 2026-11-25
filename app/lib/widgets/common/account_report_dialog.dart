import 'package:flutter/material.dart';

Future<String?> showAccountReportDialog(
  BuildContext context,
) => showDialog<String>(
  context: context,
  builder: (dialog) => SimpleDialog(
    title: const Text('Report account'),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          'Your report is stored privately by Flyprox. Reporting does not block this account.',
        ),
      ),
      for (final entry in const {
        'bullying': 'Bullying or harassment',
        'impersonation': 'Impersonation',
        'inappropriate': 'Inappropriate content',
        'spam': 'Spam',
        'safety_concern': 'Other safety concern',
      }.entries)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialog, entry.key),
          child: Text(entry.value),
        ),
      TextButton(
        onPressed: () => Navigator.pop(dialog),
        child: const Text('Cancel'),
      ),
    ],
  ),
);
