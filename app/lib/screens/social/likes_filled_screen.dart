import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const Color _background = Color(0xFFF8F8F8);

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

enum LikeGender { girl, boy, nonbinary }

class LikeItem {
  final String grade;
  final LikeGender gender;
  final String timeLabel;
  final String section;

  const LikeItem({
    required this.grade,
    required this.gender,
    required this.timeLabel,
    required this.section,
  });
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const List<LikeItem> _sampleLikes = [
  LikeItem(
    grade: '10',
    gender: LikeGender.girl,
    timeLabel: 'Час назад',
    section: 'Сегодня',
  ),
  LikeItem(
    grade: '11',
    gender: LikeGender.boy,
    timeLabel: '3 часа назад',
    section: 'Сегодня',
  ),
  LikeItem(
    grade: '9',
    gender: LikeGender.girl,
    timeLabel: '5 часов назад',
    section: 'Сегодня',
  ),
  LikeItem(
    grade: '10',
    gender: LikeGender.nonbinary,
    timeLabel: 'Вчера, 18:00',
    section: 'Вчера',
  ),
  LikeItem(
    grade: '8',
    gender: LikeGender.boy,
    timeLabel: 'Вчера, 12:00',
    section: 'Вчера',
  ),
  LikeItem(
    grade: '11',
    gender: LikeGender.girl,
    timeLabel: '3 дня назад',
    section: 'Ранее',
  ),
  LikeItem(
    grade: '9',
    gender: LikeGender.girl,
    timeLabel: '5 дней назад',
    section: 'Ранее',
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _genderLabel(LikeGender g) {
  switch (g) {
    case LikeGender.girl:
      return 'Девочка';
    case LikeGender.boy:
      return 'Мальчик';
    case LikeGender.nonbinary:
      return 'Небинарный';
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LikesFilledScreen extends ConsumerWidget {
  const LikesFilledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = <String>[];
    final Map<String, List<LikeItem>> grouped = {};
    for (final item in _sampleLikes) {
      if (!grouped.containsKey(item.section)) {
        sections.add(item.section);
        grouped[item.section] = [];
      }
      grouped[item.section]!.add(item);
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HeaderCard()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Build section headers and cards interleaved
                    final items = _buildSectionItems(
                      sections,
                      grouped,
                      context,
                    );
                    return items[index];
                  },
                  childCount: _countSectionItems(sections, grouped),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  int _countSectionItems(
    List<String> sections,
    Map<String, List<LikeItem>> grouped,
  ) {
    int count = 0;
    for (final s in sections) {
      count += 1 + (grouped[s]?.length ?? 0);
    }
    return count;
  }

  List<Widget> _buildSectionItems(
    List<String> sections,
    Map<String, List<LikeItem>> grouped,
    BuildContext context,
  ) {
    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(_SectionHeader(title: section));
      for (final item in grouped[section] ?? []) {
        widgets.add(_LikeCard(item: item));
      }
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Лайки',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Всего: 7',
                  style: TextStyle(
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
            'Узнайте, кто выбрал вас в голосовании',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
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

// ---------------------------------------------------------------------------
// Like card
// ---------------------------------------------------------------------------

class _LikeCard extends StatelessWidget {
  final LikeItem item;

  const _LikeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/likes-result'),
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
            // Heart icon in circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: _primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'За тебя проголосовали с ${item.grade} класса',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _GenderBadge(gender: item.gender),
                      const SizedBox(width: 8),
                      Text(
                        item.timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gender badge
// ---------------------------------------------------------------------------

class _GenderBadge extends StatelessWidget {
  final LikeGender gender;

  const _GenderBadge({required this.gender});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _genderLabel(gender),
        style: const TextStyle(
          color: _primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
