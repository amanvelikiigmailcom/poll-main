import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

/// Overflow menu for the 5th tab: settings and everything that does not fit.
void showMoreMenu(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MoreMenuSheet(),
  );
}

class MoreMenuSheet extends ConsumerWidget {
  const MoreMenuSheet({super.key});

  void _open(BuildContext context, String route, {bool replaceTab = false}) {
    Navigator.of(context).pop();
    if (replaceTab) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(localProfileProvider);
    final name = local.playerName.isNotEmpty ? local.playerName : 'You';
    final login = local.username.isNotEmpty ? '@${local.username}' : '';
    final letter = local.avatarLetter;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                onTap: () => _open(context, AppRoutes.profile, replaceTab: true),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: login.isEmpty
                    ? null
                    : Text(
                        login,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              const Divider(height: 20),
              _Row(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () => _open(context, AppRoutes.editProfile),
              ),
              _Row(
                icon: Icons.group_outlined,
                label: 'Friends',
                onTap: () => _open(context, AppRoutes.friends),
              ),
              _Row(
                icon: Icons.person_add_alt_outlined,
                label: 'Friend requests',
                onTap: () => _open(context, AppRoutes.friendRequests),
              ),
              _Row(
                icon: Icons.ios_share_outlined,
                label: 'Invite',
                onTap: () => _open(context, AppRoutes.invite),
              ),
              _Row(
                icon: Icons.workspace_premium_outlined,
                label: 'Premium',
                onTap: () => _open(context, AppRoutes.premium),
              ),
              _Row(
                icon: Icons.collections_bookmark_outlined,
                label: 'Collection',
                onTap: () => _open(context, AppRoutes.collection),
              ),
              const Divider(height: 20),
              _Row(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => _open(context, AppRoutes.settings),
              ),
              _Row(
                icon: Icons.help_outline_rounded,
                label: 'How to use',
                onTap: () => _open(context, AppRoutes.howToUse),
              ),
              _Row(
                icon: Icons.shield_outlined,
                label: 'Safety',
                onTap: () => _open(context, AppRoutes.safetyCenter),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
      ),
    );
  }
}
