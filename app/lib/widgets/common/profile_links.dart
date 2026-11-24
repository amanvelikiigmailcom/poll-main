import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../router/app_router.dart';
import '../../services/profile_link.dart';

/// Keep the target in memory while gates or an unfinished round are active.
class ProfileLinks extends StatefulWidget {
  const ProfileLinks({super.key, required this.child});
  final Widget child;
  @override
  State<ProfileLinks> createState() => _ProfileLinksState();
}

class _ProfileLinksState extends State<ProfileLinks> {
  StreamSubscription<Uri>? _subscription;
  String? _pending;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    appRouter.routeInformationProvider.addListener(_navigate);
    _start();
  }

  Future<void> _start() async {
    try {
      final links = AppLinks();
      _subscription = links.uriLinkStream.listen(_receive, onError: (_) {});
      final initial = await links.getInitialLink();
      if (mounted && initial != null && _pending == null) _receive(initial);
    } catch (_) {
      /* Platform links are optional in widget tests. */
    }
  }

  void _receive(Uri uri) {
    final handle = ProfileLink.handle(uri);
    if (!mounted || handle == null) return;
    _pending = handle;
    _navigate();
  }

  void _navigate() {
    if (_pending == null || _scheduled) return;
    // Only stable tabs: never interrupt voting, OTP, age or campus setup.
    final path = appRouter.routeInformationProvider.value.uri.path;
    if (!{
      AppRoutes.home,
      AppRoutes.search,
      AppRoutes.profile,
      AppRoutes.likesEmpty,
      AppRoutes.likesFilled,
      AppRoutes.settings,
    }.contains(path)) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _pending == null) return;
      if (appRouter.routeInformationProvider.value.uri.path != path) {
        _navigate();
        return;
      }
      final target = _pending!;
      _pending = null;
      appRouter.push('/p/@$target');
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    appRouter.routeInformationProvider.removeListener(_navigate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
