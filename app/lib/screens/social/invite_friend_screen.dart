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
import '../../services/invitation_poller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/wait_pass_card.dart';

class InviteFriendScreen extends ConsumerStatefulWidget {
  const InviteFriendScreen({super.key});
  @override
  ConsumerState<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends ConsumerState<InviteFriendScreen>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _invites = [];
  String? _cursor, _error;
  bool _busy = false, _checking = false;
  late final InvitationPoller _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = InvitationPoller(
      check: _check,
      isVisible: () =>
          mounted &&
          !_busy &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) &&
          ModalRoute.of(context)?.isCurrent == true,
    );
    _check();
    _poll.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll.start();
      if (mounted && ModalRoute.of(context)?.isCurrent == true && !_busy) {
        unawaited(_check());
      }
    } else {
      _poll.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll.dispose();
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
      final whatsapp =
          ref.read(invitationServiceProvider).preferredChannel == 'whatsapp';
      final selected = await InvitationService.messages
          .invokeMapMethod<String, dynamic>('pickRecipient', {
            'title': whatsapp
                ? 'Choose a friend for WhatsApp'
                : 'Choose a friend to message',
          });
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
      _poll.start(afterInvitation: true);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Invite friends',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlueDark,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One friend. One more round.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Each eligible recipient unlocks one round of 12 questions. Unlock 10 rounds with 10 different recipients. You can complete up to 50 rounds per UTC day; unused unlocks stay in your account.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            WaitPassCard(onCheck: _check),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE9ECF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!service.signedIn && !_checking) ...[
                    const Text(
                      'Sign in to unlock rounds with invitations. Guest practice earns no invitation rewards.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.phone),
                      child: const Text('Sign in to invite'),
                    ),
                  ] else if (service.signedIn) ...[
                    Text(
                      whatsapp
                          ? 'Choose a friend, then review your invitation in WhatsApp. Choosing a contact does not send anything.'
                          : 'Choose a friend, then review your invitation in Messages. iMessage or SMS may be used. Carrier charges may apply. Nothing is sent until you tap Send.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If your friend has more than one number, choose the one to message. Raw contact numbers and contact names are not uploaded.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || !service.invitationsEnabled
                          ? null
                          : _invite,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _busy
                            ? 'Opening…'
                            : service.invitationsEnabled
                            ? service.inviteButtonText
                            : 'Invitations unavailable',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      whatsapp
                          ? 'The first 5 qualifying WhatsApp returns per UTC day unlock a round immediately. Later invitations unlock after the recipient confirms the link. Returning does not verify delivery.'
                          : 'A Messages sent result unlocks one round per recipient. Cancelled or failed messages do not. Sent does not confirm delivery.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If messaging is unavailable, sharing the link requires recipient confirmation.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: Text(_checking ? 'Checking…' : 'Check invitations'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            const Text(
              'My invitations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_invites.isEmpty && !_checking)
              const Text('Your invitations will appear here.'),
            for (final invite in _invites)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
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
