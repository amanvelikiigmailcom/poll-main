import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/game_settings.dart';
import '../../theme/app_colors.dart';

/// Full English guide: quick start, game rules and 20 pro tips.
///
/// Content mirrors [AGENTS.md] product rules and the constants in
/// LocalGameService (12 questions, 4 cards, 1,000 stars, 60-minute break).
class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _GuideStep {
  const _GuideStep(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _GuideSection {
  const _GuideSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.intro,
    required this.bullets,
    this.numbered = false,
  });

  final String id;
  final IconData icon;
  final String title;
  final String intro;
  final List<String> bullets;

  /// Render bullets as a numbered list (used by the pro-tips section).
  final bool numbered;
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  static const _steps = [
    _GuideStep(
      Icons.person_add_rounded,
      'Create your profile',
      'Phone or guest → age 13+ → About you → campus + graduation year → '
          'username. Two minutes, no real names needed.',
    ),
    _GuideStep(
      Icons.groups_rounded,
      'Add 4+ people',
      'Pick contacts yourself or tap Try with example names. '
          'Only hashes leave your device — raw numbers never upload.',
    ),
    _GuideStep(
      Icons.how_to_vote_rounded,
      'Answer 12 questions',
      'Pick one of 4 cards per question. You can’t vote for yourself. '
          'Shuffle changes available cards; Skip moves on. Each can be used twice per round.',
    ),
    _GuideStep(
      Icons.star_rounded,
      'Collect 1,000 stars',
      'Every full round earns 1,000 stars, or 2,000 for an online round with server-confirmed Premium. Then a 60-minute break starts — '
          'for everyone, Premium included.',
    ),
    _GuideStep(
      Icons.ios_share_rounded,
      'Play again your way',
      'Wait out the break or invite a new friend: one confirmed invitation '
          '= one extra round.',
    ),
  ];

