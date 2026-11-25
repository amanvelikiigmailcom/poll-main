import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/game_settings.dart';
import '../../theme/app_colors.dart';

/// English FAQ: short answers grouped by topic, with search and jump links.
///
/// Copy mirrors [AGENTS.md] product rules, LocalGameService constants
/// (12 questions, 4 cards, 4+ people, 1,000 stars, 60-minute break)
/// and the How to use guide. Structure follows the guide's proven UX:
/// hero + search, category chips, accordions, progress and a help footer.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqItem {
  const _FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

class _FaqCategory {
  const _FaqCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.intro,
    required this.items,
  });

  final String id;
  final IconData icon;
  final String title;
  final String intro;
  final List<_FaqItem> items;
}

class _FaqScreenState extends State<FaqScreen> {
  static const _categories = [
    _FaqCategory(
      id: 'start',
      icon: Icons.rocket_launch_outlined,
      title: 'Getting started',
      intro: 'First minutes in the app.',
      items: [
        _FaqItem(
          'How do I start playing?',
          'Add a display name and at least 4 people — pick contacts yourself '
              'or tap Try with example names. No real names needed.',
        ),
        _FaqItem(
          'Can I play as a guest?',
          'Yes. Guest progress stays on this device. Sign in with your phone '
              'number to unlock contact matching, online votes and notifications.',
        ),
        _FaqItem(
          'What is the difference between my name and @username?',
          'Your display name is the label on game cards. Your @username is how '
              'friends find you in search. They are independent — your full name '
              'is never used as your username.',
        ),
        _FaqItem(
          'Why do you ask for my campus and graduation year?',
          'They place you in the right school community for recommendations '
              'and school rounds. Both stay editable in your profile.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'rounds',
      icon: Icons.how_to_vote_rounded,
      title: 'Rounds & voting',
      intro: '12 questions, 4 cards each.',
      items: [
        _FaqItem(
          'How does a round work?',
          'Each round has 12 questions. For every question you pick one of 4 '
              'name cards. You cannot vote for yourself.',
        ),
        _FaqItem(
          'What do Shuffle and Skip do?',
          'Shuffle replaces cards with other eligible people. If nobody else is available, no use is spent. Skip moves to the next question. Each has 2 uses per round. '
              'Skipped questions carry no penalty.',
        ),
        _FaqItem(
          'How do I report a bad question?',
          'Use Report a question while playing. Send the prepared draft from your email '
              'app to support@flyprox.com. Leave participant names and private details out.',
        ),
        _FaqItem(
          'How do I contact support or report an account?',
          'Use Settings → Contact support, Report a problem or Send feedback. '
              'For an account, open its menu and choose Report account. All open '
              'email drafts to support@flyprox.com; you must send the email yourself. '
              'Blocking is a separate action. If email is unavailable, copy the message.',
        ),
        _FaqItem(
          'What can Premium reveal?',
          'Premium includes 2 full-name voter reveals and 5 first-initial reveals '
              'per subscription week. Only eligible new votes can be revealed; '
              'older votes remain hidden.',
        ),
        _FaqItem(
          'Why do some rounds need 5 students?',
          'School rounds need at least 5 students from your campus. '
              'Recommendations and search work without it.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'breaks',
      icon: Icons.timer_outlined,
      title: 'Breaks & limits',
      intro: 'The wait is part of the game.',
      items: [
        _FaqItem(
          'How long is the break after a round?',
          '60 minutes — for everyone, Premium included. The center tab shows '
              'the same remaining time.',
        ),
        _FaqItem(
          'How many rounds can I play per day?',
          'Up to 50 completed online rounds per UTC day. Invitations never '
              'bypass this cap, and unused earned rounds stay saved.',
        ),
        _FaqItem(
          'Does Reset game skip the wait?',
          'No. Reset game clears local progress but never skips the wait, the '
              'age gate, or the school gate.',
        ),
        _FaqItem(
          'How do wait passes work?',
          'Messages marked sent or the first 5 qualifying WhatsApp returns in a UTC '
              'day can earn an extra round. Later WhatsApp invitations need recipient '
              'confirmation. Only the server grants rounds; sharing a link alone does not.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'stars',
      icon: Icons.star_rounded,
      title: 'Stars & Collection',
      intro: 'Stars are progress, boosts are placements.',
      items: [
        _FaqItem(
          'How do I earn stars?',
          'Complete a full 12-question round to collect 1,000 stars, or 2,000 '
              'for an online round with server-confirmed Premium. Stars have no cash value.',
        ),
        _FaqItem(
          'Where is my star balance kept?',
          'Signed-in balances live on the server. Guest stars stay on this '
              'device and never leave it.',
        ),
        _FaqItem(
          'What do boosts do?',
          'A 5,000-star boost places your name in 4 random questions of one '
              'other player’s round. A 20,000-star boost places it in 1 crush '
              'question. A placement is never a guaranteed vote.',
        ),
        _FaqItem(
          'Are purchases confirmed in the app?',
          'No. All purchases are confirmed by the server — never by the app alone.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'friends',
      icon: Icons.people_outline_rounded,
      title: 'Friends & search',
      intro: 'Find people from your selected campus — no phonebook search.',
      items: [
        _FaqItem(
          'How do I find people?',
          'Search by first name, last name or username with 2 or more characters. '
              'Use @ for usernames only. Results stay within your selected campus. There is no phonebook search.',
        ),
        _FaqItem(
          'What are the recommended cards?',
          '“Friends of friends” and “From your campus” suggest people you may '
              'know. Start with 5 cards, tap See more for up to 50.',
        ),
        _FaqItem(
          'How do I become friends with someone?',
          'Send a request and wait for them to accept — friendship always '
              'needs both sides. There is no in-app chat.',
        ),
        _FaqItem(
          'What happens when I block someone?',
          'Blocking hides you from each other in search and stops requests and '
              'online votes in both directions.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'likes',
      icon: Icons.favorite_outline_rounded,
      title: 'Likes & Activity',
      intro: 'See the picks and eligible Premium reveals.',
      items: [
        _FaqItem(
          'Where do I see my likes?',
          'Profile tabs show Friends, Likes and Requests. Collection lives on '
              'its own card.',
        ),
        _FaqItem(
          'What does Activity show?',
          'Who was picked, the question, graduation year and time. Newest 20 '
              'first, 20 more on scroll, 200 per query at most.',
        ),
        _FaqItem(
          'Can I see who voted for me?',
          'Premium can reveal the first initial or full name behind eligible new '
              'votes using limited weekly reveals. Older votes stay hidden. Users who also have active Premium are protected from name and first-initial reveals. Protected attempts do not use your weekly reveals. '
              'Ordinary Likes and Activity do not show voter identities.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'campus',
      icon: Icons.school_outlined,
      title: 'Campus & profile',
      intro: 'Your school, your year, your card.',
      items: [
        _FaqItem(
          'How do I set my campus?',
          'Search campuses from 3 letters, cities from 2, then save your '
              'choice. Skipping campus never unlocks the game alone.',
        ),
        _FaqItem(
          'My campus is missing. What should I do?',
          'Your request is saved first, then you send the request email '
              'yourself from your own mail app.',
        ),
        _FaqItem(
          'Can I upload a profile photo?',
          'No. Your profile photo is a fixed 🙂 — uploads are not supported.',
        ),
        _FaqItem(
          'How do I edit my profile?',
          'Open Profile, then Edit profile. Your campus, year and username '
              'stay independent of your display name.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'privacy',
      icon: Icons.shield_outlined,
      title: 'Privacy & safety',
      intro: 'You choose what leaves the device.',
      items: [
        _FaqItem(
          'Do you upload my contacts?',
          'No. You pick every contact yourself — the full address book is never '
              'uploaded. Only hashes leave your device; labels stay local.',
        ),
        _FaqItem(
          'Are hashed contacts anonymous?',
          'No. Hashing is not anonymity.',
        ),
        _FaqItem(
          'What data stays on my device?',
          'Guest progress, contact labels and game drafts. Signing in adds '
              'matching, votes and notifications.',
        ),
        _FaqItem(
          'What is the age requirement?',
          'Flyprox is 13+. The gate saves only the outcome — never your exact '
              'age or birthday.',
        ),
        _FaqItem(
          'How do I delete my data?',
          'Reset game in Settings clears local progress. Delete account in '
              'Settings removes server data — it needs a connection and is safe '
              'to retry.',
        ),
      ],
    ),
    _FaqCategory(
      id: 'premium',
      icon: Icons.workspace_premium_outlined,
      title: 'Premium & account',
      intro: 'Verified on the server, or it didn’t happen.',
      items: [
        _FaqItem(
          'How do Premium purchases work?',
          'Premium Weekly includes 2 full-name reveals, 5 first-initial reveals, '
              'double online stars and protection from name and first-initial reveals while active. Limits reset each '
              'subscription week; reopening an unlocked vote is free while active. '
              'Purchases run through Superwall and require server confirmation.',
        ),
        _FaqItem(
          'Does Premium skip the wait?',
          'No. Premium never skips the 60-minute wait.',
        ),
        _FaqItem(
          'My Premium access looks wrong. What now?',
          'Check Settings → Subscription status. If you purchased before, use '
              'Restore purchases on the Premium screen.',
        ),
        _FaqItem(
          'How do I delete my account?',
          'Go to Settings → Delete account. The server confirms the erasure; '
              'if it fails, your progress is kept and retry is safe.',
        ),
      ],
    ),
  ];

  int get _total => _categories.fold<int>(
    0,
    (count, category) => count + category.items.length,
  );

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _categoryKeys = <String, GlobalKey>{};
  late final List<ExpansibleController> _tileControllers;
  final _expanded = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tileControllers = List.generate(_total, (_) => ExpansibleController());
    for (final category in _categories) {
      _categoryKeys[category.id] = GlobalKey();
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

  /// Flat controller index for [categoryIndex]/[itemIndex].
  int _flatIndex(int categoryIndex, int itemIndex) {
    var flat = 0;
    for (var c = 0; c < categoryIndex; c++) {
      flat += _categories[c].items.length;
    }
    return flat + itemIndex;
  }

  String _questionId(int categoryIndex, int itemIndex) =>
      '${_categories[categoryIndex].id}:$itemIndex';

  bool _matches(String text) {
    if (_query.isEmpty) return true;
    return text.toLowerCase().contains(_query);
  }

  bool _itemMatches(_FaqCategory category, _FaqItem item) =>
      _matches('${category.title} ${item.question} ${item.answer}');

  /// Visible item indexes per category; empty categories are hidden.
  List<List<int>> get _visible => [
    for (var c = 0; c < _categories.length; c++)
      [
        for (var i = 0; i < _categories[c].items.length; i++)
          if (_itemMatches(_categories[c], _categories[c].items[i])) i,
      ],
  ];

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
    // While searching, open every match so answers are visible at once.
    if (_query.isNotEmpty) {
      final visible = _visible;
      for (var c = 0; c < visible.length; c++) {
        for (final i in visible[c]) {
          _tileControllers[_flatIndex(c, i)].expand();
        }
      }
      setState(() {
        for (var c = 0; c < visible.length; c++) {
          _expanded.addAll(visible[c].map((i) => _questionId(c, i)));
        }
      });
    }
  }

  void _jumpToCategory(int index) {
    GameSettings.instance.feedback(selection: true);
    if (_query.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _categoryKeys[_categories[index].id]?.currentContext;
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
    setState(() {
      for (var c = 0; c < _categories.length; c++) {
        for (var i = 0; i < _categories[c].items.length; i++) {
          _expanded.add(_questionId(c, i));
        }
      }
    });
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
      appBar: AppBar(title: const Text('FAQ')),
      body: ListenableBuilder(
        listenable: GameSettings.instance,
        builder: (context, _) {
          final animate = !GameSettings.instance.effectiveReduceMotion;
          final visible = _visible;
          final hasMatches = visible.any((items) => items.isNotEmpty);
          final progress = _total == 0 ? 0.0 : _expanded.length / _total;
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
                    total: _total,
                    topics: _categories.length,
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
                      explored: _expanded.length,
                      total: _total,
                      progress: progress,
                      onExpandAll: _expandAll,
                      onCollapseAll: _collapseAll,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CategoryChips(
                    categories: _categories,
                    onTap: _jumpToCategory,
                  ),
                ],
                if (hasMatches)
                  for (var c = 0; c < _categories.length; c++)
                    if (visible[c].isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _CategorySection(
                        key: _categoryKeys[_categories[c].id],
                        category: _categories[c],
                        itemIndexes: visible[c],
                        controllerFor: (i) =>
                            _tileControllers[_flatIndex(c, i)],
                        onChanged: (open, i) {
                          GameSettings.instance.feedback(selection: true);
                          setState(() {
                            if (open) _expanded.add(_questionId(c, i));
                          });
                        },
                      ),
                    ],
                if (!hasMatches)
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
                  child: _HelpCard(
                    onSafety: () => context.push(AppRoutes.safetyCenter),
                    onGuide: () => context.push(AppRoutes.howToUse),
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
    required this.total,
    required this.topics,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final int total;
  final int topics;
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
              Icon(Icons.quiz_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Frequently asked questions',
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
            'Short answers about rounds, stars, friends and privacy.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.quiz_rounded, label: '$total answers'),
              _StatChip(
                icon: Icons.folder_open_rounded,
                label: '$topics topics',
              ),
              const _StatChip(
                icon: Icons.touch_app_rounded,
                label: 'Tap a question',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('faq-search'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search questions…',
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
                      ? 'All questions explored — nice!'
                      : '$explored of $total questions explored',
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
              label: 'FAQ reading progress',
              value: '$explored of $total questions',
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.onTap});
  final List<_FaqCategory> categories;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == categories.length - 1 ? 0 : 8,
              ),
              child: ActionChip(
                avatar: Icon(
                  categories[i].icon,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                label: Text(categories[i].title),
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    super.key,
    required this.category,
    required this.itemIndexes,
    required this.controllerFor,
    required this.onChanged,
  });

  final _FaqCategory category;
  final List<int> itemIndexes;
  final ExpansibleController Function(int itemIndex) controllerFor;
  final void Function(bool open, int itemIndex) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      category.intro,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final i in itemIndexes)
          _QuestionCard(
            storageKey: PageStorageKey('faq-${category.id}-$i'),
            controller: controllerFor(i),
            item: category.items[i],
            onChanged: (open) => onChanged(open, i),
          ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.storageKey,
    required this.controller,
    required this.item,
    required this.onChanged,
  });

  final PageStorageKey<String> storageKey;
  final ExpansibleController controller;
  final _FaqItem item;
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
          title: Text(
            item.question,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          children: [
            const Divider(height: 16, color: AppColors.divider),
            Text(
              item.answer,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.5,
                fontSize: 14,
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

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.onSafety, required this.onGuide});
  final VoidCallback onSafety;
  final VoidCallback onGuide;

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
            Icons.support_agent_rounded,
            color: AppColors.primaryBlue,
            size: 32,
          ),
          const SizedBox(height: 10),
          const Text(
            'Still need help?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Safety center covers support, blocking and reports. '
            'The guide covers rules and pro tips.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('faq-safety'),
                  onPressed: onSafety,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Safety center'),
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
                  key: const ValueKey('faq-howto'),
                  onPressed: onGuide,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('How to play'),
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
