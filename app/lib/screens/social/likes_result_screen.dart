import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/received_vote.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/vote_result_content.dart';
import '../../widgets/common/voter_reveal_card.dart';
import 'received_likes_screen.dart';

class LikesResultScreen extends ConsumerStatefulWidget {
  const LikesResultScreen({super.key, this.like});
  final Map<String, dynamic>? like;
  @override
  ConsumerState<LikesResultScreen> createState() => _LikesResultScreenState();
}

class _LikesResultScreenState extends ConsumerState<LikesResultScreen> {
  late final StorageService _storage;
  bool _invalidated = false;
  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider)..addListener(_accountChanged);
  }

  void _accountChanged() {
    if (mounted) setState(() => _invalidated = true);
  }

  @override
  void dispose() {
    _storage.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final like = _invalidated ? null : widget.like;
    final occurred = DateTime.tryParse(
      like?['occurredAt'] is String ? like!['occurredAt'] as String : '',
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quiz result')),
      body: like == null
          ? const Center(child: Text('Like not found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (occurred != null) ...[
                    Text(
                      likeTimeAgo(occurred.toLocal(), DateTime.now()),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  VoteResultContent(vote: ReceivedVote.fromJson(like)),
                  const SizedBox(height: 20),
                  VoterRevealCard(
                    voteId: like['id'] as String?,
                    onShare:
                        like['id'] is String &&
                            (like['id'] as String).isNotEmpty
                        ? () => context.push(
                            AppRoutes.likesShare,
                            extra: like['id'],
                          )
                        : null,
                  ),
                ],
              ),
            ),
    );
  }
}
