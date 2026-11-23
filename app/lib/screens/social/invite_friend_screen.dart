import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/contact_sync_service.dart';
import '../../services/invitation_service.dart';
import '../../services/local_game_service.dart';
import '../../widgets/common/wait_pass_card.dart';

class InviteFriendScreen extends ConsumerStatefulWidget {
  const InviteFriendScreen({super.key});
  @override
  ConsumerState<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends ConsumerState<InviteFriendScreen> {
  final List<Map<String, dynamic>> _invites = [];
  String? _cursor, _phone, _name, _error;
  Map<String, dynamic>? _current;
  bool _busy = false, _checking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _check({bool more = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final service = ref.read(invitationServiceProvider);
      await service.refresh();
      if (!service.signedIn) return;
      final data =
          (await ref
                  .read(apiServiceProvider)
                  .get<Map<String, dynamic>>(
                    '/api/invites/mine',
                    queryParameters: {
                      if (more && _cursor != null) 'cursor': _cursor,
                    },
                  ))
              .data!;
      if (!mounted) return;
      setState(() {
        if (!more) _invites.clear();
        _invites.addAll(
          (data['invites'] as List).map((r) => Map<String, dynamic>.from(r)),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t load invitations. Your passes are safe; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pick() async {
    try {
      final result = await InvitationService.messages
          .invokeMapMethod<String, dynamic>('pickRecipient');
      if (!mounted || result == null) return;
      final phone = ContactSyncService.normalizePhone(
        result['phone'] as String? ?? '',
      );
      if (phone == null) {
        _notice('Choose a contact with a valid international phone number.');
        return;
      }
      setState(() {
        _phone = phone;
        _name = result['name'] as String?;
        _current = null;
      });
    } catch (_) {
      _notice(
        'Couldn’t open contacts. You can choose a recipient inside Messages instead.',
      );
    }
  }

  Future<void> _send({Map<String, dynamic>? reminder}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final names = await LocalGameService.instance.getFullName();
      if (names.$1.isEmpty || names.$2.isEmpty) {
        await LocalGameService.instance.setUsernameSetupPending(true);
        if (mounted) context.push(AppRoutes.username);
        return;
      }
      final service = ref.read(invitationServiceProvider);
      final invite =
          reminder ?? _current ?? await service.create(phone: _phone);
      if (!mounted) return;
      setState(() => _current = invite);
      final result = await service.compose(
        invite,
        phone: reminder == null ? _phone : null,
        reminder: reminder != null,
      );
      _notice(switch (result) {
        'sent' =>
          'Invitation sent. Your pass arrives after your friend registers.',
        'cancelled' => 'Message cancelled. No pass was used or awarded.',
        'unavailable' =>
          'Messages isn’t available on this device. Copy the invitation below.',
        _ => 'Couldn’t send the message. Try again or copy the invitation.',
      });
      await _check();
    } on ApiException catch (e) {
      _notice(e.message);
    } catch (_) {
      _notice(
        'Couldn’t open Messages. You can copy your invitation if a code was created.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(invitationServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'One new friend. One wait pass each.',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Send your friend a link and code in Messages. After they register with your invitation, you both earn one pass. An available pass removes your current 60-minute wait automatically; otherwise it stays for your next wait.',
            ),
            const SizedBox(height: 16),
            WaitPassCard(onCheck: _check),
            const SizedBox(height: 16),
            if (!service.signedIn && !_checking) ...[
              const Text(
                'Sign in with your phone number to invite friends and earn passes. Guest play stays available.',
              ),
              FilledButton(
                onPressed: () => context.push(AppRoutes.phone),
                child: const Text('Sign in to invite'),
              ),
            ] else if (service.signedIn) ...[
              const Text(
                'Optional: choose one contact for automatic invitation matching. Only that number is sent securely to Flyprox to create a keyed hash; the number is not stored. Your address book is never uploaded.',
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.person_outline),
                label: Text(
                  _name == null
                      ? 'Choose one friend (optional)'
                      : 'Selected: $_name',
                ),
              ),
              if (_phone != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _phone = null;
                          _name = null;
                          _current = null;
                        }),
                  child: const Text('Remove selected contact'),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _send(),
                icon: const Icon(Icons.message_outlined),
                label: Text(_busy ? 'Opening…' : 'Invite through Messages'),
              ),
              const Text(
                'You choose whether to send. Sending, cancelling or opening a link does not award a pass. Up to 100 new invitations a day, 20 an hour.',
                style: TextStyle(fontSize: 13),
              ),
              if (_current != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'Invitation code: ${_current!['code']}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: InvitationService.message(_current!)),
                    );
                    _notice('Invitation copied');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy invitation'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _current = null;
                          _phone = null;
                          _name = null;
                        }),
                  child: const Text('Create an invitation for another friend'),
                ),
              ],
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: Text(_checking ? 'Checking…' : 'Check invitations'),
            ),
            const Text(
          'Passes arrive after your friend registers with your code or matching phone number.',
              style: TextStyle(fontSize: 13),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            const Text(
              'My invitations',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (_invites.isEmpty && !_checking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Your invitations will appear here.'),
              ),
            for (final invite in _invites)
              Card(
                child: ListTile(
                  isThreeLine: true,
                  title: Text(
                    invite['friendName'] as String? ?? 'Code ${invite['code']}',
                  ),
                  subtitle: Text(
                    '${switch (invite['status']) {
                      'registered' => 'Registered · pass earned',
                      'link_opened' => 'Link opened · registration pending',
                      'compose_sent' => 'Sent · registration pending',
                      _ => 'Created · ready to send',
                    }}\nCode: ${invite['code']}',
                  ),
                  trailing: invite['status'] == 'registered'
                      ? const Icon(Icons.check_circle_outline)
                      : IconButton(
                          tooltip: 'Remind through Messages',
                          onPressed: _busy
                              ? null
                              : () => _send(reminder: invite),
                          icon: const Icon(Icons.message_outlined),
                        ),
                ),
              ),
            if (_cursor != null)
              TextButton(
                onPressed: _checking ? null : () => _check(more: true),
                child: const Text('Load more'),
              ),
          ],
        ),
      ),
    );
  }
}
