import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import 'bottom_nav_bar.dart';

/// Logged-in chrome: page on top, three working tabs at the bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int indexFor(String path) {
    if (path.startsWith('/vote') ||
        path.startsWith('/star-') ||
        path.startsWith('/timer')) {
      return 1;
    }
    if (path.startsWith('/home/profile') ||
        path.startsWith('/profile') ||
        path.startsWith('/edit-profile') ||
        path.startsWith('/settings') ||
        path.startsWith('/invite') ||
        path.startsWith('/privacy') ||
        path.startsWith('/terms') ||
        path.startsWith('/how-to') ||
        path.startsWith('/safety') ||
        path.startsWith('/delete-account')) {
      return 2;
    }
    return 0;
  }

  Future<void> _onTap(BuildContext context, int index) async {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        final ready = await LocalGameService.instance.hasEnoughNames();
        if (!context.mounted) return;
        context.go(ready ? AppRoutes.vote : AppRoutes.namesEntry);
      case 2:
        context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: indexFor(path),
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}
