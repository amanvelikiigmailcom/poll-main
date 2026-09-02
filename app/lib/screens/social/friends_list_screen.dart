import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/friend.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

class _FriendsListState {
  const _FriendsListState({
    required this.friends,
    this.query = '',
    this.isLoading = false,
  });

  final List<FriendUser> friends;
  final String query;
  final bool isLoading;

  List<FriendUser> get filtered {
    if (query.isEmpty) return friends;
    final q = query.toLowerCase();
    return friends.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  _FriendsListState copyWith({
    List<FriendUser>? friends,
    String? query,
    bool? isLoading,
  }) {
    return _FriendsListState(
      friends: friends ?? this.friends,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class _FriendsListNotifier extends StateNotifier<_FriendsListState> {
  _FriendsListNotifier() : super(_FriendsListState(friends: _kDemoFriends));

  void setQuery(String q) => state = state.copyWith(query: q);

  void removeFriend(String id) {
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != id).toList(),
    );
  }

  static final _kDemoFriends = [
    const FriendUser(
      id: '1',
      name: 'Анна Петрова',
      grade: 10,
      schoolName: 'Школа №5',
    ),
    const FriendUser(
      id: '2',
      name: 'Дмитрий Смирнов',
      grade: 11,
      schoolName: 'Гимназия №3',
    ),
    const FriendUser(
      id: '3',
      name: 'Мария Иванова',
      grade: 9,
      schoolName: 'Лицей №1',
    ),
    const FriendUser(
      id: '4',
      name: 'Алексей Козлов',
      grade: 10,
      schoolName: 'Школа №7',
    ),
    const FriendUser(
      id: '5',
      name: 'Екатерина Новикова',
      grade: 11,
      schoolName: 'Школа №2',
    ),
    const FriendUser(
      id: '6',
      name: 'Тимур Сейткали',
      grade: 9,
      schoolName: 'Назарбаевская школа',
    ),
  ];
}

final friendsListProvider =
    StateNotifierProvider<_FriendsListNotifier, _FriendsListState>(
  (_) => _FriendsListNotifier(),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _avatarColorFromName(String name) {
  const colors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFF96CEB4),
    Color(0xFFFECA57),
    Color(0xFFFF9FF3),
    Color(0xFF54A0FF),
    Color(0xFF5F27CD),
  ];
  return colors[name.hashCode.abs() % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '??';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() =>
      _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsListProvider);
    final notifier = ref.read(friendsListProvider.notifier);
    final filtered = state.filtered;

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
        title: Row(
          children: [
            const Text(
              'Мои друзья',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.friends.length}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.white,
            padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: notifier.setQuery,
              decoration: InputDecoration(
                hintText: 'Поиск друзей...',
                hintStyle: const TextStyle(
                    color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textHint),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textHint, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          notifier.setQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // List
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(
                    isSearching: state.query.isNotEmpty,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _FriendCard(
                      friend: filtered[i],
                      onTap: () => context
                          .push('/profile/${filtered[i].id}'),
                      onRemove: () =>
                          _confirmRemove(context, filtered[i], notifier),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    FriendUser friend,
    _FriendsListNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить из друзей?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Вы уверены, что хотите удалить ${friend.name} из друзей?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.removeFriend(friend.id);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friend card
// ---------------------------------------------------------------------------

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.onTap,
    required this.onRemove,
  });

  final FriendUser friend;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('friend_${friend.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_remove, color: AppColors.white),
            SizedBox(height: 4),
            Text(
              'Удалить',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Удалить из друзей?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
                'Вы уверены, что хотите удалить ${friend.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(context);
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: AppColors.accentRed),
                ),
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _showBottomSheet(context),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColorFromName(friend.name),
                backgroundImage: friend.avatarUrl != null
                    ? NetworkImage(friend.avatarUrl!)
                    : null,
                child: friend.avatarUrl == null
                    ? Text(
                        _initials(friend.name),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${friend.grade} класс · ${friend.schoolName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Online dot
              if (friend.isOnline)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              // Remove button
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Удалить из друзей',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: AppColors.primaryBlue),
              title: const Text('Открыть профиль'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/${friend.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: AppColors.accentRed),
              title: const Text(
                'Удалить из друзей',
                style: TextStyle(color: AppColors.accentRed),
              ),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.group_outlined,
            size: 64,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'Ничего не найдено' : 'Нет друзей',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Попробуйте другой запрос'
                : 'Приглашайте одноклассников\nи добавляйте их в друзья',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
