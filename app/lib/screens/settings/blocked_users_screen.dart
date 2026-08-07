import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _background = Color(0xFFF8F8F8);

class _BlockedUser {
  final String id;
  final String name;
  final String initials;
  final Color avatarColor;

  const _BlockedUser({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
  });
}

final _mockBlockedUsers = [
  const _BlockedUser(
    id: '1',
    name: 'Алексей Смирнов',
    initials: 'АС',
    avatarColor: Color(0xFF5C6BC0),
  ),
  const _BlockedUser(
    id: '2',
    name: 'Мария Иванова',
    initials: 'МИ',
    avatarColor: Color(0xFFEC407A),
  ),
  const _BlockedUser(
    id: '3',
    name: 'Дмитрий Козлов',
    initials: 'ДК',
    avatarColor: Color(0xFF26A69A),
  ),
];

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  late List<_BlockedUser> _blockedUsers;

  @override
  void initState() {
    super.initState();
    _blockedUsers = List.from(_mockBlockedUsers);
  }

  void _unblock(_BlockedUser user) {
    setState(() {
      _blockedUsers.removeWhere((u) => u.id == user.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Пользователь разблокирован'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Заблокированные',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _blockedUsers.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_outlined,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет заблокированных пользователей',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _blockedUsers.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: user.avatarColor,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => _unblock(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  side: const BorderSide(color: _primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Разблокировать',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
