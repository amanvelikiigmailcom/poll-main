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
import '../../widgets/common/premium_badge.dart';

enum SocialPage { search, friends, blocked }

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
  });
  final SocialPage page;
  final String initialKind;
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
  final _hidden = <String>{};
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
    _kind = widget.page == SocialPage.blocked ? 'blocked' : widget.initialKind;
    _storage = ref.read(storageServiceProvider);
    _storage.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    _debounce?.cancel();
    _search.clear();
    _hidden.clear();
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
          !RegExp(r'^[a-zA-Z0-9_]{2,32}$').hasMatch(_searchHandle(query))) {
        setState(() {
          _loading = false;
          _error = 'Enter 2–32 username characters: A–Z, numbers or _.';
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
      await ref.read(socialServiceProvider).act(user['id'] as String, action);
      if (owner != await _storage.getToken() ||
          !mounted ||
          generation != _generation) {
        return;
      }
      ref.invalidate(socialSummaryProvider);
      if (action == 'report') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report received. You can also block this account.'),
          ),
        );
      } else {
        // Relationship changes also invalidate profiles and other mounted lists.
        ref.read(socialVisibilityRevisionProvider.notifier).changed();
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
    };
    final visible = _isSearch || _search.text.isEmpty
        ? _users
        : _users
              .where(
                (u) => (u['username'] as String).contains(
                  _search.text.trim().toLowerCase().replaceFirst('@', ''),
                ),
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
                'Know their username? Find them here.',
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
              TextField(
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
                      ? 'Search by @username'
                      : 'Search this list',
                  prefixIcon: const Icon(Icons.search_rounded),
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
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (_isSearch)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Enter at least 2 characters from the start of their username. Names and phone numbers aren’t searchable.',
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
                      : 'All caught up',
                  _isSearch
                      ? 'Check the username with your friend and try again.'
                      : _kind == 'friends'
                      ? 'Find someone you know and send your first request.'
                      : _kind == 'blocked'
                      ? 'Accounts you block will appear here.'
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
              _recommendations(
                'Friends of friends',
                _mutuals,
                _mutualLimit,
                'No mutual connections yet. Search for someone you know.',
                () => setState(() => _mutualLimit += 20),
              ),
              const SizedBox(height: 14),
              _recommendations(
                'From your campus',
                _campus,
                _campusLimit,
                'No more people from your campus yet.',
                () => setState(() => _campusLimit += 20),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recommendations(
    String title,
    List<Map<String, dynamic>> cards,
    int limit,
    String empty,
    VoidCallback more,
  ) {
    final users = cards.where((card) => !_hidden.contains(card['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (users.isEmpty)
          Text(empty, style: const TextStyle(color: AppColors.textSecondary)),
        for (final user in users.take(limit))
          _userCard(user, recommendation: true),
        if (users.length > limit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: more,
              child: Text('See more (${users.length - limit})'),
            ),
          ),
      ],
    );
  }

  Widget _userCard(Map<String, dynamic> user, {bool recommendation = false}) {
    final relationship = user['relationship'] as String? ?? 'none';
    final inlineActions =
        recommendation &&
        relationship == 'none' &&
        MediaQuery.sizeOf(context).width >= 390 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.2;
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
    Widget hide() => TextButton(
      onPressed: _busy
          ? null
          : () => setState(() => _hidden.add(user['id'] as String)),
      child: const Text('Hide'),
    );
    return Container(
      key: recommendation ? ValueKey('suggestion-${user['id']}') : null,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            PremiumBadge(
                              active: user['premiumBadge'] == true,
                              until: user['premiumBadgeUntil'] as String?,
                            ),
                          ],
                        ),
                        if (socialDisplayName(user) != '@${user['username']}')
                          Text(
                            '@${user['username']}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
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
              if (inlineActions) ...[hide(), button('Add', 'request')],
              if (!recommendation && relationship != 'blocked')
                PopupMenuButton<String>(
                  tooltip: 'Account actions',
                  onSelected: (value) => _action(user, value),
                  itemBuilder: (_) => [
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
          if (!inlineActions)
            Wrap(
              children: [
                if (recommendation) hide(),
                if (relationship == 'none')
                  button(recommendation ? 'Add' : 'Add friend', 'request'),
                if (relationship == 'incoming') ...[
                  button('Accept', 'accept'),
                  button('Decline', 'decline', primary: false),
                ],
                if (relationship == 'outgoing') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Text(
                      'Request sent',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  button('Cancel', 'cancel', primary: false),
                ],
                if (relationship == 'friends')
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