  static const _sections = [
    _GuideSection(
      id: 'rules',
      icon: Icons.how_to_vote_rounded,
      title: 'Game rules',
      intro: 'One round, 12 questions, 4 cards each.',
      bullets: [
        'Each round has 12 questions. For every question you pick one of 4 name cards.',
        'You cannot vote for yourself — your card is never a candidate.',
        'Shuffle replaces cards when other eligible people are available; otherwise it reorders them. Skip moves to the next question. Each has 2 uses per round.',
        'Skipped questions carry no penalty — report ones that feel wrong.',
        'To start you need a display name and at least 4 participants (or example names).',
      ],
    ),
    _GuideSection(
      id: 'breaks',
      icon: Icons.timer_outlined,
      title: 'Breaks & daily limits',
      intro: 'The wait is part of the game.',
      bullets: [
        'A 60-minute break starts after every round — Premium included.',
        'The center tab shows the same remaining time.',
        'Up to 50 completed online rounds per UTC day. Invitations never bypass this cap.',
        'Unused earned rounds stay saved.',
        'Reset game never skips the wait, the age gate, or the school gate.',
      ],
    ),
    _GuideSection(
      id: 'stars',
      icon: Icons.star_rounded,
      title: 'Stars & Collection',
      intro: 'Stars are progress, boosts are placements.',
      bullets: [
        'A full 12-question round earns 1,000 stars.',
        'Signed-in balance lives on the server; guest stars stay on this device.',
        'All purchases are confirmed by the server — never by the app alone.',
        '5,000-star boost: your name appears in 4 random questions of one other player’s round (at most 1 crush question).',
        '20,000-star boost: your name appears in 1 crush question in another player’s round.',
        'Boosts apply to future eligible campus rounds — a placement is never a guaranteed vote.',
      ],
    ),
    _GuideSection(
      id: 'invites',
      icon: Icons.ios_share_rounded,
      title: 'Invitations & wait passes',
      intro: 'Only registered friends earn passes.',
      bullets: [
        'One counted recipient = one extra 12-question round — but only the server can grant it.',
        'Sharing a link alone never earns a pass: the recipient must register.',
        'A Messages “sent” receipt counts, as do the first 5 same-day WhatsApp returns after 4+ seconds.',
        'From the 6th WhatsApp return in a UTC day, the recipient must confirm in the app.',
        'Apply invitation codes within 7 days of creating your account.',
      ],
    ),
    _GuideSection(
      id: 'friends',
      icon: Icons.people_outline_rounded,
      title: 'Friends & search',
      intro: 'Usernames only — no phonebook search.',
      bullets: [
        'People are found by @username only — type 2+ letters, results update as you type.',
        'Usernames are 3–32 ASCII characters at registration.',
        'Start with 5 cards, tap See more for the full campus list (up to 50).',
        'Try “Friends of friends” and “From your campus” recommendations.',
        'Friendship always needs an accepted request. There is no in-app chat.',
        'Blocking hides you from each other in search and stops requests and online votes.',
      ],
    ),
    _GuideSection(
      id: 'likes',
      icon: Icons.favorite_outline_rounded,
      title: 'Likes & Activity',
      intro: 'See your picks and eligible voter reveals.',
      bullets: [
        'Profile tabs: Friends, Likes, Requests. Collection lives on its own card.',
        'Activity shows who was picked, the question, graduation year and time.',
        'Newest 20 first, 20 more on scroll, 200 per query at most.',
        'Premium can reveal the first initial or full name behind eligible new votes, with weekly limits. Older votes stay hidden.',
      ],
    ),
    _GuideSection(
      id: 'campus',
      icon: Icons.school_outlined,
      title: 'Campus & profile',
      intro: 'Your school, your year, your card.',
      bullets: [
        'Search campuses from 3 letters, cities from 2.',
        'Missing campus? It is saved first, then you send the request email yourself.',
        'Skipping campus or requesting a new one never unlocks the game alone.',
        'The 5-student threshold applies to school rounds, not recommendations.',
        'Your profile photo is a fixed 🙂 — uploads are not supported.',
      ],
    ),
    _GuideSection(
      id: 'privacy',
      icon: Icons.shield_outlined,
      title: 'Privacy & safety',
      intro: 'You choose what leaves the device.',
      bullets: [
        'You pick every contact yourself — the full address book is never uploaded.',
        'Only hashes leave the device; labels stay local. Hashing is not anonymity.',
        'Guest progress lives on this device; sign-in adds matching, votes and notifications.',
        'Flyprox is 13+. The gate saves only the outcome, never your exact age.',
        'Reset game clears local progress. Delete account (Settings) removes server data — needs a connection, safe to retry.',
        'Report with the question text only — leave names and private details out.',
      ],
    ),
    _GuideSection(
      id: 'premium',
      icon: Icons.workspace_premium_outlined,
      title: 'Premium',
      intro: 'Verified on the server, or it didn’t happen.',
      bullets: [
        'Purchases run through Superwall and are verified on the server.',
        'Premium includes 2 full-name reveals and 5 first-initial reveals per subscription week.',
        'Earn 2000 stars per completed online round instead of 1000, plus a blue membership badge while active.',
        'Premium never skips the 60-minute wait.',
        'A local or debug Premium flag grants no server rights.',
        'Check Settings → Subscription status if access looks wrong.',
      ],
    ),
    _GuideSection(
      id: 'tips',
      icon: Icons.tips_and_updates_rounded,
      title: '20 pro tips',
      intro: 'Small habits of experienced players.',
      numbered: true,
      bullets: [
        'Learn the flow in one minute — start with example names.',
        'Use nicknames. Never type phone numbers or addresses.',
        'Want different cards? Shuffle brings in other eligible people when available.',
        'You can skip up to 2 questions per round without a penalty.',
        'Report bad questions with their text; leave names out.',
        'Only full 12-question rounds earn the 1,000 stars.',
        'The center tab always shows your live break countdown.',
        'Invite early — passes are the only way to skip waiting.',
        'A Messages “sent” receipt counts; a bare shared link does not.',
        'Plan around the cap: 50 online rounds per UTC day.',
        'Sign in — guest stars never leave this device.',
        'Boosts shine in active rounds, but votes are never guaranteed.',
        'Save the 20,000-star crush for someone special.',
        'Search needs just 2 letters of a @username.',
        'The first 5 cards are a preview — tap See more.',
        '“From your campus” finds familiar faces fastest.',
        'Friendship needs both sides — accept requests you trust.',
        'Blocked accounts can’t vote for each other or match in search.',
        'Scroll Activity for older picks — history keeps 200 entries.',
        'Lost? Replay the intro from Settings anytime.',
      ],
    ),
  ];

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _tileKeys = <String, GlobalKey>{};
  late final List<ExpansibleController> _tileControllers;
  final _explored = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tileControllers = List.generate(
      _sections.length,
      (_) => ExpansibleController(),
    );
    for (final section in _sections) {
      _tileKeys[section.id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    for (final controller in _tileControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _matches(String text) {
    if (_query.isEmpty) return true;
    return text.toLowerCase().contains(_query);
  }

  bool _stepMatches(_GuideStep step) => _matches('${step.title} ${step.body}');

  bool _sectionMatches(_GuideSection section) => _matches(
    '${section.title} ${section.intro} ${section.bullets.join(' ')}',
  );

  List<int> get _visibleSteps => [
    for (var i = 0; i < _steps.length; i++)
      if (_stepMatches(_steps[i])) i,
  ];

  List<int> get _visibleSections => [
    for (var i = 0; i < _sections.length; i++)
      if (_sectionMatches(_sections[i])) i,
  ];

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
    // While searching, open every match so answers are visible at once.
    if (_query.isNotEmpty) {
      for (final i in _visibleSections) {
        _tileControllers[i].expand();
      }
      setState(() {
        _explored.addAll(_visibleSections.map((i) => _sections[i].id));
      });
    }
  }

  void _jumpToSection(int index) {
    GameSettings.instance.feedback(selection: true);
    if (_query.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
    }
    _tileControllers[index].expand();
    setState(() => _explored.add(_sections[index].id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _tileKeys[_sections[index].id]?.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(
          target,
          duration: GameSettings.instance.effectiveReduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _expandAll() {
    GameSettings.instance.feedback(selection: true);
    for (final controller in _tileControllers) {
      controller.expand();
    }
    setState(() => _explored.addAll(_sections.map((s) => s.id)));
  }

  void _collapseAll() {
    GameSettings.instance.feedback(selection: true);
    for (final controller in _tileControllers) {
      controller.collapse();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('How to use')),
      body: ListenableBuilder(
        listenable: GameSettings.instance,
        builder: (context, _) {
          final animate = !GameSettings.instance.effectiveReduceMotion;
          final steps = _visibleSteps;
          final sections = _visibleSections;
          final progress = _explored.length / _sections.length;
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Entrance(
                  index: 0,
                  enabled: animate,
                  child: _HeroCard(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                ),
                if (_query.isEmpty) ...[
                  const SizedBox(height: 12),
                  _Entrance(
                    index: 1,
                    enabled: animate,
                    child: _ProgressCard(
                      explored: _explored.length,
                      total: _sections.length,
                      progress: progress,
                      onExpandAll: _expandAll,
                      onCollapseAll: _collapseAll,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionChips(sections: _sections, onTap: _jumpToSection),
                ],
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _ListHeading(
                    title: 'Quick start',
                    subtitle: 'Five steps to your first round',
                  ),
                  const SizedBox(height: 8),
                  for (var order = 0; order < steps.length; order++)
                    _Entrance(
                      index: order + 2,
                      enabled: animate,
                      child: _StepCard(
                        number: steps[order] + 1,
                        step: _steps[steps[order]],
                      ),
                    ),
                ],
                if (sections.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _ListHeading(
                    title: 'Rules & details',
                    subtitle: 'Tap a card to expand it',
                  ),
                  const SizedBox(height: 8),
                  for (final i in sections)
                    _SectionCard(
                      key: _tileKeys[_sections[i].id],
                      storageKey: PageStorageKey(
                        'howto-section-${_sections[i].id}',
                      ),
                      controller: _tileControllers[i],
                      section: _sections[i],
                      onChanged: (open) {
                        GameSettings.instance.feedback(selection: true);
                        setState(() {
                          if (open) _explored.add(_sections[i].id);
                        });
                      },
                    ),
                ],
                if (steps.isEmpty && sections.isEmpty)
                  _EmptySearch(
                    query: _searchController.text,
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                const SizedBox(height: 20),
                _Entrance(
                  index: 7,
                  enabled: animate,
                  child: _ReadyCard(
                    onStart: () => context.go(AppRoutes.home),
                    onInvite: () => context.push(AppRoutes.invite),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Staggered fade-and-rise entrance. Skipped entirely when animations
/// are disabled via Settings → Reduce motion or the OS setting.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final start = (0.08 * index).clamp(0.0, 0.55);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, inner) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.explore_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How to use Flyprox',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Rules, stars and 20 pro tips — everything in one guide.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.quiz_rounded, label: '12 questions'),
              _StatChip(icon: Icons.timer_outlined, label: '60-min break'),
              _StatChip(icon: Icons.star_rounded, label: '1,000 stars'),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('howto-search'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search the guide…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.clear_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.explored,
    required this.total,
    required this.progress,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  final int explored;
  final int total;
  final double progress;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  explored >= total
                      ? 'Guide complete — nice!'
                      : '$explored of $total sections explored',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: onExpandAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Expand all'),
              ),
              TextButton(
                onPressed: onCollapseAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Collapse'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Semantics(
              label: 'Guide reading progress',
              value: '$explored of $total sections',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.sections, required this.onTap});
  final List<_GuideSection> sections;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == sections.length - 1 ? 0 : 8),
              child: ActionChip(
                avatar: Icon(
                  sections[i].icon,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                label: Text(sections[i].title),
                onPressed: () => onTap(i),
                backgroundColor: AppColors.cardBg,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.step});
  final int number;
  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.storageKey,
    required this.controller,
    required this.section,
    required this.onChanged,
  });

  final PageStorageKey<String> storageKey;
  final ExpansibleController controller;
  final _GuideSection section;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.cardBg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ExpansionTile(
          key: storageKey,
          controller: controller,
          onExpansionChanged: onChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.primaryBlue,
          collapsedIconColor: AppColors.textHint,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: AppColors.primaryBlue, size: 22),
          ),
          title: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
          ),
          subtitle: Text(
            section.intro,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          children: [
            const Divider(height: 16, color: AppColors.divider),
            for (var i = 0; i < section.bullets.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == section.bullets.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section.numbered
                        ? Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.bullets[i],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'No matches for “$query”',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Try “stars”, “invite”, “campus” or “privacy”.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Clear search')),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.onStart, required this.onInvite});
  final VoidCallback onStart;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: AppColors.primaryBlue,
            size: 32,
          ),
          const SizedBox(height: 10),
          const Text(
            'Ready to play?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jump into a round or bring a friend along.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('howto-start'),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start a round'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('howto-invite'),
                  onPressed: onInvite,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Invite a friend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
