import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';
import 'received_likes_screen.dart';
import '../../widgets/common/voter_reveal_card.dart';
import '../../models/received_vote.dart';
import '../../providers/service_providers.dart';
import '../../services/storage_service.dart';

/// Details of one received vote, opened from a Like card.
///
/// Matches the voting screen: light background, big question and a
/// two-column grid of participant cards. Names come from the server
/// snapshot only. Voter identity requires a separate backend-authorized reveal.
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
    final occurred = like == null
        ? null
        : DateTime.tryParse(
            like['occurredAt'] is String ? like['occurredAt'] as String : '',
          );
    final question = like?['question'] as String? ?? '';
    final timeLabel = occurred == null
        ? ''
        : likeTimeAgo(occurred.toLocal(), DateTime.now());
    final participants = _serverParticipants(like);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: like == null
            ? const Center(
                child: Text(
                  'Like not found.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Text(
                          'Vote details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          if (timeLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            publicVoterLabel(
                              like['voterGender'],
                              like['graduationYear'],
                            ),
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ParticipantsSection(server: participants),
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Participant rows frozen by the server at vote time, if any.
List<_Participant> _serverParticipants(Map<String, dynamic>? like) {
  final raw = like?['participants'];
  if (raw is! List) return const [];
  final result = <_Participant>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final name = entry['name'] is String
        ? (entry['name'] as String).trim()
        : '';
    if (name.isEmpty) continue;
    final year = entry['graduationYear'];
    result.add(
      _Participant(name: name, graduationYear: year is int ? year : null),
    );
  }
  return result;
}

class _Participant {
  const _Participant({required this.name, this.graduationYear});

  final String name;
  final int? graduationYear;
}

// ---------------------------------------------------------------------------
// Participants grid (server snapshot only)
// ---------------------------------------------------------------------------

/// Everyone who was in the vote, in the voting screen card style.
///
/// Missing historical snapshots show an empty state, never on-device guesses.
class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({required this.server});

  final List<_Participant> server;

  @override
  Widget build(BuildContext context) {
    final participants = server;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Everyone who was in this vote.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Participants are not available for this vote.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final participant in participants)
                    SizedBox(
                      width: cardWidth,
                      child: _ParticipantCard(
                        participant: participant,
                        isPick: false,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant, required this.isPick});

  final _Participant participant;
  final bool isPick;

  @override
  Widget build(BuildContext context) {
    final detail = participant.graduationYear == null
        ? ''
        : 'Class of ${participant.graduationYear}';
    return Container(
      decoration: BoxDecoration(
        color: isPick
            ? AppColors.primaryBlue.withValues(alpha: 0.09)
            : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPick ? AppColors.primaryBlue : AppColors.border,
          width: isPick ? 2.0 : 1.0,
        ),
        boxShadow: isPick
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: generateAvatarColor(participant.name),
                      child: Text(
                        getInitials(participant.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isPick)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  participant.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anonymous voter card
// ---------------------------------------------------------------------------
