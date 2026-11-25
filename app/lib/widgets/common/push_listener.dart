import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../services/push_driver.dart';
import '../../services/push_routing.dart';
import '../../services/push_service.dart';
import '../../services/age_gate_service.dart';
import '../../services/local_game_service.dart';
import '../../services/invite_code_store.dart';

/// Shows foreground pushes as snackbars anywhere inside the tab shell.
/// Mounted once around shell content; subscriptions die with it.
class PushListener extends ConsumerStatefulWidget {
  const PushListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener>
    with WidgetsBindingObserver {
  StreamSubscription? _messages;
  StreamSubscription? _refresh;
  StreamSubscription? _taps;
  PushService? _push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);
    _push = push;
    _refresh = push.startTokenRefreshSync();
    _messages = push.foregroundMessages.listen(_show);
    _taps = push.pushTaps.listen(_open);
    unawaited(push.syncToken());
    unawaited(_syncInvitations());
    unawaited(_syncNotifications());
    unawaited(_armAndDrain(push));
  }

  /// Arms live taps, then drains a tap that landed in the gap (including a
  /// tap made while the launch intro was still playing).
  Future<void> _armAndDrain(PushService push) async {
    await push.setTapArmed(true);
    if (!mounted) return;
    final tap = await push.getInitialTap();
    if (!mounted || tap == null) return;
    _open(tap);
  }

  int _tapRevision = 0;
  Future<void> _open(PushTap tap) async {
    final revision = ++_tapRevision;
    if (!await PushRouting.canOpen(tap, ref.read(storageServiceProvider))) {
      return;
    }
    if (!mounted || revision != _tapRevision) return;
    final route = PushRouting.locationFor(tap);
    if (!mounted || route == null) return;
    GoRouter.of(context).go(route);
  }

  Future<void> _syncNotifications() async {
    if (!mounted || AgeGateService.instance.status != AgeGateStatus.verified) {
      return;
    }
    try {
      await ref.read(notificationPreferencesProvider).recordActivityAndReview();
    } catch (_) {
      /* Keep the app usable during rollout or offline. */
    }
  }

  Future<void> _syncInvitations() async {
    if (AgeGateService.instance.status != AgeGateStatus.verified) return;
    try {
      final service = ref.read(invitationServiceProvider);
      final game = LocalGameService.instance;
      final prefsPending = await game.isUsernameSetupPending();
      if (!prefsPending &&
          !await InviteCodeStore.needsAttention() &&
          (await InviteCodeStore.accepted() ||
              await service.registrationPending())) {
        await service.claimPending();
      }
      await service.refresh();
    } catch (_) {
      /* Pending code stays available for explicit Retry. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushServiceProvider).syncToken());
      unawaited(_syncInvitations());
      unawaited(_syncNotifications());
    }
  }

  void _show(PushMessage message) {
    unawaited(_syncInvitations());
    if (!mounted) return;
    final title = message.title.trim();
    final body = message.body.trim();
    if (title.isEmpty && body.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          title.isEmpty ? body : '$title — $body',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messages?.cancel();
    _refresh?.cancel();
    _taps?.cancel();
    unawaited(_push?.setTapArmed(false));
    _push = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
