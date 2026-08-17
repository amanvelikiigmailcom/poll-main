import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userNotifierProvider);
    final user = userState.user;
    final local = ref.watch(localProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: userState.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              )
            : RefreshIndicator(
                color: AppColors.primaryBlue,
                onRefresh: () async {
                  await ref.read(localProfileProvider.notifier).refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _ProfileHeaderCard(user: user, local: local),
                      const SizedBox(height: 12),
                      const _ProfileActions(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card: avatar + name + school + stats
// ---------------------------------------------------------------------------

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({this.user, required this.local});

  final User? user;
  final LocalProfile local;

  @override
  Widget build(BuildContext context) {
    final displayName = local.playerName.isNotEmpty
        ? local.playerName
        : (user?.firstName ?? '');
    final login = local.username.isNotEmpty
        ? local.username
        : (user?.username ?? '');
    final username = login.isNotEmpty ? '@$login' : '';
    final universityInfo = local.universityLine;
    final isPremium = user?.isPremium ?? false;
    final letter = LocalGameService.avatarLetter(
      displayName: displayName,
      username: login,
    );

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push(AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          _AvatarWidget(user: user, letter: letter, radius: 52),
          const SizedBox(height: 14),
          // Name + verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isPremium) ...[
                const SizedBox(width: 6),
                _VerifiedBadge(),
              ],
            ],
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              username,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (universityInfo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              universityInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _StatsRow(local: local),
        ],
      ),
    );
  }

}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: AppColors.white, size: 14),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable avatar widget (tappable → fullscreen)
// ---------------------------------------------------------------------------

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({
    this.user,
    required this.letter,
    this.radius = 40,
  });

  final User? user;
  final String letter;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;

    Widget avatar;
    if (hasAvatar) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user!.avatarUrl!),
        backgroundColor: AppColors.primaryBlue,
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryBlue,
        child: Text(
          letter,
          style: TextStyle(
            color: AppColors.white,
            fontSize: radius * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullscreen(context, user, hasAvatar, letter),
      child: Stack(
        children: [
          avatar,
          if (user?.isPremium ?? false)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.48,
                height: radius * 0.48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Icon(
                  Icons.check,
                  color: AppColors.white,
                  size: radius * 0.26,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullscreen(
    BuildContext context,
    User? user,
    bool hasAvatar,
    String initials,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            Center(
              child: hasAvatar
                  ? ClipOval(
                      child: Image.network(
                        user!.avatarUrl!,
                        width: 260,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    )
                  : CircleAvatar(
                      radius: 130,
                      backgroundColor: AppColors.primaryBlue,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.local});

  final LocalProfile local;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          emoji: '⭐',
          value: _format(local.stars),
          label: 'Stars',
        ),
        _Divider(),
        _StatItem(
          emoji: '👥',
          value: _format(local.peopleCount),
          label: 'Named',
        ),
      ],
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 1,
      color: AppColors.border,
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit profile'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Share Hidavo'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.invite),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('How to use'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.howToUse),
          ),
        ],
      ),
    );
  }
}
