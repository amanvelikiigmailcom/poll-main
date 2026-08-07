import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _background = Color(0xFFF8F8F8);

class _HiddenUser {
  final String id;
  final String name;
  final String initials;
  final Color avatarColor;

  const _HiddenUser({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
  });
}

final _mockHiddenUsers = [
  const _HiddenUser(
    id: '1',
    name: 'Ольга Петрова',
    initials: 'ОП',
    avatarColor: Color(0xFFAB47BC),
  ),
  const _HiddenUser(
    id: '2',
    name: 'Сергей Новиков',
    initials: 'СН',
    avatarColor: Color(0xFF42A5F5),
  ),
];

class HiddenUsersScreen extends ConsumerStatefulWidget {
  const HiddenUsersScreen({super.key});

  @override
  ConsumerState<HiddenUsersScreen> createState() => _HiddenUsersScreenState();
}

class _HiddenUsersScreenState extends ConsumerState<HiddenUsersScreen> {
  late List<_HiddenUser> _hiddenUsers;

  @override
  void initState() {
    super.initState();
    _hiddenUsers = List.from(_mockHiddenUsers);
  }

  void _show(_HiddenUser user) {
    setState(() {
      _hiddenUsers.removeWhere((u) => u.id == user.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Пользователь показан'),
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
          'Скрытые',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _hiddenUsers.isEmpty
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
            Icons.visibility_off_outlined,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет скрытых пользователей',
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
      itemCount: _hiddenUsers.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final user = _hiddenUsers[index];
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
                onPressed: () => _show(user),
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
                  'Показать',
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
