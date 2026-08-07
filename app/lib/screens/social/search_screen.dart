import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../models/user.dart';
import '../../widgets/common/user_avatar.dart';

// ── Search provider (local mock — replace with real API call) ─────────────────

/// Simple result model for search results
class SearchUserResult {
  final String id;
  final String name;
  final String? username;
  final int grade;
  final String? gradeClass;
  final String? schoolName;
  final String? avatarUrl;
  bool isFriend;
  bool requestSent;

  SearchUserResult({
    required this.id,
    required this.name,
    this.username,
    required this.grade,
    this.gradeClass,
    this.schoolName,
    this.avatarUrl,
    this.isFriend = false,
    this.requestSent = false,
  });

  String get displayGrade =>
      gradeClass != null ? '$grade$gradeClass' : '$grade класс';
}

// Mock data — replace with Riverpod + API in production
final _mockUsers = [
  SearchUserResult(
    id: '1',
    name: 'Анна Петрова',
    username: 'anna_p',
    grade: 10,
    gradeClass: 'А',
    schoolName: 'Школа №5',
  ),
  SearchUserResult(
    id: '2',
    name: 'Дмитрий Смирнов',
    username: 'dima_s',
    grade: 11,
    gradeClass: 'Б',
    schoolName: 'Гимназия №3',
  ),
  SearchUserResult(
    id: '3',
    name: 'Мария Иванова',
    username: 'masha_i',
    grade: 9,
    schoolName: 'Лицей №1',
  ),
  SearchUserResult(
    id: '4',
    name: 'Алексей Козлов',
    username: 'alex_k',
    grade: 10,
    gradeClass: 'В',
    schoolName: 'Школа №7',
  ),
  SearchUserResult(
    id: '5',
    name: 'Екатерина Новикова',
    username: 'katya_n',
    grade: 11,
    schoolName: 'Школа №2',
  ),
  SearchUserResult(
    id: '6',
    name: 'Сергей Волков',
    username: 'sergey_v',
    grade: 10,
    gradeClass: 'А',
    schoolName: 'Школа №5',
  ),
  SearchUserResult(
    id: '7',
    name: 'Ольга Морозова',
    username: 'olga_m',
    grade: 9,
    gradeClass: 'Б',
    schoolName: 'Школа №5',
  ),
  SearchUserResult(
    id: '8',
    name: 'Николай Федоров',
    username: 'kolya_f',
    grade: 8,
    schoolName: 'Школа №12',
  ),
  SearchUserResult(
    id: '9',
    name: 'Татьяна Лебедева',
    username: 'tanya_l',
    grade: 11,
    gradeClass: 'А',
    schoolName: 'Лицей №2',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  String _query = '';
  bool _isLoading = false;
  List<SearchUserResult> _results = [];
  List<SearchUserResult> _localUsers = [];

  // Recent searches (persisted locally in real app)
  final List<String> _recentSearches = [
    'Анна',
    'Школа №5',
    'anna_p',
  ];

  @override
  void initState() {
    super.initState();
    _localUsers = List.from(_mockUsers);
    _controller.addListener(_onTextChanged);
    // Auto-focus the search bar when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (text.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _isLoading = false;
      });
      return;
    }

    if (text.length < 2) {
      setState(() {
        _query = text;
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = text;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(text);
    });
  }

  Future<void> _performSearch(String q) async {
    // Simulate network delay — replace with actual API call
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final lq = q.toLowerCase();
    final results = _localUsers.where((u) {
      return u.name.toLowerCase().contains(lq) ||
          (u.username?.toLowerCase().contains(lq) ?? false) ||
          (u.schoolName?.toLowerCase().contains(lq) ?? false);
    }).toList();

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _query = '';
      _results = [];
      _isLoading = false;
    });
    _focusNode.requestFocus();
  }

  void _addRecentSearch(String term) {
    if (!_recentSearches.contains(term)) {
      setState(() {
        _recentSearches.insert(0, term);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }
  }

  void _onRecentTap(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _onTextChanged();
  }

  void _removeRecent(String term) {
    setState(() => _recentSearches.remove(term));
  }

  void _sendFriendRequest(SearchUserResult user) {
    setState(() => user.requestSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Запрос отправлен ${user.name}'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
    _addRecentSearch(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Поиск',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) _addRecentSearch(v.trim());
        },
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Поиск по имени или @логину...',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textHint,
            size: 22,
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textHint,
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return _buildEmptyQuery();
    }
    if (_query.length < 2) {
      return _buildTooShort();
    }
    if (_isLoading) {
      return _buildSkeleton();
    }
    if (_results.isEmpty) {
      return _buildNoResults();
    }
    return _buildResults();
  }

  Widget _buildEmptyQuery() {
    if (_recentSearches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'Найдите одноклассников',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Введите имя или @логин',
              style: TextStyle(fontSize: 14, color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Недавние поиски',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
                letterSpacing: 0.8,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _recentSearches.clear()),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Очистить',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentSearches.map(
          (term) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.history,
              color: AppColors.textHint,
              size: 20,
            ),
            title: Text(
              term,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textHint,
              onPressed: () => _removeRecent(term),
            ),
            onTap: () => _onRecentTap(term),
          ),
        ),
      ],
    );
  }

  Widget _buildTooShort() {
    return const Center(
      child: Text(
        'Введите минимум 2 символа',
        style: TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_search,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'Пользователи не найдены',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нет результатов для "$_query"',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Новый поиск'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UserCard(
        user: _results[i],
        onAddFriend: () => _sendFriendRequest(_results[i]),
        onTap: () => context.push('/profile/${_results[i].id}'),
      ),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final SearchUserResult user;
  final VoidCallback onAddFriend;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onAddFriend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: user.avatarUrl,
              name: user.name,
              size: AvatarSize.medium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (user.username != null) ...[
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                      Text(
                        user.displayGrade,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (user.schoolName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.schoolName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _AddFriendButton(
              isFriend: user.isFriend,
              requestSent: user.requestSent,
              onTap: user.isFriend || user.requestSent ? null : onAddFriend,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  final bool isFriend;
  final bool requestSent;
  final VoidCallback? onTap;

  const _AddFriendButton({
    required this.isFriend,
    required this.requestSent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Друг',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      );
    }

    if (requestSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Отправлено',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Добавить',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 30,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
