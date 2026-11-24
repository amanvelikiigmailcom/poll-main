import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/social_identity.dart';

final profileIdentityProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final storage = ref.watch(storageServiceProvider);
      void changed() => ref.invalidateSelf();
      storage.addListener(changed);
      ref.onDispose(() => storage.removeListener(changed));
      if ((await storage.getToken())?.isNotEmpty != true) return null;
      return ref.watch(socialServiceProvider).request('/me');
    });

final profileFriendsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>?>((ref) async {
      // Mutations already invalidate summary; use that same revision for the preview.
      final summary = await ref.watch(socialSummaryProvider.future);
      if (summary == null) return null;
      final data = await ref.watch(socialServiceProvider).list('friends');
      return (data['users'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['relationship'] == 'friends')
          .take(5)
          .toList();
    });

class ProfileSocialSection extends ConsumerStatefulWidget {
  const ProfileSocialSection({super.key});
  @override
  ConsumerState<ProfileSocialSection> createState() =>
      _ProfileSocialSectionState();
}

class _ProfileSocialSectionState extends ConsumerState<ProfileSocialSection> {
  Timer? _timer;
  bool _copied = false;
  bool _copying = false;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    if (_copying) return;
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getToken();
    if (!mounted || token?.isNotEmpty != true) return;
    setState(() => _copying = true);
    try {
      // Re-read the canonical handle so renames cannot share a stale profile.
      final me = await ref.read(socialServiceProvider).request('/me');
      final handle = me['username'] as String? ?? '';
      if (!RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(handle)) {
        throw StateError('No username');
      }
      if (token != await storage.getToken() || !mounted) return;
      await Clipboard.setData(
        ClipboardData(text: 'https://api.flyprox.com/p/@$handle'),
      );
      if (token != await storage.getToken() || !mounted) return;
      setState(() => _copied = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile link copied')));
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      if (mounted && token == await storage.getToken()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t copy your profile. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(socialSummaryProvider);
    final identity = ref.watch(profileIdentityProvider);
    final friends = ref.watch(profileFriendsProvider);
    final username = identity.isLoading || identity.hasError
        ? ''
        : identity.asData?.value?['username'] as String? ?? '';
    ref.listen(profileIdentityProvider, (previous, next) {
      if (_copied &&
          (next.isLoading ||
              previous?.asData?.value?['username'] !=
                  next.asData?.value?['username'])) {
        _timer?.cancel();
        setState(() => _copied = false);
      }
    });
    String count(AsyncValue<Map<String, dynamic>?> data, String key) =>
        data.isLoading || data.hasError
        ? '—'
        : data.asData?.value?[key]?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat(
                'Friends',
                count(summary, 'friendsCount'),
                AppRoutes.friends,
              ),
              _stat(
                'Likes',
                count(identity, 'votesReceived'),
                AppRoutes.likesEmpty,
              ),
              _stat(
                'Requests',
                count(summary, 'incomingCount'),
                AppRoutes.friendRequests,
              ),
            ],
          ),
          if (summary.hasError || identity.hasError)
            TextButton(
              onPressed: () {
                ref.invalidate(socialSummaryProvider);
                ref.invalidate(profileIdentityProvider);
              },
              child: const Text('Couldn’t load profile stats. Retry'),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: username.isEmpty || _copying ? null : _share,
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: Text(_copied ? 'Copied' : 'Share profile'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Friends',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.friends),
                child: const Text('See all'),
              ),
            ],
          ),
          friends.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const ProfileSkeleton(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(profileFriendsProvider),
              child: const Text('Couldn’t load friends. Retry'),
            ),
            data: (users) => users == null
                ? const Text('Sign in to see your friends.')
                : users.isEmpty
                ? const Text('Your friends will appear here.')
                : Column(
                    children: [
                      for (final user in users)
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            leading: const CircleAvatar(child: Text('🙂')),
                            title: Text(socialDisplayName(user)),
                            subtitle: socialDisplayName(user).startsWith('@')
                                ? null
                                : Text('@${user['username']}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(
                              '/people/${Uri.encodeComponent(user['id'] as String)}',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String route) => SizedBox(
    width: 96,
    child: Material(
      color: const Color(0xFFEFF1FE),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (label == 'Likes') {
            context.go(route);
          } else {
            await context.push(route);
            if (!mounted) return;
            ref.invalidate(socialSummaryProvider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading profile',
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1FE),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      ],
    ),
  );
}
