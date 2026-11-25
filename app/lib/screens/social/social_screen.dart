import '../../services/support_email_service.dart';
import '../../widgets/common/support_email_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/social_identity.dart';

enum SocialPage { search, friends, blocked, hidden }

final socialVisibilityRevisionProvider =
    NotifierProvider<_VisibilityRevision, int>(_VisibilityRevision.new);

class _VisibilityRevision extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

/// Real server data only. Search/recommendations never expose a directory.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({
    super.key,
    required this.page,
    this.initialKind = 'friends',
    this.focusUserId,
  });
  final SocialPage page;
  final String initialKind;
  final String? focusUserId;
  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  late final StorageService _storage;
  Timer? _debounce;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _mutuals = [], _campus = [];
  int _mutualLimit = 5, _campusLimit = 5;
  late String _kind;
  String? _next;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _guest = false;
  bool _needsHandle = false;
  int _generation = 0;

  bool get _isSearch => widget.page == SocialPage.search;
  String _searchHandle(String input) =>
      input.trim().replaceFirst(RegExp(r'^@'), '');
  @override
  void initState() {
    super.initState();
    if (widget.page != SocialPage.blocked) {
      WidgetsBinding.instance.addObserver(this);
    }
    _kind = switch (widget.page) {
      SocialPage.blocked => 'blocked',
      SocialPage.hidden => 'hidden',
      _ => widget.initialKind,
    };
    _storage = ref.read(storageServiceProvider);
    _storage.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    _debounce?.cancel();
    _search.clear();
    _mutualLimit = _campusLimit = 5;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    if (widget.page != SocialPage.blocked) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _generation++;
    _debounce?.cancel();
    _storage.removeListener(_accountChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final query = _search.text.trim();
    setState(() {
      _error = null;
      _loading = true;
      if (!more) {
        _users = [];
        _next = null;
        if (_isSearch) {
          _mutuals = [];
          _campus = [];
        }
      }
    });
    try {
      final token = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (token == null || token.isEmpty) {
        setState(() {
          _guest = true;
          _loading = false;
        });
        return;
      }
      setState(() => _guest = false);
      if (_isSearch &&
          query.isNotEmpty &&
          !(query.startsWith('@')
              ? RegExp(r'^@[a-zA-Z0-9_]{2,32}$').hasMatch(query)
              : query.length >= 2 &&
                    query.length <= 80 &&
                    RegExp(
                      r"^[\p{L}\p{M}\p{N}_ .'-]+$",
                      unicode: true,
                    ).hasMatch(query))) {
        setState(() {
          _loading = false;
          _error = 'Enter 2–80 characters of a name, or a valid @username.';
        });
        return;
      }
      final service = ref.read(socialServiceProvider);
      if (_isSearch) {
        final me = await service.request('/me');
        if (!mounted || generation != _generation) return;
        setState(() => _needsHandle = me['username'] == null);
      }
      if (_isSearch && query.isEmpty) {
        Map<String, dynamic> data;
        try {
          data = await service.suggestions();
        } on ApiException catch (error) {
          if (error.statusCode != 404) rethrow;
          // The app can be updated before the recommendations endpoint.
          data = {};
        }
        if (!mounted || generation != _generation) return;
        List<Map<String, dynamic>> cards(String key) =>
            (data[key] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .take(100)
                .toList();
        setState(() {
          _mutuals = cards('friendsOfFriends');
          _campus = cards('campus');
          _loading = false;
        });
        return;
      }
      final data = _isSearch
          ? await service.search(query, cursor: more ? _next : null)
          : await service.list(_kind, cursor: more ? _next : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        final users = (data['users'] as List? ?? [])
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        _users = more
            ? {
                for (final card in [..._users, ...users]) card['id']: card,
              }.values.toList()
            : users;
        // Only reorder authorized rows. A push cannot inject a user into a list.
        final focused = _users
            .where((user) => user['id'] == widget.focusUserId)
            .toList();
        if (focused.isNotEmpty) {
          _users = [
            ...focused,
            ..._users.where((user) => user['id'] != widget.focusUserId),
          ];
        }
        _next = data['nextCursor'] as String?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Couldn’t load friends. Please try again.';
      });
    }
  }

  void _onQuery(String value) {
    if (!_isSearch) {
      setState(() {});
      return;
    }
    _debounce?.cancel();
    _generation++;
    setState(() {
      _users = [];
      _error = null;
      _loading = false;
    });
    if (value.trim().isEmpty) {
      unawaited(_load());
      return;
    }
    if (_searchHandle(value).length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _load());
  }

  Future<void> _action(Map<String, dynamic> user, String action) async {
    if (_busy) return;
    if (action == 'report') {
      await showSupportEmail(
        context,
        kind: SupportEmailKind.account,
        targetId: user['id'] as String,
        username: user['username'] as String?,
      );
      return;
    }
    final owner = await _storage.getToken();
    if (!mounted) return;
    if (['block', 'remove', 'unblock'].contains(action)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            '${action == 'remove'
                ? 'Remove friend'
                : action == 'block'
                ? 'Block account'
                : 'Unblock account'}?',
          ),
          content: Text(
            action == 'block'
                ? 'You won’t find each other in search or be able to send new requests or online votes to each other.'
                : action == 'unblock'
                ? 'You can find each other and send requests again unless they still block you. You’ll need a new request to become friends.'
                : 'You will both be removed from each other’s friends list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (owner != await _storage.getToken() || !mounted) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final service = ref.read(socialServiceProvider);
      await service.act(user['id'] as String, action);
      if (owner != await _storage.getToken() ||
          !mounted ||
          generation != _generation) {
        return;
      }
      ref.invalidate(socialSummaryProvider);
      if (action == 'hide' || action == 'show') {
        ref.read(socialVisibilityRevisionProvider.notifier).changed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'hide'
                  ? 'Suggestion hidden. Manage in Settings → Hidden suggestions.'
                  : 'This person can appear in suggestions again.',
            ),
            action: action == 'hide'
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () => _action(user, 'show'),
                  )
                : null,
          ),
        );
      } else {
        // Relationship changes also invalidate profiles and other mounted lists.
        ref.read(socialVisibilityRevisionProvider.notifier).changed();
        if (action == 'block') _showBlockedHint();
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Couldn’t save. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showBlockedHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Account blocked. Manage the list in Settings → Blocked users.',
        ),
        action: SnackBarAction(
          label: 'View list',
          onPressed: () {
            if (mounted) context.push(AppRoutes.blockedUsers);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.page != SocialPage.blocked) {
      ref.listen(onboardingDetailsProvider, (_, _) {
        _debounce?.cancel();
        unawaited(_load());
      });
    }
    ref.listen(socialVisibilityRevisionProvider, (_, _) {
      _debounce?.cancel();
      unawaited(_load());
    });
    final title = switch (widget.page) {
      SocialPage.search => 'Find your people',
      SocialPage.friends => 'Friends',
      SocialPage.blocked => 'Blocked accounts',
      SocialPage.hidden => 'Hidden suggestions',
    };
    final visible = _isSearch || _search.text.isEmpty
        ? _users
        : _users
              .where(
                (u) => '${socialDisplayName(u)} @${u['username']}'
                    .toLowerCase()
                    .contains(_search.text.trim().toLowerCase()),
              )
              .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: !_isSearch,
        actions: [
          if (widget.page == SocialPage.search)
            IconButton(
              tooltip: 'Friend requests',
              onPressed: () => context.push(AppRoutes.friendRequests),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_isSearch) ...[
              const Text(
                'Good friends. Good energy.',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find friends from your campus.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
            ],
            if (widget.page == SocialPage.friends) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    'friends': 'My friends',
                    'incoming': 'Received',
                    'outgoing': 'Sent',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _kind == entry.key,
                      onSelected: (_) {
                        setState(() {
                          _kind = entry.key;
                          _search.clear();
                        });
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (_isSearch || widget.page == SocialPage.friends) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _search,
                  onChanged: _onQuery,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    if (_isSearch) unawaited(_load());
                  },
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _isSearch
                        ? 'Search by name or @username'
                        : 'Search this list',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryBlueDark,
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _onQuery('');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (_isSearch)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Search first name, last name or username. Only people from your selected campus appear.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
            ],
            if (_isSearch && !_guest && _error == null && _needsHandle)
              _message(
                Icons.alternate_email_rounded,
                'Make your username yours',
                'Save a unique username so friends can find you and you can send requests.',
                button: 'Choose username',
                onTap: () async {
                  await context.push(AppRoutes.editProfile);
                  if (mounted) _load();
                },
              ),
            if (_guest)
              _message(
                Icons.lock_outline_rounded,
                'Friends start with a sign-in',
                'Sign in with your phone number to find friends and manage requests. You can keep playing as a guest.',
                button: 'Sign in',
                onTap: () => context.push(AppRoutes.phone),
              ),
            if (_error != null)
              _message(
                Icons.cloud_off_rounded,
                'Let’s try that again',
                _error!,
                button: 'Try again',
                onTap: () => _load(),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_guest && _error == null) ...[
              if (!_loading &&
                  visible.isEmpty &&
                  (!_isSearch || _search.text.isNotEmpty))
                _message(
                  widget.page == SocialPage.blocked
                      ? Icons.shield_outlined
                      : Icons.people_outline_rounded,
                  _isSearch
                      ? 'No match yet'
                      : _kind == 'friends'
                      ? 'Your circle starts here'
                      : _kind == 'blocked'
                      ? 'No blocked accounts'
                      : _kind == 'hidden'
                      ? 'No hidden suggestions'
                      : 'All caught up',
                  _isSearch
                      ? 'Try their name or @username. They must have selected the same campus.'
                      : _kind == 'friends'
                      ? 'Find someone you know and send your first request.'
                      : _kind == 'blocked'
                      ? 'Accounts you block will appear here.'
                      : _kind == 'hidden'
                      ? 'Hidden suggestions appear here. Show them again at any time.'
                      : 'Your friend requests will appear here.',
                  button: _kind == 'friends' && !_isSearch
                      ? 'Find friends'
                      : null,
                  onTap: () => context.go(AppRoutes.search),
                ),
              for (final user in visible) _userCard(user),
              if (_next != null && !_loading)
                OutlinedButton(
                  onPressed: () => _load(more: true),
                  child: const Text('Load more'),
                ),
            ],
            if (_isSearch &&
                !_guest &&
                !_loading &&
                _error == null &&
                _search.text.trim().isEmpty) ...[
              const SizedBox(height: 14),
              if (_mutuals.isNotEmpty)
                _recommendations(
                  'Friends of friends',
                  Icons.people_alt_outlined,
                  _mutuals,
                  _mutualLimit,
                  'No mutual connections yet. Search for someone you know.',
                  () => setState(() => _mutualLimit += 20),
                ),
              if (_mutuals.isNotEmpty) const SizedBox(height: 14),
              _recommendations(
                'From your campus',
                Icons.school_outlined,
                _campus,
                _campusLimit,
                'No more people from your campus yet.',
                () => setState(() => _campusLimit += 20),
              ),
              if (_mutuals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Friends of friends appear once your friends have other connections on your campus.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recommendations(
    String title,
    IconData icon,
    List<Map<String, dynamic>> cards,
    int limit,
    String empty,
    VoidCallback more,
  ) {
    final users = cards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF1FE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryBlueDark, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (users.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF1FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${users.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlueDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: .7)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_search_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    empty,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final user in users.take(limit))
          _userCard(user, recommendation: true),
        if (users.length > limit)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: more,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlueDark,
                side: const BorderSide(color: AppColors.primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('See more (${users.length - limit})'),
            ),
          ),
      ],
    );
  }

  Widget _userCard(Map<String, dynamic> user, {bool recommendation = false}) {
    final relationship = user['relationship'] as String? ?? 'none';
    Widget button(String label, String action, {bool primary = true}) =>
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 4),
          child: primary
              ? FilledButton(
                  onPressed: _busy ? null : () => _action(user, action),
                  child: Text(label),
                )
              : TextButton(
                  onPressed: _busy ? null : () => _action(user, action),
                  child: Text(label),
                ),
        );
    return Container(
      key: recommendation ? ValueKey('suggestion-${user['id']}') : null,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFEFF1FE),
                child: Text('🙂', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: relationship == 'blocked'
                      ? null
                      : () => context.push(
                          '/people/${Uri.encodeComponent(user['id'] as String)}',
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                socialDisplayName(user),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (socialDisplayName(user) != '@${user['username']}')
                          Text(
                            '@${user['username']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (user['graduationYear'] case final int year)
                          Text(
                            'Graduating in $year',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        if (recommendation)
                          if (user['mutualCount'] case final int count)
                            Text(
                              '$count mutual ${count == 1 ? 'friend' : 'friends'}',
                              style: const TextStyle(
                                color: AppColors.primaryBlueDark,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              if (relationship != 'blocked' && widget.page != SocialPage.hidden)
                PopupMenuButton<String>(
                  tooltip: 'Account actions',
                  onSelected: (value) => _action(user, value),
                  itemBuilder: (_) => [
                    if (recommendation)
                      const PopupMenuItem(
                        value: 'hide',
                        child: Text('Hide suggestion'),
                      ),
                    if (relationship == 'friends')
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove friend'),
                      ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Text('Block account'),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Report account'),
                    ),
                  ],
                ),
            ],
          ),
          Wrap(
            children: [
              if (widget.page == SocialPage.hidden)
                button('Show again', 'show'),
              if (widget.page != SocialPage.hidden && relationship == 'none')
                button('Add friend', 'request'),
              if (widget.page != SocialPage.hidden &&
                  relationship == 'incoming') ...[
                button('Accept', 'accept'),
                button('Decline', 'decline', primary: false),
              ],
              if (widget.page != SocialPage.hidden &&
                  relationship == 'outgoing') ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Text(
                    'Request sent',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                button('Cancel', 'cancel', primary: false),
              ],
              if (widget.page != SocialPage.hidden && relationship == 'friends')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: AppColors.primaryBlueDark,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Friends',
                        style: TextStyle(
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (relationship == 'blocked')
                button('Unblock', 'unblock', primary: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String body, {
    String? button,
    VoidCallback? onTap,
  }) => Container(
    padding: const EdgeInsets.all(24),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFEFF1FE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryBlueDark, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        if (button != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onTap, child: Text(button)),
        ],
      ],
    ),
  );
}
