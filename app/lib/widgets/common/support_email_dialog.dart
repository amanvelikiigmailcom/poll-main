import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_info_service.dart';
import '../../services/support_email_service.dart';

Future<void> showSupportEmail(
  BuildContext context, {
  SupportEmailKind kind = SupportEmailKind.support,
  String? targetId,
  String? username,
  String? eventReference,
}) => showDialog<void>(
  context: context,
  builder: (_) => SupportEmailDialog(
    kind: kind,
    targetId: targetId,
    username: username,
    eventReference: eventReference,
  ),
);

class SupportEmailDialog extends ConsumerStatefulWidget {
  const SupportEmailDialog({
    super.key,
    required this.kind,
    this.targetId,
    this.username,
    this.eventReference,
  });
  final SupportEmailKind kind;
  final String? targetId, username, eventReference;
  @override
  ConsumerState<SupportEmailDialog> createState() => _SupportEmailDialogState();
}

class _SupportEmailDialogState extends ConsumerState<SupportEmailDialog> {
  final _details = TextEditingController();
  String? _reason, _status, _version;
  bool _opening = false;
  static const reasons = [
    'Bullying or harassment',
    'Inappropriate profile',
    'Impersonation',
    'Spam',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await AppInfoService.versionLabel();
    if (mounted) setState(() => _version = version);
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  SupportEmail get _email => SupportEmail(
    kind: widget.kind,
    details: _details.text,
    reason: _reason,
    targetId: widget.targetId,
    username: widget.username,
    version: _version,
    eventReference: widget.eventReference,
  );
  bool get _ready => widget.kind != SupportEmailKind.account || _reason != null;

  Future<void> _open() async {
    if (_opening || !_ready) return;
    setState(() => _opening = true);
    final opened = await ref
        .read(supportEmailServiceProvider)
        .openDraft(_email);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _status = opened
          ? 'Email draft opened. Send it from your email app when ready.'
          : 'Couldn’t open an email app. Copy the message and email it to ${_email.recipient}.';
    });
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _email.copyText));
      if (mounted) {
        setState(
          () => _status = 'Message copied. Email it to ${_email.recipient}.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Couldn’t copy. Select the message below.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind.title),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This opens an email draft. Send it from your email app to contact Flyprox.',
          ),
          if (widget.kind == SupportEmailKind.account) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Reason'),
              isExpanded: true,
              items: [
                for (final reason in reasons)
                  DropdownMenuItem(value: reason, child: Text(reason)),
              ],
              onChanged: _opening
                  ? null
                  : (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reporting does not block this account. You can block it from the account menu.',
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            enabled: !_opening,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: widget.kind == SupportEmailKind.account
                  ? 'Additional details (optional)'
                  : 'Your message',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SelectableText(_email.copyText),
          if (_status != null) ...[const SizedBox(height: 16), Text(_status!)],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: _ready && !_opening ? _copy : null,
        child: const Text('Copy message'),
      ),
      FilledButton(
        onPressed: _ready && !_opening ? _open : null,
        child: Text(_opening ? 'Opening…' : 'Open email'),
      ),
    ],
  );
}
