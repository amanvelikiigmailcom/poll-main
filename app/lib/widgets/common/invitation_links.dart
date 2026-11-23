import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../router/app_router.dart';
import '../../services/invite_code_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';

/// Save attribution before navigation. Receiving a link cannot bypass the age
/// gate or destroy a vote/OTP screen that is already in progress.
class InvitationLinks extends StatefulWidget {
  const InvitationLinks({super.key, required this.child});
  final Widget child;
  @override
  State<InvitationLinks> createState() => _InvitationLinksState();
}

class _InvitationLinksState extends State<InvitationLinks> {
  StreamSubscription<Uri>? _subscription;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final links = AppLinks();
      final saved = await InviteCodeStore.code();
      if (saved != null && await InviteCodeStore.source() == 'link') {
        unawaited(_recordOpen(saved));
      }
      if (!mounted) return;
      _subscription = links.uriLinkStream.listen(
        (uri) => unawaited(_receive(uri)),
        onError: (_) {},
      );
    } catch (_) {
      /* Missing platform plugin in tests/web keeps normal login. */
    }
  }

  Future<void> _receive(Uri uri, {bool navigate = true}) async {
    if (uri.scheme != 'https' ||
        uri.host != 'api.flyprox.com' ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'i') {
      return;
    }
    final code = InviteCodeStore.normalize(uri.toString());
    if (!InviteCodeStore.pattern.hasMatch(code)) return;
    final previous = await InviteCodeStore.code();
    if (previous != null) return;
    await InviteCodeStore.save(code, 'link');
    unawaited(_recordOpen(code));
    if (!mounted || !navigate) return;
    final path = appRouter.routeInformationProvider.value.uri.path;
    if ([
      AppRoutes.onboarding,
      AppRoutes.phone,
      AppRoutes.invitationCode,
    ].contains(path)) {
      appRouter.go(AppRoutes.invitationCode);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Invitation code saved. Apply it in Settings → Invitation code.',
          ),
        ),
      );
    }
  }

  Future<void> _recordOpen(String code) async {
    if (!mounted) return;
    try {
      await ProviderScope.containerOf(context, listen: false)
          .read(apiServiceProvider)
          .post('/i/$code/events', data: {'type': 'app_open_with_code'});
    } catch (_) {
      /* A link is usable even when observation is offline. */
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
