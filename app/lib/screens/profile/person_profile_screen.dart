import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/person_profile.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../social/social_screen.dart';

/// The single other-person destination for IDs and authenticated handle links.
class PersonProfileScreen extends ConsumerStatefulWidget {
  const PersonProfileScreen({super.key, this.userId, this.username})
    : assert(userId != null || username != null);
  final String? userId, username;
  @override
  ConsumerState<PersonProfileScreen> createState() =>
      _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen>
    with WidgetsBindingObserver {
  late final StorageService _storage;
  final _scroll = ScrollController();
  PersonProfile? _profile;
  PersonNominations? _stats;
  final _items = <ProfileNomination>[];
  String? _error, _statsError, _cursor;
  bool _loading = true, _statsLoading = false, _busy = false, _guest = false;
  bool _emittingChange = false;
  bool _saving = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider)..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_nearEnd);
    unawaited(_load());
  }

  void _changed() => unawaited(_load());
  void _nearEnd() {
    if (_scroll.position.extentAfter < 300 &&
        _cursor != null &&
        !_statsLoading &&
        _statsError == null &&
        !_busy) {
      unawaited(_loadStats(_generation, more: true));
    }
  }

  @override
  void didUpdateWidget(covariant PersonProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.username != widget.username) {
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _storage.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _profile = null;
      _stats = null;
      _items.clear();
      _error = _statsError = _cursor = null;
      _loading = true;
      _statsLoading = _busy = false;
      _saving = false;
    });
    try {
      final token = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (token?.isNotEmpty != true) {
        setState(() {
          _guest = true;
          _loading = false;
        });
        return;
      }
      setState(() => _guest = false);
      final service = ref.read(socialServiceProvider);
      final data = widget.username != null
          ? await service.request(
              '/handles/${Uri.encodeComponent(widget.username!)}',
            )
          : await service.profile(widget.userId!);
      if (!mounted || generation != _generation) return;
      if (data['self'] == true) {
        context.go(AppRoutes.profile);
        return;
      }
      setState(() {
        _profile = PersonProfile.fromJson(data);
        _loading = false;
      });
      await _loadStats(generation);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is ApiException && error.statusCode == 404
            ? 'Profile unavailable.'
            : 'Couldn’t load profile. Try again.';
      });
    }
  }

  Future<void> _loadStats(int generation, {bool more = false}) async {
    final person = _profile;
    if (person == null || generation != _generation || _statsLoading) return;
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final data = await ref
          .read(socialServiceProvider)
          .nominations(person.id, cursor: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _stats = data;
        if (!more) _items.clear();
        final ids = _items.map((item) => item.questionId).toSet();
        _items.addAll(data.items.where((item) => ids.add(item.questionId)));
        _cursor = data.nextCursor;
        _statsLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (error is ApiException && error.statusCode == 404) {
        // A previous backend may not have this additive route. Revalidate the
        // existing profile route before interpreting a statistics 404 as a block.
        try {
          final current = await ref
              .read(socialServiceProvider)
              .profile(person.id);
          if (!mounted || generation != _generation) return;
          setState(() => _profile = PersonProfile.fromJson(current));
        } catch (profileError) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _profile = null;
            _stats = null;
            _items.clear();
            _cursor = null;
            _statsLoading = false;
            _error =
                profileError is ApiException && profileError.statusCode == 404
                ? 'Profile unavailable.'
                : 'Couldn’t load profile. Try again.';
          });
          return;
        }
      }
      setState(() {
        _statsLoading = false;
        // Never mix pages from different aggregate revisions/campuses.
        if (error is ApiException && [400, 409].contains(error.statusCode)) {
          _stats = null;
          _items.clear();
          _cursor = null;
        }
        _statsError = 'Couldn’t load profile statistics. Try again.';
      });
    }
  }

  Future<bool> _confirm(String action) async {
    final title = switch (action) {
      'remove' => 'Remove friend?',
      'block' => 'Block account?',
      'report' => 'Report account?',
      _ => 'Cancel friend request?',
    };
    final description = switch (action) {
      'remove' => 'You will both be removed from each other’s friends list.',
      'block' =>
        'You won’t see each other’s profiles or appear in each other’s search. Any friendship or pending request will be removed.',
      'report' =>
        'Send a safety report about this account to Flyprox? You can also block this account.',
      _ => 'Your sent request will be withdrawn.',
    };
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(switch (action) {
                  'remove' => 'Remove',
                  'block' => 'Block',
                  'report' => 'Send report',
                  _ => 'Withdraw request',
                }),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _action(String action) async {
    if (_busy || _profile == null) return;
    final generation = _generation;
    final person = _profile!;
    setState(() => _busy = true);
    try {
      if (['remove', 'block', 'report', 'cancel'].contains(action) &&
          !await _confirm(action)) {
        return;
      }
      if (!mounted || generation != _generation) return;
      setState(() => _saving = true);
      await ref.read(socialServiceProvider).act(person.id, action);
      if (!mounted || generation != _generation) return;
      ref.invalidate(socialSummaryProvider);
      // Refresh every mounted list, not just whichever branch initiated this action.
      _emittingChange = true;
      ref.read(socialVisibilityRevisionProvider.notifier).changed();
      _emittingChange = false;
      if (action == 'block') {
        _showBlockedHint();
      } else {
        _toast(switch (action) {
          'request' => 'Friend request sent',
          'accept' => 'Friend request accepted',
          'decline' => 'Friend request declined',
          'cancel' => 'Friend request cancelled',
          'remove' => 'Friend removed',
          _ => 'Report received. You can also block this account.',
        });
      }
      if (action == 'block') {
        setState(() {
          _profile = null;
          _stats = null;
          _items.clear();
          _cursor = null;
          _statsLoading = false;
          _error = 'Profile unavailable.';
          _generation++;
        });
      } else if (action != 'report') {
        await _load();
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _toast(switch (action) {
        'request' => 'Couldn’t send friend request. Try again.',
        'remove' => 'Couldn’t remove friend. Try again.',
        'block' => 'Couldn’t block account. Try again.',
        'report' => 'Couldn’t send report. Try again later.',
        _ => 'Couldn’t update friend request. Try again.',
      });
    } finally {
      if (mounted && (generation == _generation || _profile == null)) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
    ref.listen(onboardingDetailsProvider, (_, _) => unawaited(_load()));
    ref.listen(socialVisibilityRevisionProvider, (_, _) {
      if (!_emittingChange) unawaited(_load());
    });
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (_loading) const _PersonSkeleton(),
              if (_guest && !_loading)
                _message(
                  'Sign in to view profiles.',
                  'Sign in',
                  () => context.push(AppRoutes.phone),
                ),
              if (_error != null)
                _message(
                  _error!,
                  _error == 'Profile unavailable.' ? null : 'Retry',
                  _load,
                ),
              if (_profile case final person?) ...[
                _header(person),
                const SizedBox(height: 24),
                Text(
                  _stats == null
                      ? 'Times picked'
                      : 'Times picked · ${_stats!.votesReceived}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Available quiz results from completed rounds, grouped by question. The people who made these picks aren’t identified here.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (_statsError != null)
                  _message(
                    _statsError!,
                    'Retry',
                    () => _loadStats(_generation, more: _cursor != null),
                  ),
                if (_stats != null &&
                    _items.isEmpty &&
                    !_statsLoading &&
                    _statsError == null)
                  _message('No available nominations to show.', null, () {}),
                for (final item in _items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: const ExcludeSemantics(
                        child: Text(
                          '☆',
                          style: TextStyle(
                            fontSize: 30,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      title: Text(
                        item.question,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Selected ${item.count} ${item.count == 1 ? 'time' : 'times'}',
                      ),
                    ),
                  ),
                if (_statsLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                if (_cursor != null && !_statsLoading && _statsError == null)
                  TextButton(
                    onPressed: () => _loadStats(_generation, more: true),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Load more'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PersonProfile person) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFEFF1FE),
            child: Text('🙂', style: TextStyle(fontSize: 52)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          person.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (person.displayName != '@${person.username}') ...[
          const SizedBox(height: 4),
          Text(
            '@${person.username}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
        if (person.campus?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            person.campus!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (person.graduationYear != null) ...[
          const SizedBox(height: 4),
          Text(
            'Class of ${person.graduationYear}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _stat('Friends', _stats?.friendsCount)),
            const SizedBox(width: 8),
            Expanded(child: _stat('Times picked', _stats?.votesReceived)),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              enabled: !_busy,
              onSelected: _action,
              itemBuilder: (_) => [
                if (person.relationship == 'outgoing')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel request'),
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
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Text('•••', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy || person.relationship == 'outgoing'
              ? null
              : () => _action(switch (person.relationship) {
                  'incoming' => 'accept',
                  'friends' => 'remove',
                  _ => 'request',
                }),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(switch (person.relationship) {
                  'incoming' => 'Accept request',
                  'friends' => 'Remove friend',
                  'outgoing' => 'Request sent',
                  _ => 'Add friend',
                }),
        ),
        if (person.relationship == 'incoming')
          TextButton(
            onPressed: _busy ? null : () => _action('decline'),
            child: const Text('Decline'),
          ),
      ],
    ),
  );

  Widget _stat(String label, int? value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF1FE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Text(
          value?.toString() ?? '—',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );

  Widget _message(String text, String? button, VoidCallback action) =>
      Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center),
            if (button != null)
              TextButton(onPressed: action, child: Text(button)),
          ],
        ),
      );
}

class _PersonSkeleton extends StatelessWidget {
  const _PersonSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading profile',
    child: Column(
      children: [
        for (final height in [340.0, 86.0, 86.0])
          Container(
            height: height,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.shimmerHighlight,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
      ],
    ),
  );
}
