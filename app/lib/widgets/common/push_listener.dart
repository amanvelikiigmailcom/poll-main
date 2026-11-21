import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';
import '../../services/push_driver.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);
    _refresh = push.startTokenRefreshSync();
    _messages = push.foregroundMessages.listen(_show);
    unawaited(push.syncToken());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushServiceProvider).syncToken());
    }
  }

  void _show(PushMessage message) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
