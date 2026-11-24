import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/contact_sync_service.dart';
import '../../services/invitation_service.dart';
import '../../widgets/common/wait_pass_card.dart';

class InviteFriendScreen extends ConsumerStatefulWidget {
  const InviteFriendScreen({super.key});
  @override
  ConsumerState<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends ConsumerState<InviteFriendScreen> {
  final List<Map<String, dynamic>> _invites = [];
  String? _cursor, _error;
  bool _busy = false, _checking = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _check();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _check();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
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
      final storage = ref.read(storageServiceProvider);
      final token = await storage.getToken();
      final service = ref.read(invitationServiceProvider);
      await service.refresh();
      if (!service.signedIn || token != await storage.getToken()) return;
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
      if (!mounted || token != await storage.getToken()) return;
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
              'Couldn’t check invitations. Your unlocked rounds are saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _invite() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final token = await storage.getToken();
      final selected = await InvitationService.messages
          .invokeMapMethod<String, dynamic>('pickRecipient');
      if (!mounted || selected == null || token != await storage.getToken()) {
        return;
      }
      final region = await ref.read(onboardingDetailsProvider).country();
      final iso =
          IsoCode.values.where((value) => value.name == region).firstOrNull ??
          IsoCode.US;
      final phone = ContactSyncService.normalizePhone(
        selected['phone'] as String? ?? '',
        defaultRegion: iso,
      );
      if (phone == null) {
        _notice('Choose a valid phone number.');
        return;
      }
      final service = ref.read(invitationServiceProvider);
      final invite = await service.create(phone: phone);
      if (!mounted || token != await storage.getToken()) return;
      final result = await service.sendV2(invite, phone);
      _notice(switch (result) {
        'sent' => 'Message queued or sent. Checking your unlocked round…',
        'opened' => 'Checking your WhatsApp invitation when you return.',
        'shared' =>
          'Your round unlocks after the recipient confirms the invitation link.',
        'cancelled' => 'Invitation cancelled. No round was activated.',
        _ => 'Couldn’t send the invitation. Please try again.',
      });
      await _check();
    } on ApiException catch (e) {
      _notice(e.message);
    } catch (_) {
      _notice('Couldn’t open the invitation. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(invitationServiceProvider);
    final whatsapp = service.preferredChannel == 'whatsapp';
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'One friend. One more round.',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Each eligible recipient unlocks one round of 12 questions. Unlock 10 rounds with 10 different recipients. You can complete up to 50 rounds per UTC day; unused unlocks stay in your account.',
            ),
            const SizedBox(height: 16),
            WaitPassCard(onCheck: _check),
            const SizedBox(height: 16),
            if (!service.signedIn && !_checking) ...[
              const Text(
                'Sign in to unlock rounds with invitations. Guest practice earns no invitation rewards.',
              ),
              FilledButton(
                onPressed: () => context.push(AppRoutes.phone),
                child: const Text('Sign in to invite'),
              ),
            ] else if (service.signedIn) ...[
              const Text(
                'Choose one friend and one phone number. Raw contact numbers and contact names are not uploaded.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(
                  _busy
                      ? 'Opening…'
                      : whatsapp
                      ? 'Invite through WhatsApp'
                      : 'Invite through Messages',
                ),
              ),
              Text(
                whatsapp
                    ? 'The first 5 qualifying WhatsApp returns per UTC day unlock a round immediately. Later invitations unlock after the recipient confirms the link. Returning does not verify delivery.'
                    : 'A Messages sent result unlocks one round per recipient. Cancelled or failed messages do not. Sent does not confirm delivery.',
              ),
              const Text(
                'If messaging is unavailable, sharing the link requires recipient confirmation.',
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: Text(_checking ? 'Checking…' : 'Check invitations'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            const Text(
              'My invitations',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (_invites.isEmpty && !_checking)
              const Text('Your invitations will appear here.'),
            for (final invite in _invites)
              Card(
                child: ListTile(
                  title: Text('Code ${invite['code']}'),
                  subtitle: Text(switch (invite['status']) {
                    'activated' => '1 round activated · 12 questions',
                    'waiting_confirmation' =>
                      'Waiting for recipient confirmation',
                    _ => 'Not activated',
                  }),
                  trailing: invite['activated'] == true
                      ? const Icon(Icons.check_circle_outline)
                      : IconButton(
                          tooltip: 'Copy invitation',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: InvitationService.message(invite),
                              ),
                            );
                            _notice('Invitation copied');
                          },
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
