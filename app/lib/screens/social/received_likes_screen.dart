import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

/// Received votes only; the API never includes the voter's identity.
///
/// Cards show only what the server returns: the question and the vote time.
/// Newest votes come first; sections group them into Today / Yesterday /
/// Earlier by local calendar day.
class ReceivedLikesScreen extends ConsumerStatefulWidget {
  const ReceivedLikesScreen({super.key});
  @override
  ConsumerState<ReceivedLikesScreen> createState() =>
      _ReceivedLikesScreenState();
}

/// Local calendar-day section for a vote timestamp.
String likeSection(DateTime occurred, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(occurred.year, occurred.month, occurred.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return 'Earlier';
}

/// Short relative label for a vote timestamp ("Just now", "5m ago").
String likeTimeAgo(DateTime occurred, DateTime now) {
  final age = now.difference(occurred);
  if (age.isNegative || age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 24 && likeSection(occurred, now) == 'Today') {
    return '${age.inHours}h ago';
  }
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(occurred.year, occurred.month, occurred.day)).inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';
  return '${occurred.month}/${occurred.day}/${occurred.year}';
}

class _ReceivedLikesScreenState extends ConsumerState<ReceivedLikesScreen> {
  late final StorageService _storage;
  final _items = <Map<String, dynamic>>[];
  String? _cursor, _error;
  int? _count;
  int _generation = 0;
  bool _loading = true, _guest = false;
  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider)..addListener(_changed);
    _load();
  }

  void _changed() => _load();
  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _cursor = null;
        _count = null;
      }
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
      final data = await ref
          .read(socialServiceProvider)
          .request(
            '/likes${more && _cursor != null ? '?cursor=${Uri.encodeComponent(_cursor!)}' : ''}',
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = data['votesReceived'] as int?;
        _items.addAll(
          (data['items'] as List? ?? []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        _cursor = data['nextCursor'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Couldn’t load Likes. Try again.';
          _loading = false;
        });
      }
    }
  }

  DateTime? _occurred(Map<String, dynamic> item) {
    final value = item['occurredAt'];
    final parsed = DateTime.tryParse(value is String ? value : '');
    return parsed?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sections = <String>[];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final section = likeSection(
        _occurred(item) ?? DateTime.fromMillisecondsSinceEpoch(0),
        now,
      );
      if (!grouped.containsKey(section)) {
        sections.add(section);
        grouped[section] = [];
      }
      grouped[section]!.add(item);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderCard(
                  count: _count,
                  canPop: ModalRoute.of(context)?.canPop ?? false,
                ),
              ),
              if (_loading && _items.isEmpty)
                const SliverToBoxAdapter(child: _SkeletonList())
              else if (_guest)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CenteredState(
                    icon: Icons.lock_outline,
                    title: 'Sign in to see your Likes.',
                    hint: 'Likes appear after you sign in.',
                  ),
                )
              else if (_error != null && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CenteredState(
                    icon: Icons.cloud_off_outlined,
                    title: _error!,
                    hint: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => _load(),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _count == 0
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: _LikesEmptyCard(),
                        )
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No available Likes to show.'),
                          ),
                        ),
                )
              else ...[
                for (final section in sections) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(title: section),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _LikeCard(
                          item: grouped[section]![index],
                          occurred: _occurred(grouped[section]![index]),
                          now: now,
                        ),
                        childCount: grouped[section]!.length,
                      ),
                    ),
                  ),
                ],
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_cursor != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: TextButton(
                        onPressed: () => _load(more: true),
                        child: const Text('Load more'),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.count, required this.canPop});

  final int? count;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E6C), Color(0xFF2D4BA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2E6C).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'Close',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              const Expanded(
                child: Text(
                  'Likes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (count != null && count != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: $count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Find out who picked you in votes',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A2E6C),
        ),
      ),
    );
  }
}

class _LikeCard extends StatelessWidget {
  const _LikeCard({required this.item, required this.occurred, required this.now});

  final Map<String, dynamic> item;
  final DateTime? occurred;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.likesResult, extra: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: AppColors.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Someone picked you',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['question'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    occurred == null ? '' : likeTimeAgo(occurred!, now),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 76,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Motivational empty state shown when the user has no received Likes yet.
class _LikesEmptyCard extends StatelessWidget {
  const _LikesEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Your future likes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CardBadgeIcon(icon: Icons.star),
              SizedBox(width: 12),
              _CardBadgeIcon(icon: Icons.favorite),
              SizedBox(width: 12),
              _CardBadgeIcon(icon: Icons.auto_awesome),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'EMPTY FOR NOW',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'When someone picks you in a vote, all your likes will appear '
            'here. Want more votes? Play more polls.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlueDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Go to polls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBadgeIcon extends StatelessWidget {
  const _CardBadgeIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlueDark,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
