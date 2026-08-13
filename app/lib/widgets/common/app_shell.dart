import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import 'bottom_nav_bar.dart';
import 'more_menu_sheet.dart';

/// Logged-in chrome: page on top, Instagram-style tab bar always at the bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int indexFor(String path) {
    if (path.startsWith('/home/activity') || path == '/activity') return 1;
    if (path.startsWith('/vote') ||
        path.startsWith('/before-vote') ||
        path.startsWith('/star-') ||
        path.startsWith('/timer')) {
      return 2;
    }
    if (path.contains('like')) return 3;
    if (path.startsWith('/home/profile') ||
        path.startsWith('/profile') ||
        path.startsWith('/edit-profile') ||
        path.startsWith('/settings') ||
        path.startsWith('/friends') ||
        path.startsWith('/collection') ||
        path.startsWith('/premium') ||
        path.startsWith('/invite') ||
        path.startsWith('/notifications') ||
        path.startsWith('/language') ||
        path.startsWith('/blocked') ||
        path.startsWith('/hidden') ||
        path.startsWith('/delete-account')) {
      return 4;
    }
    return 0;
  }

  Future<void> _onTap(BuildContext context, int index) async {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.activity);
      case 2:
        final ready = await LocalGameService.instance.hasEnoughNames();
        if (!context.mounted) return;
        context.go(ready ? AppRoutes.vote : AppRoutes.namesEntry);
      case 3:
        context.go(AppRoutes.likesEmpty);
      case 4:
        showMoreMenu(context);
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
