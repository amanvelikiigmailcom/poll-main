import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../providers/auth_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'More',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Account'),
          _MenuItem(
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: () => context.push(AppRoutes.profile),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit profile',
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          _MenuItem(
            icon: Icons.collections_bookmark_outlined,
            label: 'Collection',
            onTap: () => context.push(AppRoutes.collection),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Social'),
          _MenuItem(
            icon: Icons.people_outline,
            label: 'My friends',
            onTap: () => context.push(AppRoutes.friends),
          ),
          _MenuItem(
            icon: Icons.person_add_alt_outlined,
            label: 'Friend requests',
            onTap: () => context.push(AppRoutes.friendRequests),
          ),
          _MenuItem(
            icon: Icons.share_outlined,
            label: 'Invite friend',
            onTap: () => context.push(AppRoutes.invite),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'App'),
          _MenuItem(
            icon: Icons.workspace_premium_outlined,
            label: 'Premium',
            badge: 'PRO',
            badgeColor: const Color(0xFFFFB800),
            onTap: () => context.push(AppRoutes.premium),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Other'),
          _MenuItem(
            icon: Icons.logout,
            label: 'Log out',
            labelColor: const Color(0xFFFF3B5C),
            iconColor: const Color(0xFFFF3B5C),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Log out',
                        style: TextStyle(color: Color(0xFFFF3B5C)),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.onboarding);
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeColor;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor,
    this.labelColor,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFF4B6EF5);
    final effectiveLabelColor = labelColor ?? const Color(0xFF1A1A2E);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: effectiveIconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: effectiveIconColor, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: effectiveLabelColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFF4B6EF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (badge != null) const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
