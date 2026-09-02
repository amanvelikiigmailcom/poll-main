import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _FriendRequest {
  const _FriendRequest({
    required this.id,
    required this.name,
    required this.grade,
    required this.schoolName,
    this.avatarUrl,
    this.mutualFriends = 0,
    this.isAccepted = false,
  });

  final String id;
  final String name;
  final int grade;
  final String schoolName;
  final String? avatarUrl;
  final int mutualFriends;
  final bool isAccepted;

  _FriendRequest copyWith({bool? isAccepted}) {
    return _FriendRequest(
      id: id,
      name: name,
      grade: grade,
      schoolName: schoolName,
      avatarUrl: avatarUrl,
      mutualFriends: mutualFriends,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class _RequestsNotifier extends StateNotifier<List<_FriendRequest>> {
  _RequestsNotifier()
      : super(const [
          _FriendRequest(
            id: '1',
            name: 'Анна Петрова',
            grade: 10,
            schoolName: 'Школа №5',
            mutualFriends: 3,
          ),
          _FriendRequest(
            id: '2',
            name: 'Дмитрий Смирнов',
            grade: 11,
            schoolName: 'Гимназия №3',
            mutualFriends: 1,
          ),
          _FriendRequest(
            id: '3',
            name: 'Мария Иванова',
            grade: 9,
            schoolName: 'Лицей №1',
            mutualFriends: 0,
          ),
          _FriendRequest(
            id: '4',
            name: 'Алексей Козлов',
            grade: 10,
            schoolName: 'Школа №7',
            mutualFriends: 2,
          ),
          _FriendRequest(
            id: '5',
            name: 'Зарина Асанова',
            grade: 8,
            schoolName: 'Назарбаевская школа',
            mutualFriends: 5,
          ),
        ]);

  void accept(String id) {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isAccepted: true) else r,
    ];
    // Remove from list after short delay (handled by animated list)
  }

  void decline(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void removeAccepted(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  int get pendingCount => state.where((r) => !r.isAccepted).length;
}

final friendRequestsProvider =
    StateNotifierProvider<_RequestsNotifier, List<_FriendRequest>>(
  (_) => _RequestsNotifier(),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _avatarColor(String name) {
  const colors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFF96CEB4),
    Color(0xFFFECA57),
    Color(0xFFFF9FF3),
    Color(0xFF54A0FF),
    Color(0xFF5F27CD),
    Color(0xFFFF9F43),
  ];
  return colors[name.hashCode.abs() % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);
    final notifier = ref.read(friendRequestsProvider.notifier);

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
              'Запросы в друзья',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${requests.where((r) => !r.isAccepted).length}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: requests.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final req = requests[index];
                return _RequestCard(
                  request: req,
                  onAccept: () => notifier.accept(req.id),
                  onDecline: () => notifier.decline(req.id),
                  onRemoveAccepted: () =>
                      notifier.removeAccepted(req.id),
                  onTapProfile: () => context.push('/profile/${req.id}'),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request card
// ---------------------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onRemoveAccepted,
    required this.onTapProfile,
  });

  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemoveAccepted;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: request.isAccepted
          ? _AcceptedCard(
              key: ValueKey('accepted_${request.id}'),
              request: request,
              onDismiss: onRemoveAccepted,
            )
          : _PendingCard(
              key: ValueKey('pending_${request.id}'),
              request: request,
              onAccept: onAccept,
              onDecline: onDecline,
              onTapProfile: onTapProfile,
            ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onTapProfile,
  });

  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Top row: avatar + name + info
          Row(
            children: [
              GestureDetector(
                onTap: onTapProfile,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: _avatarColor(request.name),
                  backgroundImage: request.avatarUrl != null
                      ? NetworkImage(request.avatarUrl!)
                      : null,
                  child: request.avatarUrl == null
                      ? Text(
                          _initials(request.name),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onTapProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${request.grade} класс · ${request.schoolName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (request.mutualFriends > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Общих друзей: ${request.mutualFriends}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(
                        color: AppColors.border, width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Отклонить',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Принять',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcceptedCard extends StatelessWidget {
  const _AcceptedCard({
    super.key,
    required this.request,
    required this.onDismiss,
  });

  final _FriendRequest request;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _avatarColor(request.name),
            child: Text(
              _initials(request.name),
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Теперь вы друзья!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Вы друзья ✓',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close,
                color: AppColors.textHint, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_outlined,
              size: 44,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Нет запросов',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Когда кто-то захочет добавить вас в друзья — запрос появится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
