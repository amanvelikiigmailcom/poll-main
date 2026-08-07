import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Providers for social counts (would be wired to real API in production)
// ---------------------------------------------------------------------------

final friendRequestCountProvider = StateProvider<int>((ref) => 5);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userNotifierProvider);
    final user = userState.user;
    final requestCount = ref.watch(friendRequestCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: () => ref.read(userNotifierProvider.notifier).fetchProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _ProfileHeaderCard(user: user),
                    const SizedBox(height: 12),
                    _FriendsPreviewSection(user: user),
                    const SizedBox(height: 12),
                    _ProfileMenuSection(
                      user: user,
                      requestCount: requestCount,
                    ),
                    const SizedBox(height: 32),
                  ],
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
  const _ProfileHeaderCard({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.fullName ?? 'Имя пользователя';
    final username = user?.username != null ? '@${user!.username}' : '';
    final schoolInfo = _buildSchoolInfo(user);
    final isPremium = user?.isPremium ?? false;

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Column(
        children: [
          _AvatarWidget(user: user, radius: 52),
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
          if (schoolInfo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              schoolInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _StatsRow(user: user),
        ],
      ),
    );
  }

  String _buildSchoolInfo(User? user) {
    if (user == null) return '';
    final parts = <String>[];
    if (user.schoolName != null && user.schoolName!.isNotEmpty) {
      parts.add(user.schoolName!);
    }
    parts.add(user.displayGrade);
    return parts.join(' · ');
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
  const _AvatarWidget({this.user, this.radius = 40});

  final User? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);
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
          initials,
          style: TextStyle(
            color: AppColors.white,
            fontSize: radius * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullscreen(context, user, hasAvatar, initials),
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

  String _initials(User? user) {
    if (user == null) return '??';
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return '$first$last'.toUpperCase();
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
  const _StatsRow({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          emoji: '⭐',
          value: _format(user?.starsCount ?? 0),
          label: 'Звёздочки',
        ),
        _Divider(),
        _StatItem(
          emoji: '👥',
          value: _format(user?.friendsCount ?? 0),
          label: 'Друзья',
        ),
        _Divider(),
        _StatItem(
          emoji: '❤️',
          value: _format(user?.votesReceived ?? 0),
          label: 'Голоса',
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

// ---------------------------------------------------------------------------
// Friends preview (horizontal scroll of 5 avatars)
// ---------------------------------------------------------------------------

// Lightweight friend preview data (real app would load from API)
class _FriendPreview {
  const _FriendPreview({
    required this.id,
    required this.initials,
    required this.name,
    this.avatarUrl,
  });
  final String id;
  final String initials;
  final String name;
  final String? avatarUrl;
}

const _kDemoFriends = [
  _FriendPreview(id: '1', initials: 'АИ', name: 'Айгерим'),
  _FriendPreview(id: '2', initials: 'ДА', name: 'Дамир'),
  _FriendPreview(id: '3', initials: 'СМ', name: 'Сабина'),
  _FriendPreview(id: '4', initials: 'НК', name: 'Нурлан'),
  _FriendPreview(id: '5', initials: 'АЖ', name: 'Азиза'),
];

class _FriendsPreviewSection extends StatelessWidget {
  const _FriendsPreviewSection({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Друзья',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.friends),
                  child: const Text(
                    'Все →',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: _kDemoFriends.isEmpty
                ? const Center(
                    child: Text(
                      'Нет друзей',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _kDemoFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _kDemoFriends[index];
                      return GestureDetector(
                        onTap: () => context.push('/profile/${friend.id}'),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    AppColors.primaryBlue.withOpacity(0.15),
                                child: Text(
                                  friend.initials,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                friend.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu section
// ---------------------------------------------------------------------------

class _ProfileMenuSection extends StatelessWidget {
  const _ProfileMenuSection({this.user, required this.requestCount});

  final User? user;
  final int requestCount;

  @override
  Widget build(BuildContext context) {
    final friendsCount = user?.friendsCount ?? 0;

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.collections_bookmark_outlined,
            label: 'Мои коллекции',
            onTap: () => context.push(AppRoutes.collection),
          ),
          const _ItemDivider(),
          _MenuItem(
            icon: Icons.group_outlined,
            label: 'Мои друзья',
            badge: friendsCount > 0 ? '$friendsCount' : null,
            badgeColor: AppColors.primaryBlue,
            onTap: () => context.push(AppRoutes.friends),
          ),
          const _ItemDivider(),
          _MenuItem(
            icon: Icons.person_add_outlined,
            label: 'Запросы в друзья',
            badge: requestCount > 0 ? '$requestCount' : null,
            badgeColor: AppColors.accentRed,
            onTap: () => context.push(AppRoutes.friendRequests),
          ),
          const _ItemDivider(),
          _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Редактировать профиль',
            onTap: () => context.push(AppRoutes.editProfile),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.badgeColor = AppColors.accentRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.divider,
      indent: 52,
    );
  }
}
