import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const Color _accentRed = Color(0xFFFF3B5C);
const Color _background = Color(0xFFF6F8FF);

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class SchoolActivityItem {
  final String grade;
  final String chosenName;
  final String question;
  final DateTime time;

  const SchoolActivityItem({
    required this.grade,
    required this.chosenName,
    required this.question,
    required this.time,
  });
}

class MyLikeItem {
  final String question;
  final int timesChosen;
  final int starsEarned;
  final bool hasPremium;

  const MyLikeItem({
    required this.question,
    required this.timesChosen,
    required this.starsEarned,
    this.hasPremium = false,
  });
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final List<SchoolActivityItem> _sampleSchoolFeed = [
  SchoolActivityItem(
    grade: '10',
    chosenName: 'Аня',
    question: 'Кто всегда поднимает настроение?',
    time: DateTime.now().subtract(const Duration(minutes: 3)),
  ),
  SchoolActivityItem(
    grade: '11',
    chosenName: 'Максим',
    question: 'Кто станет знаменитым?',
    time: DateTime.now().subtract(const Duration(minutes: 17)),
  ),
  SchoolActivityItem(
    grade: '9',
    chosenName: 'Соня',
    question: 'Кто лучше всех объясняет?',
    time: DateTime.now().subtract(const Duration(minutes: 45)),
  ),
  SchoolActivityItem(
    grade: '10',
    chosenName: 'Дима',
    question: 'Кто самый спортивный?',
    time: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
  ),
  SchoolActivityItem(
    grade: '8',
    chosenName: 'Маша',
    question: 'Кто лучше всех знает английский?',
    time: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  SchoolActivityItem(
    grade: '11',
    chosenName: 'Артём',
    question: 'Кто станет успешным предпринимателем?',
    time: DateTime.now().subtract(const Duration(hours: 5, minutes: 30)),
  ),
  SchoolActivityItem(
    grade: '9',
    chosenName: 'Катя',
    question: 'Кто всегда помогает другим?',
    time: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  SchoolActivityItem(
    grade: '10',
    chosenName: 'Никита',
    question: 'Кто самый креативный?',
    time: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

const List<MyLikeItem> _sampleMyLikes = [
  MyLikeItem(
    question: 'Кто всегда поднимает настроение?',
    timesChosen: 5,
    starsEarned: 250,
    hasPremium: false,
  ),
  MyLikeItem(
    question: 'Кто станет знаменитым?',
    timesChosen: 3,
    starsEarned: 150,
    hasPremium: false,
  ),
  MyLikeItem(
    question: 'Кто лучше всех объясняет?',
    timesChosen: 7,
    starsEarned: 350,
    hasPremium: true,
  ),
  MyLikeItem(
    question: 'Кто самый спортивный?',
    timesChosen: 2,
    starsEarned: 100,
    hasPremium: false,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  return '${diff.inDays} д назад';
}

// ---------------------------------------------------------------------------
// Shimmer placeholder widget
// ---------------------------------------------------------------------------
class _ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBlock({
    required this.width,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _anim.value * 3, 0),
              end: Alignment(-0.5 + _anim.value * 3, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const _ShimmerBlock(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ShimmerBlock(width: 180, height: 13),
              SizedBox(height: 8),
              _ShimmerBlock(width: 120, height: 11),
              SizedBox(height: 6),
              _ShimmerBlock(width: 80, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ActivityScreen
// ---------------------------------------------------------------------------

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<SchoolActivityItem> _schoolFeed = [];
  List<MyLikeItem> _myLikes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _schoolFeed = List.from(_sampleSchoolFeed);
      _myLikes = List.from(_sampleMyLikes);
      _loading = false;
    });
  }

  Future<void> _refreshSchool() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {}); // refresh timestamp display
  }

  Future<void> _refreshLikes() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Активность',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicator: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'В школе'),
                Tab(text: 'Мои лайки'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchoolTab(),
          _buildMyLikesTab(),
        ],
      ),
    );
  }

  // ── Tab 1: В школе ──────────────────────────────────────────────────────

  Widget _buildSchoolTab() {
    if (_loading) return _buildShimmerList();
    if (_schoolFeed.isEmpty) return _buildSchoolEmpty();

    return RefreshIndicator(
      onRefresh: _refreshSchool,
      color: _primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _schoolFeed.length,
        itemBuilder: (context, i) {
          return _AnimatedCard(
            delay: Duration(milliseconds: i * 60),
            child: _buildSchoolCard(_schoolFeed[i]),
          );
        },
      ),
    );
  }

  Widget _buildSchoolCard(SchoolActivityItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.how_to_vote_rounded,
                color: _primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Кто-то из '),
                        TextSpan(
                          text: '${item.grade} класса',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                          ),
                        ),
                        const TextSpan(text: ' выбрал '),
                        TextSpan(
                          text: item.chosenName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' в опросе '),
                        TextSpan(
                          text: '«${item.question}»',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _timeAgo(item.time),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 40,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока нет активности',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Как только кто-то из школы проголосует, здесь появятся записи',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Мои лайки ────────────────────────────────────────────────────

  Widget _buildMyLikesTab() {
    if (_loading) return _buildShimmerList();
    if (_myLikes.isEmpty) return _buildLikesEmpty();

    final totalStars = _myLikes.fold<int>(0, (sum, e) => sum + e.starsEarned);

    return RefreshIndicator(
      onRefresh: _refreshLikes,
      color: _primaryBlue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Stars summary banner
          _buildStarsBanner(totalStars),
          const SizedBox(height: 16),
          ..._myLikes.asMap().entries.map((e) {
            return _AnimatedCard(
              delay: Duration(milliseconds: e.key * 70),
              child: _buildLikeCard(e.value),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStarsBanner(int totalStars) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B6EF5), Color(0xFF6B8EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalStars звёзд',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'получено за все голоса',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLikeCard(MyLikeItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accentRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: _accentRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '«${item.question}»',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(
                            label: '${item.timesChosen}× выбрали',
                            color: _primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            label: '+${item.starsEarned} ⭐',
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            // "Узнать кто" button
            SizedBox(
              width: double.infinity,
              child: item.hasPremium
                  ? ElevatedButton.icon(
                      onPressed: () => context.push(
                        '/premium-result?pollQuestion=${Uri.encodeComponent(item.question)}',
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Узнать кто голосовал'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        elevation: 0,
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.push('/premium'),
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: const Text('Узнать кто'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accentRed,
                        side: const BorderSide(color: _accentRed, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikesEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: _accentRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока нет лайков',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Когда тебя выберут в голосовании, здесь появятся твои лайки',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/vote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Перейти к опросам',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer loading ──────────────────────────────────────────────────────

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }
}

// ---------------------------------------------------------------------------
// Info chip
// ---------------------------------------------------------------------------
class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated card entrance
// ---------------------------------------------------------------------------
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedCard({required this.child, required this.delay});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
