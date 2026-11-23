import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/invite_code_store.dart';
import '../../services/local_game_service.dart';

class InvitationCodeScreen extends ConsumerStatefulWidget {
  const InvitationCodeScreen({super.key, this.lateEntry = false});
  final bool lateEntry;
  @override
  ConsumerState<InvitationCodeScreen> createState() =>
      _InvitationCodeScreenState();
}

class _InvitationCodeScreenState extends ConsumerState<InvitationCodeScreen> {
  final _code = TextEditingController();
  String _source = 'typed';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    InviteCodeStore.changes.addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final code = await InviteCodeStore.code();
    final source = await InviteCodeStore.source();
    if (mounted && code != null && _code.text.isEmpty) {
      setState(() {
        _code.text = code;
        _source = source;
      });
    }
  }

  @override
  void dispose() {
    InviteCodeStore.changes.removeListener(_load);
    _code.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      setState(() {
        _code.text = InviteCodeStore.normalize(value?.text ?? '');
        _source = 'pasted';
        _error = null;
      });
      if (InviteCodeStore.pattern.hasMatch(_code.text)) {
        _record('code_pasted', _code.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t paste. You can type the code from the message.',
        );
      }
    }
  }

  Future<void> _record(String type, String code) async {
    if (!mounted) return;
    try {
      await ref
          .read(apiServiceProvider)
          .post('/i/$code/events', data: {'type': type});
    } catch (_) {
      /* Funnel telemetry never blocks registration. */
    }
  }

  Future<void> _continue({bool skip = false}) async {
    if (_busy) return;
    final code = InviteCodeStore.normalize(_code.text);
    if (!skip && !InviteCodeStore.pattern.hasMatch(code)) {
      setState(
        () => _error = 'Enter the six-character code from your invitation.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (skip) {
        await InviteCodeStore.clear();
      } else {
        await InviteCodeStore.save(code, _source);
        await InviteCodeStore.accept();
        _record(
          _source == 'pasted'
              ? 'code_pasted'
              : _source == 'link'
              ? 'app_open_with_code'
              : 'code_typed',
          code,
        );
      }
      await InviteCodeStore.markSeen();
      if (!mounted) return;
      if (!widget.lateEntry) {
        context.go(AppRoutes.phone);
        return;
      }
      final service = ref.read(invitationServiceProvider);
      if ((await ref.read(storageServiceProvider).getToken())?.isNotEmpty !=
          true) {
        if (mounted) context.go(AppRoutes.phone);
        return;
      }
      final names = await LocalGameService.instance.getFullName();
      if (names.$1.isEmpty || names.$2.isEmpty) {
        await LocalGameService.instance.setUsernameSetupPending(true);
        if (mounted) context.go(AppRoutes.username);
        return;
      }
      final claimed = await service.claimPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            claimed
                ? 'Invitation applied. Your wait pass is ready.'
                : 'No matching invitation found.',
          ),
        ),
      );
      context.go(AppRoutes.invite);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t apply the invitation. Your code is saved; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invitation code')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Were you invited?',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Apply the code from your message and register. You and your friend each get one pass to skip a 60-minute wait.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Your friend will see that you registered and receive your first name in an invitation notification. If they selected your phone number, we can also match your invitation after you verify it.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste invitation code'),
            ),
            const Text(
              'iPhone may ask for permission to paste. Choose Allow Paste, or type the code below.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('invitation-code'),
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Invitation code',
                hintText: 'K7M2QP',
                errorText: _error,
                errorMaxLines: 4,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                _source = 'typed';
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _continue(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _continue,
              child: Text(
                _busy
                    ? 'Checking…'
                    : widget.lateEntry
                    ? 'Apply invitation'
                    : 'Continue with code',
              ),
            ),
            if (!widget.lateEntry)
              TextButton(
                onPressed: _busy ? null : () => _continue(skip: true),
                child: const Text('Skip, I wasn’t invited'),
              ),
            if (widget.lateEntry)
              const Text(
                'Available for seven days after account creation. Each new account can apply one invitation.',
              ),
          ],
        ),
      ),
    ),
  );
}
