import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_colors.dart';

// Tracks whether a vote round is available right now or the 60-minute
// break timer is still running, using LocalGameService's local state.
enum _HomeTabState { loading, timerActive, voteAvailable }

class MainTab extends ConsumerStatefulWidget {
  const MainTab({super.key});

  @override
  ConsumerState<MainTab> createState() => _MainTabState();
}

class _MainTabState extends ConsumerState<MainTab> {
  _HomeTabState _tabState = _HomeTabState.loading;

  int _secondsRemaining = 0;
  Timer? _ticker;

  int _starsCount = 0;
  int _peopleCount = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final remaining = await LocalGameService.instance.secondsUntilNextRound();
    final stars = await LocalGameService.instance.getStars();
    final people = (await LocalGameService.instance.getNames()).length;
    if (!mounted) return;
    setState(() {
      _starsCount = stars;
      _peopleCount = people;
      _secondsRemaining = remaining;
      _tabState = remaining > 0
          ? _HomeTabState.timerActive
          : _HomeTabState.voteAvailable;
    });
    _ticker?.cancel();
    if (remaining > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_secondsRemaining <= 1) {
          t.cancel();
          setState(() {
            _secondsRemaining = 0;
            _tabState = _HomeTabState.voteAvailable;
          });
        } else {
          setState(() => _secondsRemaining--);
        }
      });
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Start a round once the selected contacts or example names are ready.
  Future<void> _startVote() async {
    final ready = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    if (ready) {
      context.push(AppRoutes.vote);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Choose at least 4 contacts, or try example names to start the game.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.push(AppRoutes.namesEntry);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(invitationServiceProvider, (_, __) {
      if (mounted) _loadState();
    });
    final decorative =
        MediaQuery.sizeOf(context).height >= 700 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.4;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadState,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Flyprox',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open profile',
                    onPressed: () => context.go(AppRoutes.profile),
                    icon: const Text('🙂', style: TextStyle(fontSize: 28)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_tabState == _HomeTabState.loading)
                const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_tabState == _HomeTabState.timerActive) _buildTimerCard(),
              if (_tabState == _HomeTabState.voteAvailable)
                _buildVoteCard(decorative),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFECA900),
                        value: '$_starsCount',
                        label: 'Stars',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_alt_outlined,
                        iconColor: AppColors.primaryBlue,
                        value: '$_peopleCount',
                        label: 'People',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _heroDecoration => BoxDecoration(
    color: AppColors.primaryBlueDark,
    borderRadius: BorderRadius.circular(28),
  );

  Widget _buildTimerCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: _heroDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.timer_outlined, color: Colors.white, size: 32),
        const SizedBox(height: 24),
        const Text(
          'A little break.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your next round opens in',
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _formatTime(_secondsRemaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 28),
        _heroButton(
          'Details',
          () => context.push(AppRoutes.timer),
          Icons.arrow_forward_rounded,
        ),
      ],
    ),
  );

  Widget _buildVoteCard(bool decorative) => Container(
    padding: const EdgeInsets.all(24),
    decoration: _heroDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR NEXT ROUND',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Who’s most\nlikely to…?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '12 questions about the people you choose.',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
        ),
        if (decorative) ...[
          const SizedBox(height: 16),
          const ExcludeSemantics(child: _RoundCards()),
        ],
        const SizedBox(height: 28),
        _heroButton('Go to quiz', _startVote, Icons.arrow_forward_rounded),
      ],
    ),
  );

  Widget _heroButton(
    String label,
    VoidCallback onPressed,
    IconData icon,
  ) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlueDark,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 22),
        ],
      ),
    ),
  );
}

class _RoundCards extends StatelessWidget {
  const _RoundCards();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: Center(
      child: SizedBox(
        width: 216,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _card('💛', -0.18, const Offset(-58, 5), const Color(0xFFEAF0FF)),
            _card('😂', 0.18, const Offset(58, 5), const Color(0xFFEAF0FF)),
            _card('✨', 0, Offset.zero, Colors.white),
          ],
        ),
      ),
    ),
  );
  Widget _card(String emoji, double angle, Offset offset, Color color) =>
      Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 82,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 35)),
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9ECF4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
