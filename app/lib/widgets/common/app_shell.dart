import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import 'bottom_nav_bar.dart';

/// Local-game pages with five tabs at the bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.navigationShell});

  final StatefulNavigationShell? navigationShell;

  final Widget child;

  static int indexFor(String path) {
    if (path.startsWith('/home/search') || path.startsWith('/people/')) {
      return 1;
    }
    if (path.startsWith('/likes')) return 2;
    if (path.startsWith('/home/profile') ||
        path.startsWith('/edit-profile') ||
        path.startsWith('/invite')) {
      return 3;
    }
    if (path.startsWith('/settings') ||
        path.startsWith('/friend') ||
        path.startsWith('/blocked') ||
        path.startsWith('/hidden') ||
        path.startsWith('/faq') ||
        path.startsWith('/for-parents') ||
        path.startsWith('/privacy') ||
        path.startsWith('/terms') ||
        path.startsWith('/how-to') ||
        path.startsWith('/safety') ||
        path.startsWith('/delete-account')) {
      return 4;
    }
    return 0; // Home, questions, results and cooldown belong to the same game tab.
  }

  Future<void> _onTap(BuildContext context, int index) async {
    final path = GoRouterState.of(context).uri.path;
    if (index == 0 &&
        indexFor(path) == 0 &&
        (path == AppRoutes.home ||
            path == AppRoutes.vote ||
            path == AppRoutes.timer ||
            path == AppRoutes.starReceived)) {
      return;
    }
    if (navigationShell != null) {
      navigationShell!.goBranch(
        index,
        initialLocation: index == navigationShell!.currentIndex,
      );
      return;
    }
    switch (index) {
      case 0:
        final remaining = await LocalGameService.instance
            .secondsUntilNextRound();
        final progress = await LocalGameService.instance.loadRoundProgress();
        if (!context.mounted) return;
        context.go(
          remaining > 0
              ? AppRoutes.timer
              : progress != null
              ? AppRoutes.vote
              : AppRoutes.home,
        );
      case 1:
        context.go(AppRoutes.search);
      case 2:
        context.go(AppRoutes.likesEmpty);
      case 3:
        context.go(AppRoutes.profile);
      case 4:
        context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell?.currentIndex ?? indexFor(path),
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}
