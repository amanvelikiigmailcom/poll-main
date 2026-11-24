import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';
import 'received_likes_screen.dart';

/// Details of one received vote, opened from a Like card.
///
/// Matches the voting screen: light background, big question and a
/// two-column grid of participant cards. Names come from the server
/// snapshot when the vote has one, otherwise from this device.
/// The voter stays anonymous; the API never sends names or
/// identity hints, so this screen promises no reveal.
class LikesResultScreen extends ConsumerWidget {
  const LikesResultScreen({super.key, this.like});

  final Map<String, dynamic>? like;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final like = this.like;
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
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
                          const SizedBox(height: 20),
                          _ParticipantsSection(
                            question: question,
                            server: participants,
                          ),
                          const SizedBox(height: 20),
                          const _AnonymousCard(),
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
    final name = entry['name'] is String ? (entry['name'] as String).trim() : '';
    if (name.isEmpty) continue;
    final year = entry['graduationYear'];
    result.add(
      _Participant(
        name: name,
        graduationYear: year is int ? year : null,
      ),
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
// Participants grid (server snapshot, local names as fallback)
// ---------------------------------------------------------------------------

/// Everyone who was in the vote, in the voting screen card style.
///
/// The server snapshot wins when the vote has one. Older votes without a
/// snapshot fall back to the names saved on this device. The saved local
/// pick is marked with the voting selected style in both modes.
class _ParticipantsSection extends StatefulWidget {
  const _ParticipantsSection({required this.question, required this.server});

  final String question;
  final List<_Participant> server;

  @override
  State<_ParticipantsSection> createState() => _ParticipantsSectionState();
}

class _ParticipantsSectionState extends State<_ParticipantsSection> {
  List<String>? _names;
  String? _pick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<String> names = const [];
    String? pick;
    try {
      final game = LocalGameService.instance;
      names = await game.selectedOptions();
      final answers = [
        ...await game.getRoundAnswers(),
        ...await game.getRoundAnswers(completed: true),
      ];
      for (final answer in answers) {
        if (answer.question == widget.question && answer.choice != null) {
          pick = answer.choice;
          break;
        }
      }
    } catch (_) {
      names = const [];
      pick = null;
    }
    if (mounted) {
      setState(() {
        _names = names;
        _pick = pick;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    final fromServer = widget.server.isNotEmpty;
    final participants = fromServer
        ? widget.server
        : [
            for (final name in names ?? const <String>[])
              _Participant(name: name),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fromServer ? 'Participants' : 'Your voting circle',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fromServer
              ? 'Everyone who was in this vote.'
              : 'People you vote with on this device.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        if (!fromServer && names == null)
          const SizedBox(height: 8)
        else if (participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Play a round to see your voting circle.',
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
                        isPick: participant.name == _pick,
                        onTap: () => context.push(
                          AppRoutes.likesPerson,
                          extra: {
                            'name': participant.name,
                            'question': widget.question,
                            'isPick': participant.name == _pick,
                            if (participant.graduationYear != null)
                              'graduationYear': participant.graduationYear,
                          },
                        ),
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
  const _ParticipantCard({
    required this.participant,
    required this.isPick,
    required this.onTap,
  });

  final _Participant participant;
  final bool isPick;
  final VoidCallback onTap;

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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.08),
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

class _AnonymousCard extends StatelessWidget {
  const _AnonymousCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voter',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Anonymous voter',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The voter stays anonymous.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
