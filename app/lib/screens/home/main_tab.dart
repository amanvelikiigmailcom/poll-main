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

class _MainTabState extends ConsumerState<MainTab> with WidgetsBindingObserver {
  _HomeTabState _tabState = _HomeTabState.loading;

  int _secondsRemaining = 0;
  Timer? _ticker;

  bool _hasProgress = false;
  bool _schoolDraft = false;
  bool _schoolWaiting = false;
  ({bool school, int joined, int threshold})? _mode;
  int _modeRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
    _loadMode();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMode();
      ref.invalidate(starBalanceProvider);
    }
  }

  Future<void> _loadMode() async {
    final generation = ++_modeRequest;
    final mode = await ref.read(onboardingDetailsProvider).votingMode();
    if (mounted && generation == _modeRequest) setState(() => _mode = mode);
  }

  Future<void> _loadState() async {
    final waiting = !await ref.read(onboardingDetailsProvider).votingAllowed();
    final remaining = await LocalGameService.instance.secondsUntilNextRound();
    final progress = await LocalGameService.instance.loadRoundProgress();
    if (!mounted) return;
    setState(() {
      _schoolWaiting = waiting;
      _hasProgress = progress != null;
      _schoolDraft = progress?.draft?['schoolVoting'] == true;
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
    final progress = await LocalGameService.instance.loadRoundProgress();
    if (!mounted) return;
    if (ready ||
        progress?.draft != null ||
        (await ref.read(onboardingDetailsProvider).votingMode())?.school ==
            true) {
      if (!mounted) return;
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
    ref.listen(onboardingDetailsProvider, (_, __) {
      if (mounted) {
        setState(() => _mode = null);
        _loadState();
        _loadMode();
      }
    });
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
          onRefresh: () async {
            ref.invalidate(starBalanceProvider);
            await Future.wait([_loadState(), _loadMode()]);
          },
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
              if (_schoolWaiting)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: _heroDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choose your campus to play',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Quiz play opens after you select your campus. If it is missing, send its details to our team.',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      _heroButton(
                        'Choose your campus',
                        () => context.go(AppRoutes.schoolSetup),
                        Icons.school_outlined,
                      ),
                    ],
                  ),
                ),
              if (!_schoolWaiting && _tabState == _HomeTabState.timerActive)
                _buildTimerCard(),
              if (!_schoolWaiting && _tabState == _HomeTabState.voteAvailable)
                _buildVoteCard(decorative),
              if (!_schoolWaiting)
                if (_mode case final mode?)
                  _SchoolBanner(
                    mode: mode,
                    hasProgress: _hasProgress,
                    schoolDraft: _schoolDraft,
                    onInvite: () => context.push(AppRoutes.invite),
                  ),
              const SizedBox(height: 20),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: const Text('⭐', style: TextStyle(fontSize: 30)),
                  title: const Text(
                    'Collection',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    ref
                        .watch(starBalanceProvider)
                        .when(
                          skipLoadingOnRefresh: false,
                          skipLoadingOnReload: false,
                          data: (n) => n == null
                              ? 'Your stars & boosts'
                              : '$n stars · Explore boosts',
                          error: (_, _) => 'Couldn’t load stars',
                          loading: () => 'Loading stars…',
                        ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.collection),
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
        const SizedBox(height: 16),
        const Text(
          'Invite one friend to unlock another round once confirmed.',
          style: TextStyle(color: Colors.white, height: 1.4),
        ),
        const SizedBox(height: 20),
        _heroButton(
          'Invite a friend',
          () => context.push(AppRoutes.invite),
          Icons.arrow_forward_rounded,
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.timer),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Details'),
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
          '12 questions. Pick the person who fits and make their day.',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
        ),
        if (decorative) ...[
          const SizedBox(height: 16),
          const ExcludeSemantics(child: _RoundCards()),
        ],
        const SizedBox(height: 28),
        _heroButton(
          _hasProgress ? 'Continue round' : 'Go to quiz',
          _startVote,
          Icons.arrow_forward_rounded,
        ),
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

class _SchoolBanner extends StatelessWidget {
  const _SchoolBanner({
    required this.mode,
    required this.hasProgress,
    required this.schoolDraft,
    required this.onInvite,
  });
  final ({bool school, int joined, int threshold}) mode;
  final bool hasProgress;
  final bool schoolDraft;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final open = mode.school;
    final title = open
        ? (hasProgress && !schoolDraft
              ? 'Campus quizzes open next round'
              : 'Campus quizzes are open')
        : 'Unlock campus quizzes';
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF1FE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  open ? Icons.verified_outlined : Icons.school_outlined,
                  color: AppColors.primaryBlueDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (!open) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: mode.threshold == 0
                    ? 0
                    : (mode.joined / mode.threshold).clamp(0.0, 1.0),
                backgroundColor: AppColors.border,
                color: AppColors.primaryBlue,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${mode.joined} of ${mode.threshold} joined',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Until ${mode.threshold} classmates join, you play with your contacts. Invite classmates to unlock the full school mode.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onInvite,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 20),
                label: const Text(
                  'Invite classmates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
