import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Friend state enum
// ---------------------------------------------------------------------------

enum _FriendRelation { none, pending, friends }

// ---------------------------------------------------------------------------
// Minimal "other user" model (real app would fetch from API)
// ---------------------------------------------------------------------------

class _OtherUser {
  const _OtherUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.grade,
    required this.schoolName,
    this.avatarUrl,
    this.starsCount = 0,
    this.friendsCount = 0,
    this.votesReceived = 0,
    this.isPremium = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final int grade;
  final String schoolName;
  final String? avatarUrl;
  final int starsCount;
  final int friendsCount;
  final int votesReceived;
  final bool isPremium;

  String get fullName => '$firstName $lastName'.trim();
  String get displayGrade => '$grade класс';
}

// ---------------------------------------------------------------------------
// Demo friend preview
// ---------------------------------------------------------------------------

class _FriendPreview {
  const _FriendPreview({
    required this.id,
    required this.initials,
    required this.name,
  });
  final String id;
  final String initials;
  final String name;
}

// ---------------------------------------------------------------------------
// Provider (per userId)
// ---------------------------------------------------------------------------

final _friendRelationProvider =
    StateProvider.family<_FriendRelation, String>((ref, userId) {
  return _FriendRelation.none;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileForPeopleScreen extends ConsumerWidget {
  const ProfileForPeopleScreen({super.key, required this.userId});

  final String userId;

  // Demo data – real app would fetch from API
  static final _kDemo = _OtherUser(
    id: '999',
    firstName: 'Айгерим',
    lastName: 'Нурсейт',
    username: 'aigerim_n',
    grade: 10,
    schoolName: 'Назарбаевская школа Астана',
    starsCount: 850,
    friendsCount: 22,
    votesReceived: 31,
    isPremium: true,
  );

  static const _kFriends = [
    _FriendPreview(id: 'a', initials: 'ДА', name: 'Дамир'),
    _FriendPreview(id: 'b', initials: 'МА', name: 'Маша'),
    _FriendPreview(id: 'c', initials: 'ТК', name: 'Тимур'),
    _FriendPreview(id: 'd', initials: 'СМ', name: 'Сабина'),
    _FriendPreview(id: 'e', initials: 'АЖ', name: 'Азиза'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = _kDemo; // Replace with async fetch in real app
    final relation = ref.watch(_friendRelationProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _OtherProfileHeader(user: user),
            const SizedBox(height: 12),
            _FriendActionCard(
              user: user,
              relation: relation,
              onTap: () => _handleFriendTap(ref, relation),
            ),
            const SizedBox(height: 12),
            _OtherFriendsPreview(friends: _kFriends, userId: userId),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _handleFriendTap(WidgetRef ref, _FriendRelation current) {
    final notifier = ref.read(_friendRelationProvider(userId).notifier);
    switch (current) {
      case _FriendRelation.none:
        notifier.state = _FriendRelation.pending;
        break;
      case _FriendRelation.pending:
        // Cancel request
        notifier.state = _FriendRelation.none;
        break;
      case _FriendRelation.friends:
        // Could show "remove friend" dialog; for now toggle back
        notifier.state = _FriendRelation.none;
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _OtherProfileHeader extends StatelessWidget {
  const _OtherProfileHeader({required this.user});

  final _OtherUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Column(
        children: [
          _OtherAvatarWidget(user: user),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (user.isPremium) ...[
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: AppColors.white, size: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '${user.schoolName} · ${user.displayGrade}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          _OtherStatsRow(user: user),
        ],
      ),
    );
  }
}

class _OtherAvatarWidget extends StatelessWidget {
  const _OtherAvatarWidget({required this.user});

  final _OtherUser user;

  @override
  Widget build(BuildContext context) {
    final initials = '${user.firstName[0]}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
        .toUpperCase();
    final hasAvatar =
        user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    Widget avatar;
    if (hasAvatar) {
      avatar = CircleAvatar(
        radius: 52,
        backgroundImage: NetworkImage(user.avatarUrl!),
        backgroundColor: AppColors.primaryBlue,
      );
    } else {
      avatar = CircleAvatar(
        radius: 52,
        backgroundColor: AppColors.primaryBlue,
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 26,
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
          if (user.isPremium)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child:
                    const Icon(Icons.check, color: AppColors.white, size: 13),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullscreen(
    BuildContext context,
    _OtherUser user,
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
                  color: Colors.transparent),
            ),
            Center(
              child: hasAvatar
                  ? ClipOval(
                      child: Image.network(
                        user.avatarUrl!,
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
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherStatsRow extends StatelessWidget {
  const _OtherStatsRow({required this.user});

  final _OtherUser user;

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(emoji: '⭐', value: _fmt(user.starsCount), label: 'Звёздочки'),
        Container(height: 44, width: 1, color: AppColors.border),
        _Stat(emoji: '👥', value: _fmt(user.friendsCount), label: 'Друзья'),
        Container(height: 44, width: 1, color: AppColors.border),
        _Stat(
            emoji: '❤️',
            value: _fmt(user.votesReceived),
            label: 'Голоса'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Friend action button
// ---------------------------------------------------------------------------

class _FriendActionCard extends StatelessWidget {
  const _FriendActionCard({
    required this.user,
    required this.relation,
    required this.onTap,
  });

  final _OtherUser user;
  final _FriendRelation relation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget button;

    switch (relation) {
      case _FriendRelation.none:
        button = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text(
              'Добавить в друзья',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        break;

      case _FriendRelation.pending:
        button = SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.hourglass_empty, size: 18),
            label: const Text(
              'Запрос отправлен',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side:
                  const BorderSide(color: AppColors.border, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        break;

      case _FriendRelation.friends:
        button = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.check, size: 18),
            label: const Text(
              'Вы друзья',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        break;
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: button,
    );
  }
}

// ---------------------------------------------------------------------------
// Friends preview
// ---------------------------------------------------------------------------

class _OtherFriendsPreview extends StatelessWidget {
  const _OtherFriendsPreview({
    required this.friends,
    required this.userId,
  });

  final List<_FriendPreview> friends;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Друзья',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final f = friends[index];
                return GestureDetector(
                  onTap: () => context.push('/profile/${f.id}'),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppColors.primaryBlue.withOpacity(0.15),
                          child: Text(
                            f.initials,
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          f.name,
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
